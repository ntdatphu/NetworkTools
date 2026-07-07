from __future__ import annotations

import sqlite3
from typing import Any

from .common import log_db_error, normalize_host, soft_delete, text_or_default


def get_excluded_addresses(db: Any, host: str) -> list[dict[str, Any]]:
    host = normalize_host(host)
    if not host:
        return []
    try:
        with db._connect() as conn:
            rows = conn.execute(
                """
                SELECT ex_id, host, start_ip, end_ip, success
                FROM excluded_address
                WHERE host = ? AND success != -1
                ORDER BY ex_id ASC;
                """,
                (host,),
            ).fetchall()
        return db._dict_rows(rows)
    except sqlite3.Error as exc:
        log_db_error("getExcludedAddresses", exc)
        return []


def add_excluded_address(db: Any, host: str, start_ip: str, end_ip: str) -> bool:
    host = normalize_host(host)
    start = text_or_default(start_ip, "")
    end = text_or_default(end_ip, "")
    if not host or not start or not end:
        return False
    try:
        with db._connect() as conn:
            conn.execute(
                """
                INSERT INTO excluded_address (host, start_ip, end_ip, success)
                VALUES (?, ?, ?, 0);
                """,
                (host, start, end),
            )
            conn.commit()
        return True
    except sqlite3.Error as exc:
        log_db_error("addExcludedAddress", exc)
        return False


def delete_excluded_address(db: Any, ex_id: int) -> bool:
    try:
        with db._connect() as conn:
            soft_delete(conn, "excluded_address", "ex_id", ex_id)
            conn.commit()
        return True
    except sqlite3.Error as exc:
        log_db_error("deleteExcludedAddress", exc)
        return False
