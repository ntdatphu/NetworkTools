from __future__ import annotations

import sqlite3
import sys
from typing import Any

from .common import table_name, text_or_default


def get_excluded_addresses(db: Any, host: str) -> list[dict[str, Any]]:
    host = (host or "").strip()
    if not host:
        return []
    try:
        with db._connect() as conn:
            excluded_table = table_name(db, conn, "excluded_address", "t03_excluded_address")
            rows = conn.execute(
                f"""
                SELECT ex_id, host, start_ip, end_ip, success
                FROM {excluded_table}
                WHERE host = ? AND success != -1
                ORDER BY ex_id ASC;
                """,
                (host,),
            ).fetchall()
        return db._dict_rows(rows)
    except sqlite3.Error as exc:
        print(f"[db] getExcludedAddresses failed: {exc}", file=sys.stderr)
        return []


def add_excluded_address(db: Any, host: str, start_ip: str, end_ip: str) -> bool:
    host = (host or "").strip()
    start = text_or_default(start_ip, "")
    end = text_or_default(end_ip, "")
    if not host or not start or not end:
        return False
    try:
        with db._connect() as conn:
            excluded_table = table_name(db, conn, "excluded_address", "t03_excluded_address")
            conn.execute(
                f"""
                INSERT INTO {excluded_table} (host, start_ip, end_ip, success)
                VALUES (?, ?, ?, 0);
                """,
                (host, start, end),
            )
            conn.commit()
        return True
    except sqlite3.Error as exc:
        print(f"[db] addExcludedAddress failed: {exc}", file=sys.stderr)
        return False


def delete_excluded_address(db: Any, ex_id: int) -> bool:
    try:
        with db._connect() as conn:
            excluded_table = table_name(db, conn, "excluded_address", "t03_excluded_address")
            conn.execute(f"UPDATE {excluded_table} SET success = -1 WHERE ex_id = ?;", (ex_id,))
            conn.commit()
        return True
    except sqlite3.Error as exc:
        print(f"[db] deleteExcludedAddress failed: {exc}", file=sys.stderr)
        return False
