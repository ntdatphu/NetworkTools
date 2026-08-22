"""SQLite repository for Cisco Syslog configuration state."""

from __future__ import annotations

from contextlib import closing
from pathlib import Path

from .connections import info_connection


class DeviceStateRepository:
    def __init__(self, info_db: Path) -> None:
        self.info_db = Path(info_db)

    def save_device_state(
        self, host: str, server_ip: str, protocol: str, port: int,
        interface: str | None, configured: bool, result: str,
    ) -> None:
        with closing(info_connection(self.info_db)) as conn:
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

    def save_device_attempt(
        self, host: str, server_ip: str, protocol: str, port: int, result: str,
    ) -> None:
        with closing(info_connection(self.info_db)) as conn:
            conn.execute(
                """INSERT INTO t12_syslog_device_state
                   (device_host, server_ip, protocol, port, configured, last_result, updated_at)
                   VALUES (?, ?, ?, ?, 0, ?, CURRENT_TIMESTAMP)
                   ON CONFLICT(device_host, server_ip, protocol, port) DO UPDATE SET
                     last_result=excluded.last_result,
                     updated_at=CURRENT_TIMESTAMP""",
                (host, server_ip, protocol, port, result),
            )
            conn.commit()

    def configured_hosts(self, server_ip: str, protocol: str, port: int) -> set[str]:
        with closing(info_connection(self.info_db)) as conn:
            rows = conn.execute(
                """SELECT device_host FROM t12_syslog_device_state
                   WHERE server_ip = ? AND protocol = ? AND port = ? AND configured = 1""",
                (server_ip, protocol, port),
            ).fetchall()
        return {str(row["device_host"]) for row in rows}


__all__ = ["DeviceStateRepository"]
