from __future__ import annotations

import sqlite3
from collections.abc import Iterable
from pathlib import Path
from typing import Any

from .models import SyslogMessage


class SyslogRepository:
    def __init__(self, info_db: Path, device_db: Path) -> None:
        self.info_db = info_db
        self.device_db = device_db

    def _info_connection(self) -> sqlite3.Connection:
        if not self.info_db.is_file():
            raise FileNotFoundError(self.info_db)
        conn = sqlite3.connect(self.info_db, timeout=10)
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA journal_mode=WAL")
        conn.execute("PRAGMA busy_timeout=10000")
        return conn

    def _device_connection(self) -> sqlite3.Connection:
        if not self.device_db.is_file():
            raise FileNotFoundError(self.device_db)
        conn = sqlite3.connect(self.device_db, timeout=10)
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA busy_timeout=10000")
        return conn

    def connected_devices(self) -> list[dict[str, Any]]:
        with self._device_connection() as conn:
            rows = conn.execute(
                """SELECT host, device_name, device_type FROM t01_devices
                   WHERE success = 1
                   ORDER BY COALESCE(NULLIF(TRIM(device_name), ''), host) COLLATE NOCASE"""
            ).fetchall()
        return [dict(row) for row in rows]

    def resolve_device_host(self, source_ip: str) -> str | None:
        with self._device_connection() as conn:
            row = conn.execute("SELECT host FROM t01_devices WHERE host = ? LIMIT 1", (source_ip,)).fetchone()
            if row:
                return str(row["host"])
            row = conn.execute(
                "SELECT host FROM t02_interface_name WHERE ip_address = ? ORDER BY success DESC LIMIT 1",
                (source_ip,),
            ).fetchone()
        return str(row["host"]) if row else None

    def source_interface(self, host: str) -> str | None:
        with self._device_connection() as conn:
            row = conn.execute(
                """SELECT interface_name FROM t02_interface_name
                   WHERE host = ? AND ip_address = ? AND COALESCE(shutdown, 0) = 0
                   ORDER BY CASE WHEN success = 1 THEN 0 ELSE 1 END, iface_id LIMIT 1""",
                (host, host),
            ).fetchone()
        return str(row["interface_name"]) if row else None

    def is_connected(self, host: str) -> bool:
        with self._device_connection() as conn:
            row = conn.execute("SELECT 1 FROM t01_devices WHERE host = ? AND success = 1", (host,)).fetchone()
        return row is not None

    def insert_messages(self, messages: Iterable[SyslogMessage]) -> list[dict[str, Any]]:
        rows = list(messages)
        if not rows:
            return []
        sql = """INSERT INTO t12_syslog_messages
            (device_host, source_ip, device_time, received_at, facility, severity,
             mnemonic, message, raw_message, protocol, parse_status)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"""
        with self._info_connection() as conn:
            conn.executemany(sql, [(
                row.device_host, row.source_ip, row.device_time, row.received_at,
                row.facility, row.severity, row.mnemonic, row.message,
                row.raw_message, row.protocol, row.parse_status,
            ) for row in rows])
            last_id = int(conn.execute("SELECT last_insert_rowid()").fetchone()[0])
            conn.commit()
        first_id = max(1, last_id - len(rows) + 1) if last_id else 0
        result = []
        for offset, row in enumerate(rows):
            item = row.to_dict()
            item["id"] = first_id + offset if first_id else 0
            result.append(item)
        return result

    def query_messages(self, filters: dict[str, Any], before_id: int = 0, limit: int = 200) -> list[dict[str, Any]]:
        clauses: list[str] = []
        params: list[Any] = []
        host = str(filters.get("host") or "").strip()
        search = str(filters.get("search") or "").strip()
        severities = [int(x) for x in filters.get("severities", []) if 0 <= int(x) <= 7]
        if host:
            clauses.append("device_host = ?")
            params.append(host)
        if search:
            clauses.append("(message LIKE ? ESCAPE '\\' OR mnemonic LIKE ? ESCAPE '\\')")
            escaped = search.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
            params.extend((f"%{escaped}%", f"%{escaped}%"))
        if severities:
            clauses.append(f"severity IN ({','.join('?' for _ in severities)})")
            params.extend(severities)
        if before_id > 0:
            clauses.append("id < ?")
            params.append(before_id)
        where = " WHERE " + " AND ".join(clauses) if clauses else ""
        params.append(max(1, min(int(limit), 500)))
        with self._info_connection() as conn:
            rows = conn.execute(
                "SELECT * FROM t12_syslog_messages" + where + " ORDER BY id DESC LIMIT ?", params
            ).fetchall()
        return [dict(row) for row in rows]

    def save_device_state(self, host: str, server_ip: str, protocol: str, port: int,
                          interface: str | None, configured: bool, result: str) -> None:
        with self._info_connection() as conn:
            conn.execute(
                """INSERT INTO t12_syslog_device_state
                   (device_host, server_ip, protocol, port, source_interface, configured, last_result, updated_at)
                   VALUES (?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
                   ON CONFLICT(device_host, server_ip, protocol, port) DO UPDATE SET
                     source_interface=excluded.source_interface,
                     configured=excluded.configured,
                     last_result=excluded.last_result,
                     updated_at=CURRENT_TIMESTAMP""",
                (host, server_ip, protocol, port, interface, int(configured), result),
            )
            conn.commit()

    def configured_hosts(self, server_ip: str, protocol: str, port: int) -> set[str]:
        with self._info_connection() as conn:
            rows = conn.execute(
                """SELECT device_host FROM t12_syslog_device_state
                   WHERE server_ip = ? AND protocol = ? AND port = ? AND configured = 1""",
                (server_ip, protocol, port),
            ).fetchall()
        return {str(row["device_host"]) for row in rows}

    def delete_expired(self, retention_days: int, batch_size: int = 5_000) -> int:
        total = 0
        modifier = f"-{max(1, int(retention_days))} days"
        with self._info_connection() as conn:
            while True:
                cursor = conn.execute(
                    """DELETE FROM t12_syslog_messages WHERE id IN (
                         SELECT id FROM t12_syslog_messages
                         WHERE received_at < datetime('now', ?) LIMIT ?
                       )""",
                    (modifier, max(100, min(int(batch_size), 10_000))),
                )
                conn.commit()
                deleted = max(0, int(cursor.rowcount))
                total += deleted
                if deleted < batch_size:
                    break
        return total
