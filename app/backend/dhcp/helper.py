from __future__ import annotations

import sqlite3
import sys
from typing import Any

from .common import text_or_default


def get_dhcp_helper_addresses(db: Any, host: str) -> list[dict[str, Any]]:
    host = (host or "").strip()
    if not host:
        return []
    try:
        with db._connect() as conn:
            rows = conn.execute(
                """
                SELECT h.id, h.iface_id, i.interface_name, h.helper_ip, h.success
                FROM router_iface_helper AS h
                JOIN interface_name AS i ON i.iface_id = h.iface_id
                WHERE i.host = ? AND h.success != -1 AND i.success != -1
                ORDER BY i.interface_name COLLATE NOCASE, h.id ASC;
                """,
                (host,),
            ).fetchall()
        return db._dict_rows(rows)
    except sqlite3.Error as exc:
        print(f"[db] getDhcpHelperAddresses failed: {exc}", file=sys.stderr)
        return []


def add_dhcp_helper_address(db: Any, iface_id: int, helper_ip: str) -> bool:
    helper = text_or_default(helper_ip, "")
    if iface_id < 0 or not helper:
        return False
    try:
        with db._connect() as conn:
            conn.execute(
                """
                INSERT INTO router_iface_helper (iface_id, helper_ip, success)
                VALUES (?, ?, 0)
                ON CONFLICT(iface_id, helper_ip)
                DO UPDATE SET success = 0;
                """,
                (iface_id, helper),
            )
            conn.commit()
        return True
    except sqlite3.Error as exc:
        print(f"[db] addDhcpHelperAddress failed: {exc}", file=sys.stderr)
        return False


def delete_dhcp_helper_address(db: Any, helper_id: int) -> bool:
    try:
        with db._connect() as conn:
            conn.execute("UPDATE router_iface_helper SET success = -1 WHERE id = ?;", (helper_id,))
            conn.commit()
        return True
    except sqlite3.Error as exc:
        print(f"[db] deleteDhcpHelperAddress failed: {exc}", file=sys.stderr)
        return False
