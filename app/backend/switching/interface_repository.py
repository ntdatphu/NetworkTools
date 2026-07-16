from __future__ import annotations

import sqlite3
from contextlib import closing
from typing import Any

from .common import (
    boolean,
    choice,
    failed,
    integer,
    ok,
    optional_vlan,
    text,
    validate_vlan_expression,
)
from .navigation import normalize_switch_role
from .schema import ensure_switch_schema


def get_switch_interfaces(db: Any, host: str) -> list[dict[str, Any]]:
    target = text(host)
    if not target:
        return []
    with closing(db._connect()) as conn:
        rows = conn.execute(
            """
            SELECT i.id, i.if_name, i.description, i.mode, i.admin_status,
                   i.oper_status, i.speed, i.duplex, i.updated_at,
                   a.access_vlan, a.voice_vlan,
                   t.allowed_vlans, t.native_vlan, t.encapsulation, t.pruning_vlans,
                   s.portfast, s.bpduguard, s.bpdufilter, s.root_guard, s.loop_guard,
                   ps.max_mac, ps.violation, ps.sticky, ps.aging_type, ps.aging_time,
                   CASE WHEN ps.iface_id IS NULL THEN 0 ELSE 1 END AS port_security_enabled,
                   sc.bc_level, sc.mc_level, sc.uc_level, sc.action AS storm_action,
                   CASE WHEN sc.iface_id IS NULL THEN 0 ELSE 1 END AS storm_enabled
            FROM t06_interface_l2 AS i
            LEFT JOIN t06_iface_access AS a ON a.iface_id = i.id
            LEFT JOIN t06_iface_trunk AS t ON t.iface_id = i.id
            LEFT JOIN t06_iface_stp AS s ON s.iface_id = i.id
            LEFT JOIN t06_iface_port_security AS ps ON ps.iface_id = i.id
            LEFT JOIN t06_iface_storm_control AS sc ON sc.iface_id = i.id
            WHERE i.host = ?
            ORDER BY i.if_name COLLATE NOCASE;
            """,
            (target,),
        ).fetchall()
    return [dict(row) for row in rows]


def _require_vlan(conn: sqlite3.Connection, host: str, vlan_id: int, field: str) -> None:
    found = conn.execute(
        "SELECT 1 FROM t06_vlan_db WHERE host = ? AND vlan_id = ?;",
        (host, vlan_id),
    ).fetchone()
    if found is None:
        raise ValueError(f"{field} {vlan_id} does not exist on this switch")


def _save_mode_profile(
    conn: sqlite3.Connection,
    host: str,
    iface_id: int,
    mode: str,
    payload: dict[str, Any],
) -> None:
    if mode == "access":
        access_vlan = integer(payload.get("access_vlan", 1), "Access VLAN", 1, 4094)
        voice_vlan = optional_vlan(payload.get("voice_vlan"), "Voice VLAN")
        if voice_vlan == access_vlan:
            raise ValueError("Voice VLAN must differ from Access VLAN")
        _require_vlan(conn, host, access_vlan, "Access VLAN")
        if voice_vlan is not None:
            _require_vlan(conn, host, voice_vlan, "Voice VLAN")
        conn.execute("DELETE FROM t06_iface_trunk WHERE iface_id = ?;", (iface_id,))
        conn.execute(
            """
            INSERT INTO t06_iface_access(iface_id, access_vlan, voice_vlan)
            VALUES (?, ?, ?)
            ON CONFLICT(iface_id) DO UPDATE SET
                access_vlan = excluded.access_vlan,
                voice_vlan = excluded.voice_vlan;
            """,
            (iface_id, access_vlan, voice_vlan),
        )
        return

    if mode == "trunk":
        native_vlan = integer(payload.get("native_vlan", 1), "Native VLAN", 1, 4094)
        _require_vlan(conn, host, native_vlan, "Native VLAN")
        allowed = validate_vlan_expression(
            payload.get("allowed_vlans"), "Allowed VLANs", "all"
        )
        pruning = validate_vlan_expression(
            payload.get("pruning_vlans"), "Pruning VLANs", "none"
        )
        encapsulation = choice(
            payload.get("encapsulation"),
            "Encapsulation",
            {"dot1q", "isl"},
            "dot1q",
        )
        conn.execute("DELETE FROM t06_iface_access WHERE iface_id = ?;", (iface_id,))
        conn.execute(
            """
            INSERT INTO t06_iface_trunk(
                iface_id, allowed_vlans, native_vlan, encapsulation, pruning_vlans
            ) VALUES (?, ?, ?, ?, ?)
            ON CONFLICT(iface_id) DO UPDATE SET
                allowed_vlans = excluded.allowed_vlans,
                native_vlan = excluded.native_vlan,
                encapsulation = excluded.encapsulation,
                pruning_vlans = excluded.pruning_vlans;
            """,
            (iface_id, allowed, native_vlan, encapsulation, pruning),
        )
        return

    conn.execute("DELETE FROM t06_iface_access WHERE iface_id = ?;", (iface_id,))
    conn.execute("DELETE FROM t06_iface_trunk WHERE iface_id = ?;", (iface_id,))


