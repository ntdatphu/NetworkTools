from __future__ import annotations

import sqlite3
import sys
from typing import Any


def normalize_host(value: Any) -> str:
    return text_or_default(value, "")


def text_or_none(value: Any) -> str | None:
    if value is None:
        return None
    text = str(value).strip()
    return text or None


def text_or_default(value: Any, default: str) -> str:
    text = text_or_none(value)
    return text if text is not None else default


def option_action_cfg(current: dict[str, Any], submitted: dict[str, Any]) -> str:
    fields = ("defaut", "dns", "lease")
    bits = ["1" if str(current.get(field) or "") != str(submitted.get(field) or "") else "0" for field in fields]
    return "".join(bits)


def pool_identity_changed(current: dict[str, Any], submitted: dict[str, Any]) -> bool:
    return any(
        str(current.get(field) or "") != str(submitted.get(field) or "")
        for field in ("pool", "network", "subnetmask")
    )


def log_db_error(operation: str, exc: sqlite3.Error) -> None:
    print(f"[db] {operation} failed: {exc}", file=sys.stderr)


def soft_delete(conn: sqlite3.Connection, table: str, id_column: str, id_value: int) -> bool:
    cursor = conn.execute(f"UPDATE {table} SET success = -1 WHERE {id_column} = ?;", (id_value,))
    return cursor.rowcount > 0
