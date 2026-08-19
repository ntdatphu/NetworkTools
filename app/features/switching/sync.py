"""Parse and synchronize bounded Cisco switch operational snapshots."""

from __future__ import annotations

import re
import sqlite3
from contextlib import closing
from dataclasses import dataclass
from pathlib import Path
from typing import Any


_IFACE_PREFIXES = {
    "gi": "GigabitEthernet",
    "fa": "FastEthernet",
    "te": "TenGigabitEthernet",
    "eth": "Ethernet",
    "po": "Port-channel",
}


def normalize_interface_name(value: str) -> str:
    name = str(value or "").strip()
    match = re.match(r"^([A-Za-z]+)(\d.*)$", name)
    if not match:
        return name
    return _IFACE_PREFIXES.get(match.group(1).lower(), match.group(1)) + match.group(2)


def parse_vlan_brief(output: str) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for match in re.finditer(
        r"(?m)^\s*(\d+)\s+(\S+)\s+(active|suspended|suspend)\b",
        str(output or ""),
        re.IGNORECASE,
    ):
        vlan_id = int(match.group(1))
        if 1002 <= vlan_id <= 1005:
            continue
        rows.append(
            {
                "vlan_id": vlan_id,
                "vlan_name": match.group(2),
                "state": "suspend" if "suspend" in match.group(3).lower() else "active",
            }
        )
    return rows


def parse_interface_status(output: str) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    pattern = re.compile(
        r"(?m)^\s*([A-Za-z]+\d+(?:/\d+)*)\s+(.*?)\s+"
        r"(connected|notconnect|disabled|err-disabled)\s+"
        r"(trunk|routed|unassigned|\d+)\s+"
        r"(auto|a-full|full|a-half|half)\s+(auto|a-\d+|\d+)\b",
        re.IGNORECASE,
    )
    for match in pattern.finditer(str(output or "")):
        vlan = match.group(4).lower()
        rows.append(
            {
                "if_name": normalize_interface_name(match.group(1)),
                "description": match.group(2).strip(),
                "mode": "trunk" if vlan == "trunk" else "routed" if vlan == "routed" else "access",
                "admin_status": "down" if match.group(3).lower() == "disabled" else "up",
                "oper_status": (
                    "up" if match.group(3).lower() == "connected"
                    else "err-disabled" if match.group(3).lower() == "err-disabled"
                    else "down"
                ),
                "speed": match.group(6).lower().removeprefix("a-"),
                "duplex": match.group(5).lower().removeprefix("a-"),
                "access_vlan": int(vlan) if vlan.isdigit() else None,
            }
        )
    return rows


def parse_trunks(output: str) -> dict[str, dict[str, Any]]:
    trunks: dict[str, dict[str, Any]] = {}
    pattern = re.compile(
        r"(?m)^\s*([A-Za-z]+\d+(?:/\d+)*)\s+\S+\s+"
        r"(802\.1q|isl|n-802\.1q|n-isl)\s+trunking\s+(\d+)\b",
        re.IGNORECASE,
    )
    for match in pattern.finditer(str(output or "")):
        encapsulation = "dot1q" if "802.1q" in match.group(2).lower() else "isl"
        trunks[normalize_interface_name(match.group(1))] = {
            "native_vlan": int(match.group(3)),
            "encapsulation": encapsulation,
            "allowed_vlans": "all",
        }
    return trunks


def parse_etherchannels(output: str) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    pattern = re.compile(
        r"(?m)^\s*(\d+)\s+Po\d+\(([^)]*)\)\s+(LACP|PAgP|-)\s+(.*)$",
        re.IGNORECASE,
    )
    for match in pattern.finditer(str(output or "")):
        protocol = match.group(3).lower()
        members = re.findall(r"([A-Za-z]+\d+(?:/\d+)*)\([A-Za-z]+\)", match.group(4))
        rows.append(
            {
                "po_number": int(match.group(1)),
                "protocol": "static" if protocol == "-" else protocol,
                "mode": "on" if protocol == "-" else "active" if protocol == "lacp" else "desirable",
                "member_ports": ",".join(normalize_interface_name(item) for item in members),
                "status": "up" if "U" in match.group(2) else "down",
            }
        )
    return rows


