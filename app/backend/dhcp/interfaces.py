from __future__ import annotations

import sqlite3
from typing import Any

from .common import log_db_error, normalize_host


def get_router_interfaces(db: Any, host: str) -> list[dict[str, Any]]:
    host = normalize_host(host)
    if not host:
        return []
    try:
        with db._connect() as conn:
            rows = conn.execute(
                """
                SELECT iface_id, host, t02_interface_name AS interface_name, ip_address, subnet_mask,
                       description, shutdown, success
                FROM t02_interface_name
                WHERE host = ? AND success != -1
                ORDER BY t02_interface_name COLLATE NOCASE;
                """,
                (host,),
            ).fetchall()
        return db._dict_rows(rows)
    except sqlite3.Error as exc:
        log_db_error("getRouterInterfaces", exc)
        return []