def _save_optional_profiles(
    conn: sqlite3.Connection,
    iface_id: int,
    mode: str,
    payload: dict[str, Any],
) -> None:
    if mode == "routed":
        conn.execute("DELETE FROM t06_iface_stp WHERE iface_id = ?;", (iface_id,))
        conn.execute("DELETE FROM t06_iface_port_security WHERE iface_id = ?;", (iface_id,))
        conn.execute("DELETE FROM t06_iface_storm_control WHERE iface_id = ?;", (iface_id,))
        return

    conn.execute(
        """
        INSERT INTO t06_iface_stp(
            iface_id, portfast, bpduguard, bpdufilter, root_guard, loop_guard
        ) VALUES (?, ?, ?, ?, ?, ?)
        ON CONFLICT(iface_id) DO UPDATE SET
            portfast = excluded.portfast,
            bpduguard = excluded.bpduguard,
            bpdufilter = excluded.bpdufilter,
            root_guard = excluded.root_guard,
            loop_guard = excluded.loop_guard;
        """,
        (
            iface_id,
            choice(payload.get("portfast"), "PortFast", {"enabled", "disabled"}, "disabled"),
            choice(payload.get("bpduguard"), "BPDU Guard", {"enabled", "disabled"}, "disabled"),
            choice(payload.get("bpdufilter"), "BPDU Filter", {"enabled", "disabled"}, "disabled"),
            choice(payload.get("root_guard"), "Root Guard", {"enabled", "disabled"}, "disabled"),
            choice(payload.get("loop_guard"), "Loop Guard", {"enabled", "disabled"}, "disabled"),
        ),
    )

    if boolean(payload.get("port_security_enabled")):
        if mode != "access":
            raise ValueError("Port Security can only be enabled on an access port")
        max_mac = integer(payload.get("max_mac", 1), "Maximum MAC", 1, 16384)
        aging_time = integer(payload.get("aging_time", 0), "Aging time", 0, 1_000_000)
        conn.execute(
            """
            INSERT INTO t06_iface_port_security(
                iface_id, max_mac, violation, sticky, aging_type, aging_time
            ) VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(iface_id) DO UPDATE SET
                max_mac = excluded.max_mac,
                violation = excluded.violation,
                sticky = excluded.sticky,
                aging_type = excluded.aging_type,
                aging_time = excluded.aging_time;
            """,
            (
                iface_id,
                max_mac,
                choice(
                    payload.get("violation"),
                    "Violation",
                    {"shutdown", "restrict", "protect"},
                    "shutdown",
                ),
                boolean(payload.get("sticky")),
                choice(
                    payload.get("aging_type"),
                    "Aging type",
                    {"absolute", "inactivity"},
                    "absolute",
                ),
                aging_time,
            ),
        )
    else:
        conn.execute("DELETE FROM t06_iface_port_security WHERE iface_id = ?;", (iface_id,))

    if boolean(payload.get("storm_enabled")):
        try:
            levels = [
                float(payload.get(key, default))
                for key, default in (
                    ("bc_level", 20),
                    ("mc_level", 20),
                    ("uc_level", 80),
                )
            ]
        except (TypeError, ValueError) as exc:
            raise ValueError("Storm Control levels must be numeric") from exc
        if any(level < 0 or level > 100 for level in levels):
            raise ValueError("Storm Control levels must be between 0 and 100")
        conn.execute(
            """
            INSERT INTO t06_iface_storm_control(
                iface_id, bc_level, mc_level, uc_level, action
            ) VALUES (?, ?, ?, ?, ?)
            ON CONFLICT(iface_id) DO UPDATE SET
                bc_level = excluded.bc_level,
                mc_level = excluded.mc_level,
                uc_level = excluded.uc_level,
                action = excluded.action;
            """,
            (
                iface_id,
                *levels,
                choice(
                    payload.get("storm_action"),
                    "Storm action",
                    {"shutdown", "trap", "none"},
                    "shutdown",
                ),
            ),
        )
    else:
        conn.execute("DELETE FROM t06_iface_storm_control WHERE iface_id = ?;", (iface_id,))


