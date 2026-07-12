"""Resolve UI interface names to the canonical interface foreign key."""

import sqlite3


def require_iface_id(conn: sqlite3.Connection, host: str, interface_name: str) -> int:
    row = conn.execute(
        "SELECT iface_id FROM t02_interface_name WHERE host = ? AND interface_name = ? LIMIT 1;",
        (host, interface_name),
    ).fetchone()
    if row is None:
        raise ValueError(f"Interface {interface_name!r} does not exist for host {host!r}")
    return int(row["iface_id"])
