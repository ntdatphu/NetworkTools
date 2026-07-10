from __future__ import annotations

import sqlite3
import sys
from typing import Any

from .common import interface_table_info


def get_router_interfaces(db: Any, host: str) -> list[dict[str, Any]]:
    """Đọc danh sách interface router đang hoạt động để UI chọn helper."""
    host = (host or "").strip()
    if not host:
        return []
    try:
        with db._connect() as conn:
            iface_table, iface_column = interface_table_info(db, conn)
            rows = conn.execute(
                f"""
                SELECT iface_id, host, {iface_column} AS interface_name, ip_address, subnet_mask,
                       description, shutdown, success
                FROM {iface_table}
                WHERE host = ? AND success != -1
                ORDER BY {iface_column} COLLATE NOCASE;
                """,
                (host,),
            ).fetchall()
        return db._dict_rows(rows)
    except sqlite3.Error as exc:
        print(f"[db] getRouterInterfaces failed: {exc}", file=sys.stderr)
        return []