def parse_vtp_status(output: str) -> dict[str, Any] | None:
    text = str(output or "")
    domain = re.search(r"VTP Domain Name\s*:\s*(\S+)", text, re.IGNORECASE)
    if not domain or domain.group(1).lower() in {"null", "none", "(none)"}:
        return None
    version = re.search(r"VTP version running\s*:\s*(\d+)", text, re.IGNORECASE)
    mode = re.search(r"VTP Operating Mode\s*:\s*(\w+)", text, re.IGNORECASE)
    pruning = re.search(r"VTP Pruning Mode\s*:\s*(\w+)", text, re.IGNORECASE)
    return {
        "domain_name": domain.group(1).strip(),
        "version": int(version.group(1)) if version else 2,
        "mode": mode.group(1).lower() if mode else "transparent",
        "pruning": int(bool(pruning and pruning.group(1).lower() == "enabled")),
        "primary_server": int(bool(re.search(r"VTP Primary Server\s*:\s*local", text, re.IGNORECASE))),
    }


@dataclass
class _Database:
    db_path: str

    def _connect(self) -> sqlite3.Connection:
        connection = sqlite3.connect(self.db_path)
        connection.row_factory = sqlite3.Row
        connection.execute("PRAGMA foreign_keys = ON")
        return connection


def _module_has_local_state(conn: sqlite3.Connection, host: str, module: str) -> bool:
    table = {"vlan": "t06_vlan_db", "interfaces": "t06_interface_l2", "vtp": "t09_vtp_switches"}[module]
    return conn.execute(f"SELECT 1 FROM {table} WHERE host = ? LIMIT 1", (host,)).fetchone() is not None


def _module_is_pending(db: _Database, host: str, module: str) -> bool:
    tables = {
        "vlan": ("t06_vlan_db",),
        "interfaces": ("t06_interface_l2", "t06_etherchannel"),
        "vtp": ("t09_vtp_switches",),
    }[module]
    with closing(db._connect()) as conn:
        return any(
            conn.execute(
                f"""
                SELECT 1 FROM {table}
                WHERE host = ? AND (
                    success IN ('pending_apply','pending_delete') OR success IS NULL
                ) LIMIT 1;
                """,
                (host,),
            ).fetchone() is not None
            for table in tables
        )


def _sync_vlans(conn: sqlite3.Connection, host: str, rows: list[dict[str, Any]]) -> int:
    for row in rows:
        conn.execute(
            """
            INSERT INTO t06_vlan_db(host, vlan_id, vlan_name, state, success)
            VALUES (?, ?, ?, ?, 'synchronized')
            ON CONFLICT(host, vlan_id) DO UPDATE SET
                vlan_name = excluded.vlan_name, state = excluded.state,
                success = 'synchronized'
            """,
            (host, row["vlan_id"], row["vlan_name"], row["state"]),
        )
    return len(rows)


def _sync_interfaces(conn: sqlite3.Connection, host: str, snapshot: dict[str, str]) -> int:
    rows = parse_interface_status(snapshot.get("interfaces_status", ""))
    trunks = parse_trunks(snapshot.get("interfaces_trunk", ""))
    for row in rows:
        conn.execute(
            """
            INSERT INTO t06_interface_l2(
                host, if_name, description, mode, admin_status, oper_status,
                speed, duplex, success
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'synchronized')
            ON CONFLICT(host, if_name) DO UPDATE SET
                description = excluded.description, mode = excluded.mode,
                admin_status = excluded.admin_status, oper_status = excluded.oper_status,
                speed = excluded.speed, duplex = excluded.duplex,
                updated_at = datetime('now'), success = 'synchronized'
            """,
            (host, row["if_name"], row["description"], row["mode"], row["admin_status"],
             row["oper_status"], row["speed"] if row["speed"] in {"auto", "10", "100", "1000", "10000"} else "auto",
             row["duplex"] if row["duplex"] in {"auto", "full", "half"} else "auto"),
        )
        iface_id = conn.execute(
            "SELECT id FROM t06_interface_l2 WHERE host = ? AND if_name = ?", (host, row["if_name"])
        ).fetchone()[0]
        if row["mode"] == "access" and row["access_vlan"] is not None:
            conn.execute(
                "INSERT INTO t06_iface_access(iface_id, access_vlan) VALUES (?, ?) "
                "ON CONFLICT(iface_id) DO UPDATE SET access_vlan = excluded.access_vlan",
                (iface_id, row["access_vlan"]),
            )
        if row["if_name"] in trunks:
            trunk = trunks[row["if_name"]]
            conn.execute(
                """
                INSERT INTO t06_iface_trunk(iface_id, allowed_vlans, native_vlan, encapsulation)
                VALUES (?, ?, ?, ?)
                ON CONFLICT(iface_id) DO UPDATE SET allowed_vlans = excluded.allowed_vlans,
                    native_vlan = excluded.native_vlan, encapsulation = excluded.encapsulation
                """,
                (iface_id, trunk["allowed_vlans"], trunk["native_vlan"], trunk["encapsulation"]),
            )
    for row in parse_etherchannels(snapshot.get("etherchannel_summary", "")):
        conn.execute(
            """
            INSERT INTO t06_etherchannel(
                host, po_number, protocol, mode, member_ports, status, success
            ) VALUES (?, ?, ?, ?, ?, ?, 'synchronized')
            ON CONFLICT(host, po_number) DO UPDATE SET protocol = excluded.protocol,
                mode = excluded.mode, member_ports = excluded.member_ports,
                status = excluded.status, success = 'synchronized'
            """,
            (host, row["po_number"], row["protocol"], row["mode"], row["member_ports"], row["status"]),
        )
    return len(rows)


