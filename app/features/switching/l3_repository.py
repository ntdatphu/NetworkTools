from __future__ import annotations

import sqlite3
from contextlib import closing
from typing import Any

from .common import boolean, failed, integer, ok, text, validate_ipv4_pair
from .navigation import normalize_switch_role
from .schema import ensure_switch_schema


def _require_sw3(conn: sqlite3.Connection, host: str) -> None:
    row = conn.execute("SELECT role FROM t01_devices WHERE host = ?;", (host,)).fetchone()
    if row is None or normalize_switch_role(row["role"]) != "sw3":
        raise ValueError("Layer 3 switch features require device role sw3")


def get_ip_routing(db: Any, host: str) -> dict[str, Any]:
    target = text(host)
    if not target:
        return {"ip_routing": 0, "updated_at": ""}
    ensure_switch_schema(db)
    with closing(db._connect()) as conn:
        row = conn.execute(
            "SELECT ip_routing, updated_at FROM t06_switch_l3_config WHERE host = ?;",
            (target,),
        ).fetchone()
    return dict(row) if row else {"ip_routing": 0, "updated_at": ""}


def save_ip_routing(db: Any, host: str, enabled: Any) -> dict[str, Any]:
    target = text(host)
    if not target:
        return failed("Host is required")
    try:
        ensure_switch_schema(db)
        with closing(db._connect()) as conn:
            with conn:
                _require_sw3(conn, target)
                conn.execute(
                    """
                    INSERT INTO t06_switch_l3_config(host, ip_routing, updated_at)
                    VALUES (?, ?, datetime('now'))
                    ON CONFLICT(host) DO UPDATE SET
                        ip_routing = excluded.ip_routing,
                        updated_at = excluded.updated_at;
                    """,
                    (target, boolean(enabled)),
                )
        return ok("IP routing preference saved to the local workspace")
    except (sqlite3.Error, ValueError) as exc:
        return failed(str(exc))


def get_svis(db: Any, host: str) -> list[dict[str, Any]]:
    target = text(host)
    if not target:
        return []
    ensure_switch_schema(db)
    with closing(db._connect()) as conn:
        rows = conn.execute(
            """
            SELECT s.id, s.vlan_id, v.vlan_name, s.ip_address,
                   s.subnet_mask, s.shutdown, s.success
            FROM t06_svi_interface AS s
            JOIN t06_vlan_db AS v ON v.host = s.host AND v.vlan_id = s.vlan_id
            WHERE s.host = ? AND s.success != -1
            ORDER BY s.vlan_id;
            """,
            (target,),
        ).fetchall()
    return [dict(row) for row in rows]


def save_svi(db: Any, host: str, payload: dict[str, Any]) -> dict[str, Any]:
    target = text(host)
    if not target:
        return failed("Host is required")
    try:
        ensure_switch_schema(db)
        row_id = int(payload.get("id") or 0)
        vlan_id = integer(payload.get("vlan_id"), "VLAN ID", 1, 4094)
        ip_address, subnet_mask = validate_ipv4_pair(
            payload.get("ip_address"), payload.get("subnet_mask")
        )
        with closing(db._connect()) as conn:
            with conn:
                _require_sw3(conn, target)
                if conn.execute(
                    "SELECT 1 FROM t06_vlan_db WHERE host = ? AND vlan_id = ?;",
                    (target, vlan_id),
                ).fetchone() is None:
                    raise ValueError(f"VLAN {vlan_id} does not exist on this switch")
                duplicate_ip = conn.execute(
                    """
                    SELECT 1 FROM t06_svi_interface
                    WHERE host = ? AND ip_address = ? AND id != ? AND success != -1;
                    """,
                    (target, ip_address, row_id),
                ).fetchone()
                if ip_address and duplicate_ip is not None:
                    raise ValueError("The IPv4 address is already assigned to another SVI")
                if row_id > 0:
                    cursor = conn.execute(
                        """
                        UPDATE t06_svi_interface
                        SET vlan_id = ?, ip_address = ?, subnet_mask = ?,
                            shutdown = ?, success = 0
                        WHERE id = ? AND host = ?;
                        """,
                        (
                            vlan_id,
                            ip_address,
                            subnet_mask,
                            boolean(payload.get("shutdown")),
                            row_id,
                            target,
                        ),
                    )
                    if cursor.rowcount == 0:
                        raise ValueError("The selected SVI no longer exists")
                    saved_id = row_id
                else:
                    cursor = conn.execute(
                        """
                        INSERT INTO t06_svi_interface(
                            host, vlan_id, ip_address, subnet_mask, shutdown, success
                        ) VALUES (?, ?, ?, ?, ?, 0);
                        """,
                        (
                            target,
                            vlan_id,
                            ip_address,
                            subnet_mask,
                            boolean(payload.get("shutdown")),
                        ),
                    )
                    saved_id = int(cursor.lastrowid)
        return ok("SVI saved to the local workspace", id=saved_id)
    except (sqlite3.Error, ValueError) as exc:
        return failed(str(exc))
