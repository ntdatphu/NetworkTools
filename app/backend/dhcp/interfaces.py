from __future__ import annotations

import sqlite3
import sys
from typing import Any


def get_router_interfaces(db: Any, host: str) -> list[dict[str, Any]]:
    host = (host or "").strip()
    if not host:
        return []
    try:
        with db._connect() as conn:
            rows = conn.execute(
                """
                SELECT iface_id, host, interface_name, ip_address, subnet_mask,
                       description, shutdown, success
                FROM interface_name
                WHERE host = ? AND success != -1
                ORDER BY interface_name COLLATE NOCASE;
                """,
                (host,),
            ).fetchall()
        return db._dict_rows(rows)
    except sqlite3.Error as exc:
        print(f"[db] getRouterInterfaces failed: {exc}", file=sys.stderr)
        return []