def _sync_vtp(conn: sqlite3.Connection, host: str, output: str) -> int:
    row = parse_vtp_status(output)
    if row is None:
        return 0
    conn.execute(
        """
        INSERT INTO t09_vtp_domains(domain_name, version, password_type, password_value)
        VALUES (?, ?, 'none', NULL)
        ON CONFLICT(domain_name) DO UPDATE SET version = excluded.version
        """,
        (row["domain_name"], row["version"]),
    )
    domain_id = conn.execute(
        "SELECT vtp_domain_id FROM t09_vtp_domains WHERE domain_name = ?", (row["domain_name"],)
    ).fetchone()[0]
    conn.execute(
        """
        INSERT INTO t09_vtp_switches(
            vtp_domain_id, host, pruning, sync_status, success
        ) VALUES (?, ?, ?, 'synchronized', 'synchronized')
        ON CONFLICT(host) DO UPDATE SET vtp_domain_id = excluded.vtp_domain_id,
            pruning = excluded.pruning, sync_status = 'synchronized',
            success = 'synchronized'
        """,
        (domain_id, host, row["pruning"]),
    )
    switch_id = conn.execute(
        "SELECT vtp_switch_id FROM t09_vtp_switches WHERE host = ?", (host,)
    ).fetchone()[0]
    conn.execute(
        """
        INSERT INTO t09_vtp_database_modes(vtp_switch_id, database_type, mode, primary_server)
        VALUES (?, 'vlan', ?, ?)
        ON CONFLICT(vtp_switch_id, database_type) DO UPDATE SET
            mode = excluded.mode, primary_server = excluded.primary_server
        """,
        (switch_id, row["mode"], row["primary_server"]),
    )
    return 1


def sync_switch_state(
    db_path: str | Path,
    host: str,
    snapshot: dict[str, str],
    mode: str = "safe",
) -> dict[str, Any]:
    """Preview or merge switch state while preserving unpushed local modules."""
    db = _Database(str(db_path))
    from .schema import ensure_switch_schema

    ensure_switch_schema(db)
    modules = {
        "vlan": bool(parse_vlan_brief(snapshot.get("vlan_brief", ""))),
        "interfaces": bool(parse_interface_status(snapshot.get("interfaces_status", ""))),
        "vtp": parse_vtp_status(snapshot.get("vtp_status", "")) is not None,
    }
    conflicts: list[str] = []
    with db._connect() as conn:
        for module, available in modules.items():
            if available and _module_has_local_state(conn, host, module) and _module_is_pending(db, host, module):
                conflicts.append(module)
    if mode == "preview":
        return {"conflicts": conflicts, "available": [key for key, value in modules.items() if value]}

    counts = {"vlans": 0, "interfaces": 0, "vtp": 0}
    applied: list[str] = []
    with db._connect() as conn, conn:
        if modules["vlan"] and (mode == "force_device_state" or "vlan" not in conflicts):
            counts["vlans"] = _sync_vlans(conn, host, parse_vlan_brief(snapshot["vlan_brief"]))
            applied.append("vlan")
        if modules["interfaces"] and (mode == "force_device_state" or "interfaces" not in conflicts):
            counts["interfaces"] = _sync_interfaces(conn, host, snapshot)
            applied.append("interfaces")
        if modules["vtp"] and (mode == "force_device_state" or "vtp" not in conflicts):
            counts["vtp"] = _sync_vtp(conn, host, snapshot["vtp_status"])
            applied.append("vtp")
    return {**counts, "conflicts": conflicts, "applied": applied}