def save_switch_interface(
    db: Any, host: str, payload: dict[str, Any]
) -> dict[str, Any]:
    """Save an interface and all related profiles in one transaction."""
    target = text(host)
    if not target:
        return failed("Host is required")
    try:
        ensure_switch_schema(db)
        row_id = int(payload.get("id") or 0)
        if_name = text(payload.get("if_name"))
        if not if_name:
            raise ValueError("Interface name is required")
        mode = choice(
            payload.get("mode"),
            "Mode",
            {"access", "trunk", "hybrid", "routed"},
            "access",
        )
        values = (
            if_name,
            text(payload.get("description")),
            mode,
            choice(payload.get("admin_status"), "Admin status", {"up", "down"}, "up"),
            choice(
                payload.get("oper_status"),
                "Oper status",
                {"up", "down", "err-disabled", "unknown"},
                "unknown",
            ),
            choice(
                payload.get("speed"),
                "Speed",
                {"auto", "10", "100", "1000", "10000"},
                "auto",
            ),
            choice(payload.get("duplex"), "Duplex", {"auto", "full", "half"}, "auto"),
        )
        with closing(db._connect()) as conn:
            with conn:
                if mode == "routed":
                    device = conn.execute(
                        "SELECT role FROM t01_devices WHERE host = ?;", (target,)
                    ).fetchone()
                    if device is None or normalize_switch_role(device["role"]) != "sw3":
                        raise ValueError("Routed ports require device role sw3")
                if row_id > 0:
                    cursor = conn.execute(
                        """
                        UPDATE t06_interface_l2
                        SET if_name = ?, description = ?, mode = ?, admin_status = ?,
                            oper_status = ?, speed = ?, duplex = ?,
                            updated_at = datetime('now')
                        WHERE id = ? AND host = ?;
                        """,
                        (*values, row_id, target),
                    )
                    if cursor.rowcount == 0:
                        raise ValueError("The selected interface no longer exists")
                    saved_id = row_id
                else:
                    cursor = conn.execute(
                        """
                        INSERT INTO t06_interface_l2(
                            host, if_name, description, mode, admin_status,
                            oper_status, speed, duplex
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?);
                        """,
                        (target, *values),
                    )
                    saved_id = int(cursor.lastrowid)
                _save_mode_profile(conn, target, saved_id, mode, payload)
                _save_optional_profiles(conn, saved_id, mode, payload)
        return ok("Interface saved to the local workspace", id=saved_id)
    except (sqlite3.Error, ValueError, TypeError) as exc:
        return failed(str(exc))
