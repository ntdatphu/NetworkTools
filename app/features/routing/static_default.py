from __future__ import annotations

import sqlite3
from typing import Any


def fetch_default_route(conn: sqlite3.Connection, host: str) -> sqlite3.Row | None:
    """Đọc default static route hiện hành của một thiết bị."""
    return conn.execute(
        """
        SELECT id, next_hop_ip, success
        FROM t04_static_default_routes
        WHERE host = ? AND success != -1
        ORDER BY id DESC
        LIMIT 1;
        """,
        (host,),
    ).fetchone()


def replace_default_route(conn: sqlite3.Connection, host: str, default_value: str) -> None:
    """Mark default route cũ cần xóa và thêm default route mới nếu có."""
    default_text = (default_value or "").strip()
    conn.execute(
        """
        UPDATE t04_static_default_routes
        SET success = -1
        WHERE host = ? AND success != -1;
        """,
        (host,),
    )
    if default_text:
        conn.execute(
            """
            INSERT INTO t04_static_default_routes (host, next_hop_ip, success)
            VALUES (?, ?, 0);
            """,
            (host, default_text),
        )


def default_route_payload(default_row: sqlite3.Row | None) -> dict[str, Any]:
    """Chuyển row default route thành payload trả về cho QML."""
    return {
        "default_route_id": default_row["id"] if default_row else 0,
        "default_route": default_row["next_hop_ip"] if default_row else "",
        "default_route_success": default_row["success"] if default_row else 0,
    }
