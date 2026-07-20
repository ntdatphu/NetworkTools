"""SQLite repository owning device inventory and status persistence."""

from __future__ import annotations

import sqlite3
from pathlib import Path
from typing import Any

from infrastructure.database.paths import DEVICE_NETWORK_DB, require_database


class DeviceRepository:
    """Provide transactional access to t01_devices and related device rows."""

    def __init__(self, db_path: str | Path = DEVICE_NETWORK_DB) -> None:
        """Store the injected database path without opening a connection eagerly."""
        self.db_path = Path(db_path)

    def _connect(self) -> sqlite3.Connection:
        """Open the required database with row and foreign-key support."""
        connection = sqlite3.connect(require_database(self.db_path), timeout=10.0)
        connection.row_factory = sqlite3.Row
        connection.execute("PRAGMA foreign_keys = ON;")
        connection.execute("PRAGMA busy_timeout = 10000;")
        return connection

    def get_login(self, host: str) -> dict[str, Any] | None:
        """Read the credential-bearing row used only by connection services."""
        with self._connect() as connection:
            row = connection.execute(
                "SELECT host, method, portnumber, username, password, os, dev FROM t01_devices WHERE host = ?;",
                ((host or "").strip(),),
            ).fetchone()
        return dict(row) if row is not None else None

    def update_flag(self, host: str, column: str, value: int) -> bool:
        """Update one allow-listed device state flag transactionally."""
        if column not in {"dev", "success"}:
            raise ValueError(f"Unsupported t01_devices column: {column}")
        with self._connect() as connection:
            cursor = connection.execute(
                f"UPDATE t01_devices SET {column} = ? WHERE host = ?;",
                (int(value), (host or "").strip()),
            )
            connection.commit()
            return cursor.rowcount > 0

    def reset_to_waiting(self, host: str) -> bool:
        """Reset a closed device session to waiting and non-dev state."""
        with self._connect() as connection:
            cursor = connection.execute(
                "UPDATE t01_devices SET success = 0, dev = 0 WHERE host = ?;",
                ((host or "").strip(),),
            )
            connection.commit()
            return cursor.rowcount > 0
