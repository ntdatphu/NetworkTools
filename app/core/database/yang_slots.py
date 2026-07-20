"""QML slots grouped by the yang responsibility."""

from __future__ import annotations

import sqlite3
import sys

from PyQt6.QtCore import pyqtSlot


class YangSlotsMixin:
    """Provide the stable QML contract for this responsibility."""

    @pyqtSlot(str, str, str, int, result=bool)
    def addYangcfg(self, host: str, username: str, password: str, success: int) -> bool:
        """Ghi thông tin YANG config và bật cờ t01_yangcfg cho thiết bị."""
        try:
            with self._connect() as conn:
                conn.execute(
                    "INSERT INTO t01_yangcfg (host, username, password, success) VALUES (?, ?, ?, ?);",
                    ((host or "").strip(), username or None, password or None, success),
                )
                conn.execute("UPDATE t01_devices SET t01_yangcfg = 1 WHERE host = ?;", ((host or "").strip(),))
                conn.commit()
            return True
        except sqlite3.Error as exc:
            print(f"[db] addYangcfg failed: {exc}", file=sys.stderr)
            return False
