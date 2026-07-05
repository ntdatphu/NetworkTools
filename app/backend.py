from __future__ import annotations

import os
import json
import sqlite3
import subprocess
import sys
from pathlib import Path
from collections.abc import Mapping, Sequence
from typing import Any

from PyQt6.QtCore import QObject, QTimer, QUrl, pyqtProperty, pyqtSignal, pyqtSlot


APP_DIR = Path(__file__).resolve().parent
QML_MODULE_DIR = APP_DIR / "NetworkTools"
DB_PATH = APP_DIR / "device_network.db"
SQL_PATH = QML_MODULE_DIR / "main.sql"
BACKEND_SERVICES_DIR = APP_DIR / "backend"
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


def _variant_list(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return rows


class AppPaths(QObject):
    @pyqtSlot(str, result=QUrl)
    def resource(self, relative_path: str) -> QUrl:
        return QUrl.fromLocalFile(str((QML_MODULE_DIR / relative_path).resolve()))


class DatabaseManager(QObject):
    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self.db_path = DB_PATH
        self.sql_path = SQL_PATH
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
        try:
            return int(str(value).strip())
        except (TypeError, ValueError):
            return None

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

    @pyqtSlot(result=bool)
    def initializeDatabase(self) -> bool:
        try:
            APP_DIR.mkdir(parents=True, exist_ok=True)
            db_exists = self.db_path.exists()
            with self._connect() as conn:
                if not db_exists or not self._table_exists(conn, "devices"):
                    script = self.sql_path.read_text(encoding="utf-8")
                    conn.executescript(script)

                self._ensure_column(
                    conn,
                    "devices",
                    "device_type",
                    "ALTER TABLE devices ADD COLUMN device_type TEXT DEFAULT 'unknown';",
                )
                self._ensure_column(
                    conn,
                    "devices",
                    "yangcfg",
                    "ALTER TABLE devices ADD COLUMN yangcfg INTEGER DEFAULT 0;",
                )
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
            return True
        except Exception as exc:
            print(f"[db] initialize failed: {exc}", file=sys.stderr)
            return False

    @pyqtSlot(str, str, str, str, str, str, result=bool)
    def addDevice(
        self,
        host: str,
        device_name: str,
        method: str,
        port_text: str,
        username: str,
        password: str,
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
                        (host, device_name, method, portnumber, username, password, success, device_type)
                    VALUES (?, ?, ?, ?, ?, ?, 0, 'unknown');
                    """,
                    (
                        host,
                        device_name or None,
                        method or None,
                        port,
                        username or None,
                        password or None,
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

    @pyqtSlot(str, str, str, str, str, str, result=bool)
    def updateDevice(
        self,
        host: str,
        device_name: str,
        method: str,
        port_text: str,
        username: str,
        password: str,
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
                    SET device_name = ?, method = ?, portnumber = ?, username = ?, password = ?
                    WHERE host = ?;
                    """,
                    (device_name or None, method or None, port, username or None, password or None, (host or "").strip()),
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
                    SELECT host, device_name, method, portnumber, username, password
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
                out.append(
                    {
                        "name": name,
                        "ip": row["host"],
                        "status": status,
                        "type": (row["device_type"] or "unknown").strip() or "unknown",
                    }
                )
            return _variant_list(out)
        except sqlite3.Error as exc:
            print(f"[db] getDevices failed: {exc}", file=sys.stderr)
            return []

    @pyqtSlot(result=bool)
    def createFoldersFromDevices(self) -> bool:
        try:
            with self._connect() as conn:
                rows = conn.execute("SELECT host FROM devices WHERE COALESCE(success, 0) != 3;").fetchall()
            backup_dir = APP_DIR / "backup"
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
    def getRouterInterfaces(self, host: str) -> list[dict[str, Any]]:
        return []

    @pyqtSlot(str, str, result="QVariant")
    def getRouterInterfaceByName(self, host: str, name: str) -> dict[str, Any]:
        return {}

    @pyqtSlot("QVariant", result=bool)
    def saveRouterInterface(self, payload: Any) -> bool:
        return True

    @pyqtSlot(int, result=bool)
    def deleteRouterInterface(self, iface_id: int) -> bool:
        return True

    @pyqtSlot(str, result="QVariant")
    def getDhcpPools(self, host: str) -> list[dict[str, Any]]:
        return []

    @pyqtSlot(str, str, str, str, str, str, str, result=bool)
    def addDhcpPool(self, host: str, pool: str, network: str, subnetmask: str, default: str, dns: str, lease: str) -> bool:
        return True

    @pyqtSlot(int, str, str, str, str, str, str, result=bool)
    def updateDhcpPool(self, dhcp_id: int, pool: str, network: str, subnetmask: str, default: str, dns: str, lease: str) -> bool:
        return True

    @pyqtSlot(int, result=bool)
    def deleteDhcpPool(self, dhcp_id: int) -> bool:
        return True

    @pyqtSlot(str, result="QVariant")
    def getExcludedAddresses(self, host: str) -> list[dict[str, Any]]:
        return []

    @pyqtSlot(str, str, str, result=bool)
    def addExcludedAddress(self, host: str, start_ip: str, end_ip: str) -> bool:
        return True

    @pyqtSlot(int, result=bool)
    def deleteExcludedAddress(self, ex_id: int) -> bool:
        return True

    @pyqtSlot(str, result="QVariant")
    def getDhcpHelperAddresses(self, host: str) -> list[dict[str, Any]]:
        return []

    @pyqtSlot(int, str, result=bool)
    def addDhcpHelperAddress(self, iface_id: int, helper_ip: str) -> bool:
        return True

    @pyqtSlot(int, result=bool)
    def deleteDhcpHelperAddress(self, helper_id: int) -> bool:
        return True

    @pyqtSlot(str, result="QVariant")
    def getStaticRouting(self, host: str) -> dict[str, Any]:
        return get_static_routing(self, host)

    @pyqtSlot(str, str, "QVariant", result=bool)
    def saveStaticRouting(self, host: str, default_value: str, routes: Any) -> bool:
        return save_static_routing(self, host, default_value, routes)

    @pyqtSlot(str, result="QVariant")
    def getOspfRouting(self, host: str) -> dict[str, Any]:
        return get_ospf_routing(self, host)

    @pyqtSlot(str, "QVariant", result=bool)
    def saveOspfRouting(self, host: str, payload: Any) -> bool:
        return save_ospf_routing(self, host, payload)

    @pyqtSlot(str, result="QVariant")
    def getEigrpRouting(self, host: str) -> dict[str, Any]:
        return get_eigrp_routing(self, host)

    @pyqtSlot(str, "QVariant", result=bool)
    def saveEigrpRouting(self, host: str, payload: Any) -> bool:
        return save_eigrp_routing(self, host, payload)

    @pyqtSlot(str, str, result="QVariant")
    def getAcls(self, host: str, acl_type: str) -> list[dict[str, Any]]:
        return []

    @pyqtSlot("QVariant", result=bool)
    def saveAcl(self, payload: Any) -> bool:
        return True

    @pyqtSlot(int, result=bool)
    def deleteAcl(self, acl_id: int) -> bool:
        return True

    @pyqtSlot(str, result="QVariant")
    def getNatStaticEntries(self, host: str) -> list[dict[str, Any]]:
        return []

    @pyqtSlot(str, str, str, str, str, result=bool)
    def addNatStaticEntry(self, host: str, local_ip: str, global_ip: str, protocol: str, description: str) -> bool:
        return True

    @pyqtSlot(int, result=bool)
    def deleteNatStaticEntry(self, nat_static_id: int) -> bool:
        return True

    @pyqtSlot(str, result="QVariant")
    def getNatInterfaces(self, host: str) -> list[dict[str, Any]]:
        return []

    @pyqtSlot(str, str, str, result=bool)
    def addNatInterface(self, host: str, interface_name: str, nat_role: str) -> bool:
        return True

    @pyqtSlot(int, result=bool)
    def deleteNatInterface(self, nat_intf_id: int) -> bool:
        return True

    @pyqtSlot(str, result="QVariant")
    def getNatDynamicPools(self, host: str) -> list[dict[str, Any]]:
        return []

    @pyqtSlot(str, str, str, str, str, result=bool)
    def addNatDynamicPool(self, host: str, pool_name: str, start_ip: str, end_ip: str, netmask: str) -> bool:
        return True

    @pyqtSlot(int, result=bool)
    def deleteNatDynamicPool(self, nat_dynamic_id: int) -> bool:
        return True

    @pyqtSlot(str, result="QVariant")
    def getNatPatRules(self, host: str) -> list[dict[str, Any]]:
        return []

    @pyqtSlot(str, str, str, str, result=bool)
    def addNatPatRule(self, host: str, acl_name: str, interface_name: str, overload: str) -> bool:
        return True

    @pyqtSlot(int, result=bool)
    def deleteNatPatRule(self, nat_pat_id: int) -> bool:
        return True

    @pyqtSlot(str, result="QVariant")
    def getNatAcls(self, host: str) -> list[dict[str, Any]]:
        return []

    @pyqtSlot("QVariant", result=bool)
    def addNatAcl(self, payload: Any) -> bool:
        return True

    @pyqtSlot(int, result=bool)
    def deleteNatAcl(self, nat_acl_id: int) -> bool:
        return True

    @pyqtSlot(str, result="QVariant")
    def getNatRouteMapEntries(self, host: str) -> list[dict[str, Any]]:
        return []

    @pyqtSlot("QVariant", result=bool)
    def addNatRouteMapEntry(self, payload: Any) -> bool:
        return True

    @pyqtSlot(int, result=bool)
    def deleteNatRouteMapEntry(self, route_map_entry_id: int) -> bool:
        return True


class TerminalHelper(QObject):
    @pyqtSlot()
    def openTerminal(self) -> None:
        if os.name == "nt":
            subprocess.Popen(["cmd.exe", "/k"], cwd=str(APP_DIR), creationflags=subprocess.CREATE_NEW_CONSOLE)
            return

        commands = [
            ["x-terminal-emulator"],
            ["gnome-terminal"],
            ["konsole"],
            ["xfce4-terminal"],
            ["xterm"],
        ]
        for command in commands:
            try:
                subprocess.Popen(command)
                return
            except OSError:
                continue

    @pyqtSlot(str)
    def pingHost(self, ip: str) -> None:
        ip = (ip or "").strip()
        if not ip:
            return

        if os.name == "nt":
            subprocess.Popen(
                ["cmd.exe", "/k", "ping", ip],
                cwd=str(APP_DIR),
                creationflags=subprocess.CREATE_NEW_CONSOLE,
            )
            return

        try:
            subprocess.Popen(["x-terminal-emulator", "-e", "ping", ip])
        except OSError:
            subprocess.Popen(["ping", ip])

    @pyqtSlot(result="QVariant")
    def ensurePythonLoginDeps(self) -> dict[str, Any]:
        return {"ok": True, "message": "PyQt6 frontend runtime is ready."}

    @pyqtSlot(str, result="QVariant")
    def connectHostAndSync(self, host: str) -> dict[str, Any]:
        return {"ok": False, "message": f"Connect backend is not ported in app yet: {host}"}


class NetworkMonitor(QObject):
    networkChanged = pyqtSignal()
    systemInfoChanged = pyqtSignal()

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._connected = True
        self._connection_type = "ethernet"
        self._network_name = "local"
        self._ram_usage_percent = 0
        self._timer = QTimer(self)
        self._timer.timeout.connect(self._refresh)
        self._timer.start(3000)
        self._refresh()

    def _refresh(self) -> None:
        self._ram_usage_percent = self._read_ram_usage()
        self.systemInfoChanged.emit()

    def _read_ram_usage(self) -> int:
        try:
            meminfo = Path("/proc/meminfo").read_text(encoding="utf-8")
            values: dict[str, int] = {}
            for line in meminfo.splitlines():
                key, _, raw = line.partition(":")
                if key in {"MemTotal", "MemAvailable"}:
                    values[key] = int(raw.strip().split()[0])
            total = values.get("MemTotal", 0)
            available = values.get("MemAvailable", 0)
            if total > 0:
                return int(((total - available) * 100) / total)
        except Exception:
            pass
        return 0

    @pyqtProperty(bool, notify=networkChanged)
    def isConnected(self) -> bool:
        return self._connected

    @pyqtProperty(str, notify=networkChanged)
    def connectionType(self) -> str:
        return self._connection_type

    @pyqtProperty(str, notify=networkChanged)
    def networkName(self) -> str:
        return self._network_name

    @pyqtProperty(int, notify=systemInfoChanged)
    def ramUsagePercent(self) -> int:
        return self._ram_usage_percent
