"""QML slots grouped by the device responsibility."""

from __future__ import annotations

import sqlite3
import sys
from typing import Any

from PyQt6.QtCore import pyqtSlot

from infrastructure.database.paths import require_database
from .conversion import _clean_display_text, _variant_list


class DeviceSlotsMixin:
    """Provide the stable QML contract for this responsibility."""

    def _connect(self) -> sqlite3.Connection:
        """Mở kết nối SQLite chính và bật foreign key cho các thao tác DB."""
        conn = sqlite3.connect(require_database(self.db_path), timeout=10.0)
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA foreign_keys = ON;")
        conn.execute("PRAGMA busy_timeout = 10000;")
        return conn

    def _ensure_column(self, conn: sqlite3.Connection, table: str, column: str, ddl: str) -> None:
        """Add a compatibility column only when it is absent from a table."""
        columns = {row["name"] for row in conn.execute(f"PRAGMA table_info({table});")}
        if column not in columns:
            conn.execute(ddl)

    def _table_exists(self, conn: sqlite3.Connection, table: str) -> bool:
        """Return whether a named SQLite table exists in the active database."""
        row = conn.execute(
            """
            SELECT 1
            FROM sqlite_master
            WHERE type = 'table' AND name = ?
            LIMIT 1;
            """,
            (table,),
        ).fetchone()
        return row is not None

    def _table_columns(self, conn: sqlite3.Connection, table: str) -> set[str]:
        """Return the column names declared by a SQLite table."""
        return {row["name"] for row in conn.execute(f"PRAGMA table_info({table});")}

    @pyqtSlot(str, str, str, str, str, str, result=bool)
    @pyqtSlot(str, str, str, str, str, str, str, str, str, result=bool)
    def addDevice(
        self,
        host: str,
        device_name: str,
        method: str,
        port_text: str,
        username: str,
        password: str,
        os_name: str = "",
        role: str = "",
        device_type: str = "",
    ) -> bool:
        """Thêm một thiết bị mới từ UI vào bảng t01_devices."""
        host = (host or "").strip()
        if not host:
            return False
        try:
            port = int(port_text) if str(port_text).strip() else None
        except ValueError:
            return False
        if port is not None and not 1 <= port <= 65535:
            return False
        try:
            with self._connect() as conn:
                conn.execute(
                    """
                    INSERT INTO t01_devices
                        (host, device_name, method, portnumber, username, password, os, role, success, dev, device_type)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, 0, ?);
                    """,
                    (
                        host,
                        _clean_display_text(device_name) or None,
                        method or None,
                        port,
                        username or None,
                        password or None,
                        os_name or None,
                        role or None,
                        (device_type or role or "unknown"),
                    ),
                )
                conn.commit()
            return True
        except sqlite3.IntegrityError:
            return False
        except sqlite3.Error as exc:
            print(f"[db] addDevice failed: {exc}", file=sys.stderr)
            return False

    @pyqtSlot(str, result="QVariant")
    def deleteDevice(self, host: str) -> dict[str, Any]:
        """Delete one inventory device and return a QML-friendly status payload."""
        target_host = (host or "").strip()
        if not target_host:
            return {"ok": False, "severity": "warning", "message": "Delete device failed: host is empty."}
        try:
            with self._connect() as conn:
                cursor = conn.execute("DELETE FROM t01_devices WHERE host = ?;", (target_host,))
                conn.commit()
            if cursor.rowcount <= 0:
                message = f"Delete device failed for {target_host}: no database row was deleted."
                return {"ok": False, "severity": "error", "message": message}

            message = f"Device {target_host} deleted."
            return {"ok": True, "severity": "success", "message": message}
        except sqlite3.Error as exc:
            message = f"Delete device failed for {target_host}: {exc}"
            print(f"[db] deleteDevice failed: {exc}", file=sys.stderr)
            return {"ok": False, "severity": "error", "message": message}

    @pyqtSlot(str, int, result=bool)
    def updateDeviceSuccess(self, host: str, success: int) -> bool:
        """Cập nhật cờ success của thiết bị trong DB."""
        target_host = (host or "").strip()
        if not target_host:
            return False
        try:
            with self._connect() as conn:
                cursor = conn.execute("UPDATE t01_devices SET success = ? WHERE host = ?;", (success, target_host))
                conn.commit()
            if cursor.rowcount <= 0:
                return False
            return True
        except sqlite3.Error as exc:
            print(f"[db] updateDeviceSuccess failed: {exc}", file=sys.stderr)
            return False

    @pyqtSlot(str, result="QVariant")
    def resetDeviceToWaiting(self, host: str) -> dict[str, Any]:
        """Reset thiết bị disconnected về waiting để cho phép kết nối lại."""
        target_host = (host or "").strip()
        if not target_host:
            return {"ok": False, "message": "Host is empty.", "severity": "warning"}
        try:
            with self._connect() as conn:
                cursor = conn.execute(
                    "UPDATE t01_devices SET success = 0, dev = 0 WHERE host = ?;",
                    (target_host,)
                )
                conn.commit()
                if cursor.rowcount == 0:
                    return {"ok": False, "message": f"Device {target_host} not found.", "severity": "error"}
                return {"ok": True, "message": f"Device {target_host} reset to Waiting.", "severity": "success"}
        except Exception as e:
            return {"ok": False, "message": str(e), "severity": "error"}

    @pyqtSlot(str, int, result=bool)
    def updateDeviceDev(self, host: str, dev: int) -> bool:
        """Cập nhật cờ dev để đưa thiết bị vào hoặc ra khỏi luồng xử lý dev."""
        target_host = (host or "").strip()
        if not target_host:
            return False
        try:
            with self._connect() as conn:
                cursor = conn.execute("UPDATE t01_devices SET dev = ? WHERE host = ?;", (1 if dev else 0, target_host))
                conn.commit()
            if cursor.rowcount <= 0:
                return False
            return True
        except sqlite3.Error as exc:
            print(f"[db] updateDeviceDev failed: {exc}", file=sys.stderr)
            return False

    @pyqtSlot(str, int, int, result="QVariant")
    def setDeviceDevState(self, host: str, dev: int, success: int) -> dict[str, Any]:
        """Update development and connection flags together for one device."""
        target_host = (host or "").strip()
        dev_value = 1 if dev else 0
        success_value = 1 if success else 0
        action_name = "Up (Dev)" if dev_value else "Down (Dev)"
        if not target_host:
            return {"ok": False, "severity": "warning", "message": f"{action_name} failed: host is empty."}

        try:
            with self._connect() as conn:
                cursor = conn.execute(
                    "UPDATE t01_devices SET dev = ?, success = ? WHERE host = ?;",
                    (dev_value, success_value, target_host),
                )
                conn.commit()
            if cursor.rowcount <= 0:
                return {
                    "ok": False,
                    "severity": "error",
                    "message": f"{action_name} failed for {target_host}: device was not found.",
                }
            return {
                "ok": True,
                "severity": "success",
                "message": f"{action_name} applied for {target_host}.",
            }
        except sqlite3.Error as exc:
            print(f"[db] setDeviceDevState failed: {exc}", file=sys.stderr)
            return {"ok": False, "severity": "error", "message": f"{action_name} failed for {target_host}: {exc}"}

    @pyqtSlot(str, str, str, str, str, str, result=bool)
    @pyqtSlot(str, str, str, str, str, str, str, str, str, result=bool)
    def updateDevice(
        self,
        host: str,
        device_name: str,
        method: str,
        port_text: str,
        username: str,
        password: str,
        os_name: str = "",
        role: str = "",
        device_type: str = "",
    ) -> bool:
        """Cập nhật thông tin kết nối và phân loại thiết bị trong DB."""
        target_host = (host or "").strip()
        if not target_host:
            return False
        try:
            port = int(port_text) if str(port_text).strip() else None
        except ValueError:
            return False
        if port is not None and not 1 <= port <= 65535:
            return False
        try:
            with self._connect() as conn:
                row = conn.execute(
                    "SELECT host FROM t01_devices WHERE host = ?;",
                    (target_host,),
                ).fetchone()
                if row is None:
                    return False

                cursor = conn.execute(
                    """
                    UPDATE t01_devices
                    SET device_name = ?, method = ?, portnumber = ?, username = ?, password = ?,
                        os = ?, role = ?, device_type = ?
                    WHERE host = ?;
                    """,
                    (
                        _clean_display_text(device_name) or None,
                        method or None,
                        port,
                        username or None,
                        password or None,
                        os_name or None,
                        role or None,
                        (device_type or role or "unknown"),
                        target_host,
                    ),
                )
                conn.commit()
            if cursor.rowcount <= 0:
                return False
            return True
        except sqlite3.Error as exc:
            print(f"[db] updateDevice failed: {exc}", file=sys.stderr)
            return False

    @pyqtSlot(str, result="QVariant")
    def getDeviceByHost(self, host: str) -> dict[str, Any]:
        """Đọc chi tiết một thiết bị từ DB để trả về cho QML."""
        try:
            with self._connect() as conn:
                row = conn.execute(
                    """
                    SELECT host, device_name, method, portnumber, username, password, os, role, device_type, dev
                    FROM t01_devices
                    WHERE host = ?;
                    """,
                    ((host or "").strip(),),
                ).fetchone()
            if row is None:
                return {}
            return {
                "ip": row["host"],
                "name": _clean_display_text(row["device_name"]),
                "protocol": row["method"] or "SSH",
                "port": "" if row["portnumber"] is None else str(row["portnumber"]),
                "user": row["username"] or "",
                "pass": row["password"] or "",
                "os": row["os"] or "cisco_ios",
                "role": row["role"] or "",
                "type": row["device_type"] or "unknown",
                "dev": row["dev"] if row["dev"] is not None else 0,
            }
        except sqlite3.Error as exc:
            print(f"[db] getDeviceByHost failed: {exc}", file=sys.stderr)
            return {}

    @pyqtSlot(result="QVariant")
    def getDevices(self) -> list[dict[str, Any]]:
        """Đọc danh sách thiết bị để hiển thị trên panel QML."""
        try:
            with self._connect() as conn:
                rows = conn.execute(
                    """
                    SELECT host, device_name, success, role, device_type
                    FROM t01_devices
                    ORDER BY host COLLATE NOCASE;
                    """
                ).fetchall()
            out: list[dict[str, Any]] = []
            for row in rows:
                success = int(row["success"] if row["success"] is not None else 0)
                if success == 3:
                    continue
                status = {1: "connected", 0: "waiting", -1: "disconnected"}.get(success)
                if status is None:
                    continue
                name = _clean_display_text(row["device_name"]) or row["host"]
                role = (row["role"] or "").strip().lower()
                device_type = (
                    role
                    if role in {"sw2", "sw3"}
                    else (row["device_type"] or "unknown").strip() or "unknown"
                )
                out.append(
                    {
                        "name": name,
                        "ip": row["host"],
                        "status": status,
                        "role": role,
                        "type": device_type,
                    }
                )
            return _variant_list(out)
        except sqlite3.Error as exc:
            print(f"[db] getDevices failed: {exc}", file=sys.stderr)
            return []
