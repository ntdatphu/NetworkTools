from __future__ import annotations

import sqlite3
from typing import Any

from .common import log_db_error, normalize_host, soft_delete, text_or_default


def get_dhcp_helper_addresses(db: Any, host: str) -> list[dict[str, Any]]:
    host = normalize_host(host)
    if not host:
        return []
    try:
        with db._connect() as conn:
            rows = conn.execute(
                """
                SELECT h.id, h.iface_id, i.interface_name AS interface_name, h.helper_ip, h.success
                FROM t03_router_iface_helper AS h
                JOIN t02_interface_name AS i ON i.iface_id = h.iface_id
                WHERE i.host = ? AND h.success != -1 AND i.success != -1
                ORDER BY i.t02_interface_name COLLATE NOCASE, h.id ASC;
                """,
                (host,),
            ).fetchall()
        return db._dict_rows(rows)
    except sqlite3.Error as exc:
        log_db_error("getDhcpHelperAddresses", exc)
        return []


def add_dhcp_helper_address(db: Any, iface_id: int, helper_ip: str) -> bool:
    helper = text_or_default(helper_ip, "")
    if iface_id < 0 or not helper:
        return False
    try:
        with db._connect() as conn:
            conn.execute(
                """
                INSERT INTO t03_router_iface_helper (iface_id, helper_ip, success)
                VALUES (?, ?, 0)
                ON CONFLICT(iface_id, helper_ip)
                DO UPDATE SET success = 0;
                """,
                (iface_id, helper),
            )
            conn.commit()
        return True
    except sqlite3.Error as exc:
        log_db_error("addDhcpHelperAddress", exc)
        return False


def delete_dhcp_helper_address(db: Any, helper_id: int) -> bool:
    try:
        with db._connect() as conn:
            deleted = soft_delete(conn, "t03_router_iface_helper", "id", helper_id)
            conn.commit()
        return deleted
    except sqlite3.Error as exc:
        log_db_error("deleteDhcpHelperAddress", exc)
        return False
