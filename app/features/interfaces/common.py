from __future__ import annotations

import sqlite3
import sys
from contextlib import contextmanager
from typing import Any


@contextmanager
def db_connection(db: Any):
    conn = db._connect()
    try:
        with conn:
            yield conn
    finally:
        conn.close()


def normalize_host(value: Any) -> str:
    return str(value or "").strip()


def text_or_none(value: Any) -> str | None:
    if value is None:
        return None
    text = str(value).strip()
    return text or None


def log_db_error(operation: str, exc: sqlite3.Error) -> None:
    print(f"[db/interfaces] {operation} failed: {exc}", file=sys.stderr)
