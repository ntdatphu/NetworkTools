from __future__ import annotations

import hashlib
import json
from contextlib import closing
from typing import Any

from .schema import ensure_switch_schema


def payload_hash(payload: dict[str, Any]) -> str:
    canonical = json.dumps(payload, ensure_ascii=True, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()


def is_payload_pending(db: Any, host: str, module_name: str, payload: dict[str, Any]) -> bool:
    ensure_switch_schema(db)
    fingerprint = payload_hash(payload)
    with closing(db._connect()) as conn:
        row = conn.execute(
            """
            SELECT payload_hash
            FROM t06_switch_push_state
            WHERE host = ? AND module_name = ?;
            """,
            (host, module_name),
        ).fetchone()
    return row is None or row["payload_hash"] != fingerprint


def mark_payload_applied(
    db: Any, host: str, module_name: str, payload: dict[str, Any]
) -> None:
    ensure_switch_schema(db)
    with closing(db._connect()) as conn:
        with conn:
            conn.execute(
                """
                INSERT INTO t06_switch_push_state(host, module_name, payload_hash, pushed_at)
                VALUES (?, ?, ?, datetime('now'))
                ON CONFLICT(host, module_name) DO UPDATE SET
                    payload_hash = excluded.payload_hash,
                    pushed_at = excluded.pushed_at;
                """,
                (host, module_name, payload_hash(payload)),
            )
