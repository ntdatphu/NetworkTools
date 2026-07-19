from __future__ import annotations

import sqlite3
from contextlib import closing
from typing import Any

from .common import choice, failed, integer, ok, text
from .schema import ensure_switch_schema


def get_vlans(db: Any, host: str) -> list[dict[str, Any]]:
    target = text(host)
    if not target:
        return []
    with closing(db._connect()) as conn:
        rows = conn.execute(
            """
            SELECT v.id, v.vlan_id, v.vlan_name, v.state,
                   COUNT(i.id) AS access_port_count
            FROM t06_vlan_db AS v
            LEFT JOIN t06_iface_access AS a ON a.access_vlan = v.vlan_id
            LEFT JOIN t06_interface_l2 AS i ON i.id = a.iface_id AND i.host = v.host
            WHERE v.host = ?
            GROUP BY v.id
            ORDER BY v.vlan_id;
            """,
            (target,),
        ).fetchall()
    return [dict(row) for row in rows]


def save_vlan(db: Any, host: str, payload: dict[str, Any]) -> dict[str, Any]:
    target = text(host)
    if not target:
        return failed("Host is required")
    try:
        ensure_switch_schema(db)
        row_id = int(payload.get("id") or 0)
        vlan_id = integer(payload.get("vlan_id"), "VLAN ID", 1, 4094)
        name = text(payload.get("vlan_name"))
        state = choice(payload.get("state"), "VLAN state", {"active", "suspend"}, "active")
        with closing(db._connect()) as conn:
            with conn:
                if row_id > 0:
                    cursor = conn.execute(
                        """
                        UPDATE t06_vlan_db
                        SET vlan_id = ?, vlan_name = ?, state = ?
                        WHERE id = ? AND host = ?;
                        """,
                        (vlan_id, name, state, row_id, target),
                    )
                    if cursor.rowcount == 0:
                        raise ValueError("The selected VLAN no longer exists")
                    saved_id = row_id
                else:
                    cursor = conn.execute(
                        "INSERT INTO t06_vlan_db(host, vlan_id, vlan_name, state) VALUES (?, ?, ?, ?);",
                        (target, vlan_id, name, state),
                    )
                    saved_id = int(cursor.lastrowid)
        return ok("VLAN saved to the local workspace", id=saved_id)
    except (sqlite3.Error, ValueError) as exc:
        return failed(str(exc))
