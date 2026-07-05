from __future__ import annotations

import json
import sqlite3
import sys
from collections.abc import Mapping, Sequence
from typing import Any

from PyQt6.QtCore import QObject, pyqtSlot

from .runtime import APP_DIR, BACKEND_SERVICES_DIR, DB_PATH, NETWORK_CODE_DB_JSON_PATH, SQL_PATH

if str(BACKEND_SERVICES_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_SERVICES_DIR))

from route import (
    get_eigrp_routing,
    get_ospf_routing,
    get_static_routing,
    save_eigrp_routing,
    save_ospf_routing,
    save_static_routing,
)

from .database_stubs import StubSlotsMixin


def _variant_list(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return rows


class DatabaseManager(StubSlotsMixin, QObject):
    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self.app_dir = APP_DIR
        self.db_path = DB_PATH
        self.sql_path = SQL_PATH
        self._last_routing_error = ""
        self.initializeDatabase()

    def _connect(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA foreign_keys = ON;")
        return conn

    def _ensure_column(self, conn: sqlite3.Connection, table: str, column: str, ddl: str) -> None:
        columns = {row["name"] for row in conn.execute(f"PRAGMA table_info({table});")}
        if column not in columns:
            conn.execute(ddl)

    def _table_exists(self, conn: sqlite3.Connection, table: str) -> bool:
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

    def _as_list(self, value: Any) -> list[Any]:
        if hasattr(value, "toVariant"):
            value = value.toVariant()
        if value is None:
            return []
        if isinstance(value, str):
            try:
                decoded = json.loads(value)
            except json.JSONDecodeError:
                return []
            return self._as_list(decoded)
        if isinstance(value, list):
            return value
        if isinstance(value, tuple):
            return list(value)
        if isinstance(value, Sequence) and not isinstance(value, (str, bytes, bytearray)):
            return list(value)
        return []

    def _as_dict(self, value: Any) -> dict[str, Any]:
        if hasattr(value, "toVariant"):
            value = value.toVariant()
        if isinstance(value, str):
            try:
                decoded = json.loads(value)
            except json.JSONDecodeError:
                return {}
            return self._as_dict(decoded)
        if isinstance(value, dict):
            return value
        if isinstance(value, Mapping):
            return dict(value)
        return {}

    def _int_or_none(self, value: Any) -> int | None:
        if value is None or value == "":
            return None
        if isinstance(value, bool):
            return int(value)
        if isinstance(value, int):
            return value
        if isinstance(value, float):
            return int(value) if value.is_integer() else None
        try:
            text = str(value).strip()
            return int(text)
        except (TypeError, ValueError):
            try:
                number = float(str(value).strip())
            except (TypeError, ValueError):
                return None
            return int(number) if number.is_integer() else None

    def _int_or_zero(self, value: Any) -> int:
        return self._int_or_none(value) or 0

    def _bool_int(self, value: Any) -> int:
        if isinstance(value, str):
            return 1 if value.strip().lower() in {"1", "true", "yes", "on"} else 0
        return 1 if bool(value) else 0

    def _str_or_none(self, value: Any) -> str | None:
        if value is None:
            return None
        text = str(value).strip()
        return text or None

    def _dict_rows(self, rows: list[sqlite3.Row]) -> list[dict[str, Any]]:
        return [dict(row) for row in rows]

    def _set_last_routing_error(self, message: str) -> None:
        self._last_routing_error = (message or "").strip()

    def _write_network_code_db_paths(self) -> None:
        NETWORK_CODE_DB_JSON_PATH.parent.mkdir(parents=True, exist_ok=True)
        data = {
            "device_network_db": str(self.db_path.resolve()),
            "main_sql": str(self.sql_path.resolve()),
        }
        NETWORK_CODE_DB_JSON_PATH.write_text(json.dumps(data, indent=4), encoding="utf-8")

    @pyqtSlot(result=str)
    def getLastRoutingError(self) -> str:
        return self._last_routing_error

    @pyqtSlot(result=bool)
    def initializeDatabase(self) -> bool:
        try:
            APP_DIR.mkdir(parents=True, exist_ok=True)
            db_exists = self.db_path.exists()
            with self._connect() as conn:
                if not db_exists or not self._table_exists(conn, "devices"):
                    script = self.sql_path.read_text(encoding="utf-8")
                    conn.executescript(script)
                self._ensure_column(conn, "devices", "os", "ALTER TABLE devices ADD COLUMN os TEXT;")
                self._ensure_column(conn, "devices", "role", "ALTER TABLE devices ADD COLUMN role TEXT;")
                self._ensure_column(conn, "devices", "admin", "ALTER TABLE devices ADD COLUMN admin INTEGER DEFAULT 0;")
                self._ensure_column(conn, "devices", "device_type", "ALTER TABLE devices ADD COLUMN device_type TEXT DEFAULT 'unknown';")
                self._ensure_column(conn, "devices", "yangcfg", "ALTER TABLE devices ADD COLUMN yangcfg INTEGER DEFAULT 0;")
                conn.execute(
                    """
                    CREATE TABLE IF NOT EXISTS yangcfg (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        host TEXT NOT NULL,
                        username TEXT,
                        password TEXT,
                        success INTEGER DEFAULT 0,
                        FOREIGN KEY (host) REFERENCES devices(host)
                            ON UPDATE CASCADE ON DELETE CASCADE
                    );
                    """
                )
                conn.commit()
            self._write_network_code_db_paths()
            return True
        except Exception as exc:
            print(f"[db] initialize failed: {exc}", file=sys.stderr)
            return False

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
        host = (host or "").strip()
        if not host:
            return False
        try:
            port = int(port_text) if str(port_text).strip() else None
        except ValueError:
            port = None
        try:
            with self._connect() as conn:
                conn.execute(
                    """
                    INSERT INTO devices
                        (host, device_name, method, portnumber, username, password, os, role, success, admin, device_type)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, 0, ?);
                    """,
                    (
                        host,
                        device_name or None,
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

    @pyqtSlot(str, result=bool)
    def deleteDevice(self, host: str) -> bool:
        try:
            with self._connect() as conn:
                conn.execute("DELETE FROM devices WHERE host = ?;", ((host or "").strip(),))
                conn.commit()
            return True
        except sqlite3.Error as exc:
            print(f"[db] deleteDevice failed: {exc}", file=sys.stderr)
            return False

    @pyqtSlot(str, int, result=bool)
    def updateDeviceSuccess(self, host: str, success: int) -> bool:
        try:
            with self._connect() as conn:
                conn.execute("UPDATE devices SET success = ? WHERE host = ?;", (success, (host or "").strip()))
                conn.commit()
            return True
        except sqlite3.Error as exc:
            print(f"[db] updateDeviceSuccess failed: {exc}", file=sys.stderr)
            return False

    @pyqtSlot(str, int, result=bool)
    def updateDeviceAdmin(self, host: str, admin: int) -> bool:
        try:
            with self._connect() as conn:
                conn.execute("UPDATE devices SET admin = ? WHERE host = ?;", (1 if admin else 0, (host or "").strip()))
                conn.commit()
            return True
        except sqlite3.Error as exc:
            print(f"[db] updateDeviceAdmin failed: {exc}", file=sys.stderr)
            return False

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
        try:
            port = int(port_text) if str(port_text).strip() else None
        except ValueError:
            port = None
        try:
            with self._connect() as conn:
                conn.execute(
                    """
                    UPDATE devices
                    SET device_name = ?, method = ?, portnumber = ?, username = ?, password = ?,
                        os = ?, role = ?, device_type = ?
                    WHERE host = ?;
                    """,
                    (
                        device_name or None,
                        method or None,
                        port,
                        username or None,
                        password or None,
                        os_name or None,
                        role or None,
                        (device_type or role or "unknown"),
                        (host or "").strip(),
                    ),
                )
                conn.commit()
            return True
        except sqlite3.Error as exc:
            print(f"[db] updateDevice failed: {exc}", file=sys.stderr)
            return False

    @pyqtSlot(str, result="QVariant")
    def getDeviceByHost(self, host: str) -> dict[str, Any]:
        try:
            with self._connect() as conn:
                row = conn.execute(
                    """
                    SELECT host, device_name, method, portnumber, username, password, os, role, device_type, admin
                    FROM devices
                    WHERE host = ?;
                    """,
                    ((host or "").strip(),),
                ).fetchone()
            if row is None:
                return {}
            return {
                "ip": row["host"],
                "name": row["device_name"] or "",
                "protocol": row["method"] or "SSH",
                "port": "" if row["portnumber"] is None else str(row["portnumber"]),
                "user": row["username"] or "",
                "pass": row["password"] or "",
                "os": row["os"] or "cisco_ios",
                "role": row["role"] or "",
                "type": row["device_type"] or "unknown",
                "admin": row["admin"] if row["admin"] is not None else 0,
            }
        except sqlite3.Error as exc:
            print(f"[db] getDeviceByHost failed: {exc}", file=sys.stderr)
            return {}

    @pyqtSlot(result="QVariant")
    def getDevices(self) -> list[dict[str, Any]]:
        try:
            with self._connect() as conn:
                rows = conn.execute(
                    """
                    SELECT host, device_name, success, device_type
                    FROM devices
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
                name = (row["device_name"] or "").strip() or row["host"]
                out.append({"name": name, "ip": row["host"], "status": status, "type": (row["device_type"] or "unknown").strip() or "unknown"})
            return _variant_list(out)
        except sqlite3.Error as exc:
            print(f"[db] getDevices failed: {exc}", file=sys.stderr)
            return []

    @pyqtSlot(result=bool)
    def createFoldersFromDevices(self) -> bool:
        try:
            with self._connect() as conn:
                rows = conn.execute("SELECT host FROM devices WHERE COALESCE(success, 0) != 3;").fetchall()
            backup_dir = self.app_dir / "backup"
            backup_dir.mkdir(exist_ok=True)
            for row in rows:
                host = (row["host"] or "").strip()
                if host:
                    (backup_dir / host).mkdir(exist_ok=True)
            return True
        except Exception as exc:
            print(f"[db] createFoldersFromDevices failed: {exc}", file=sys.stderr)
            return False

    @pyqtSlot(str, str, str, int, result=bool)
    def addYangcfg(self, host: str, username: str, password: str, success: int) -> bool:
        try:
            with self._connect() as conn:
                conn.execute(
                    "INSERT INTO yangcfg (host, username, password, success) VALUES (?, ?, ?, ?);",
                    ((host or "").strip(), username or None, password or None, success),
                )
                conn.execute("UPDATE devices SET yangcfg = 1 WHERE host = ?;", ((host or "").strip(),))
                conn.commit()
            return True
        except sqlite3.Error as exc:
            print(f"[db] addYangcfg failed: {exc}", file=sys.stderr)
            return False

    @pyqtSlot(str, result="QVariant")
    def getRoutingInfo(self, host: str) -> dict[str, Any]:
        host = (host or "").strip()
        if not host:
            return {"ok": False, "message": "Host is empty", "routes": []}
        try:
            with self._connect() as conn:
                rows = conn.execute(
                    """
                    SELECT id, host, vrf_name, protocol_code, protocol_name,
                           destination, prefix_length, administrative_distance,
                           metric, next_hop, route_age, exit_interface,
                           is_best, collected_at, raw_line
                    FROM info_routing_table
                    WHERE host = ?
                    ORDER BY
                        is_best DESC,
                        vrf_name COLLATE NOCASE,
                        protocol_code COLLATE NOCASE,
                        destination COLLATE NOCASE,
                        prefix_length DESC,
                        id ASC;
                    """,
                    (host,),
                ).fetchall()
            routes: list[dict[str, Any]] = []
            for row in rows:
                routes.append(
                    {
                        "id": row["id"],
                        "host": row["host"] or "",
                        "vrf_name": row["vrf_name"] or "default",
                        "protocol_code": row["protocol_code"] or "",
                        "protocol_name": row["protocol_name"] or "",
                        "destination": row["destination"] or "",
                        "prefix_length": row["prefix_length"] if row["prefix_length"] is not None else "",
                        "administrative_distance": row["administrative_distance"] if row["administrative_distance"] is not None else "",
                        "metric": row["metric"] if row["metric"] is not None else "",
                        "next_hop": row["next_hop"] or "",
                        "route_age": row["route_age"] or "",
                        "exit_interface": row["exit_interface"] or "",
                        "is_best": row["is_best"] if row["is_best"] is not None else 0,
                        "collected_at": row["collected_at"] or "",
                        "raw_line": row["raw_line"] or "",
                    }
                )
            return {"ok": True, "message": "Loaded routing table info", "routes": _variant_list(routes)}
        except sqlite3.Error as exc:
            print(f"[db] getRoutingInfo failed: {exc}", file=sys.stderr)
            return {"ok": False, "message": str(exc), "routes": []}

    @pyqtSlot(str, result="QVariant")
    def getStaticRouting(self, host: str) -> dict[str, Any]:
        return get_static_routing(self, host)

    @pyqtSlot(str, str, "QVariant", result=bool)
    def saveStaticRouting(self, host: str, default_value: str, routes: Any) -> bool:
        self._set_last_routing_error("")
        return save_static_routing(self, host, default_value, routes)

    @pyqtSlot(str, result="QVariant")
    def getOspfRouting(self, host: str) -> dict[str, Any]:
        return get_ospf_routing(self, host)

    @pyqtSlot(str, "QVariant", result=bool)
    def saveOspfRouting(self, host: str, payload: Any) -> bool:
        self._set_last_routing_error("")
        return save_ospf_routing(self, host, payload)

    @pyqtSlot(str, result="QVariant")
    def getEigrpRouting(self, host: str) -> dict[str, Any]:
        return get_eigrp_routing(self, host)

    @pyqtSlot(str, "QVariant", result=bool)
    def saveEigrpRouting(self, host: str, payload: Any) -> bool:
        self._set_last_routing_error("")
        return save_eigrp_routing(self, host, payload)
