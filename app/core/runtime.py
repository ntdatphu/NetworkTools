from __future__ import annotations

import os
import sqlite3
import subprocess
import sys
from pathlib import Path
from typing import Any

from PyQt6.QtCore import QObject, QTimer, QUrl, pyqtProperty, pyqtSignal, pyqtSlot


APP_DIR = Path(__file__).resolve().parent.parent
QML_MODULE_DIR = APP_DIR / "NetworkTools"
DB_PATH = APP_DIR / "device_network.db"
SQL_PATH = QML_MODULE_DIR / "main.sql"
BACKEND_SERVICES_DIR = APP_DIR / "backend"
NETWORK_CODE_DIR = APP_DIR / "network_code"
NETWORK_CODE_DB_JSON_PATH = NETWORK_CODE_DIR / "database_paths.json"

if str(BACKEND_SERVICES_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_SERVICES_DIR))
if str(NETWORK_CODE_DIR) not in sys.path:
    sys.path.insert(0, str(NETWORK_CODE_DIR))


def normalize_device_type(os_name: str | None) -> str:
    if not os_name:
        return "cisco_ios"

    normalized = os_name.strip().lower().replace("-", "_").replace(" ", "_")
    aliases = {
        "ios": "cisco_ios",
        "cisco_ios": "cisco_ios",
        "ios_xe": "cisco_xe",
        "cisco_xe": "cisco_xe",
        "nxos": "cisco_nxos",
        "cisco_nxos": "cisco_nxos",
        "asa": "cisco_asa",
        "cisco_asa": "cisco_asa",
        "mikrotik": "mikrotik_routeros",
        "mikrotik_routeros": "mikrotik_routeros",
    }
    return aliases.get(normalized, normalized)


def load_device_for_login(host: str) -> dict[str, Any] | None:
    host = (host or "").strip()
    if not host:
        return None

    with sqlite3.connect(DB_PATH) as conn:
        conn.row_factory = sqlite3.Row
        row = conn.execute(
            """
            SELECT host, method, portnumber, username, password, os
            FROM devices
            WHERE host = ?;
            """,
            (host,),
        ).fetchone()

    if row is None:
        return None

    method = (row["method"] or "ssh").strip().lower()
    return {
        "host": row["host"],
        "method": method,
        "port": row["portnumber"] or (23 if method == "telnet" else 22),
        "username": row["username"] or "",
        "password": row["password"] or "",
        "device_type": normalize_device_type(row["os"]),
    }


def update_device_flag(host: str, column: str, value: int) -> None:
    if column not in {"admin", "success"}:
        raise ValueError(f"Unsupported devices column: {column}")
    with sqlite3.connect(DB_PATH) as conn:
        conn.execute(f"UPDATE devices SET {column} = ? WHERE host = ?;", (value, (host or "").strip()))
        conn.commit()


def open_terminal(app_dir: Path) -> None:
    if os.name == "nt":
        subprocess.Popen(["cmd.exe", "/k"], cwd=str(app_dir), creationflags=subprocess.CREATE_NEW_CONSOLE)
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


def ping_host(app_dir: Path, ip: str) -> None:
    if os.name == "nt":
        subprocess.Popen(
            ["cmd.exe", "/k", "ping", ip],
            cwd=str(app_dir),
            creationflags=subprocess.CREATE_NEW_CONSOLE,
        )
        return

    try:
        subprocess.Popen(["x-terminal-emulator", "-e", "ping", ip])
    except OSError:
        subprocess.Popen(["ping", ip])


def read_ram_usage_percent() -> int:
    try:
        import psutil  # type: ignore

        return int(psutil.virtual_memory().percent)
    except Exception:
        pass

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


class AppPaths(QObject):
    @pyqtSlot(str, result=QUrl)
    def resource(self, relative_path: str) -> QUrl:
        return QUrl.fromLocalFile(str((QML_MODULE_DIR / relative_path).resolve()))


class TerminalHelper(QObject):
    @pyqtSlot()
    def openTerminal(self) -> None:
        open_terminal(APP_DIR)

    @pyqtSlot(str)
    def pingHost(self, ip: str) -> None:
        ip = (ip or "").strip()
        if not ip:
            return
        ping_host(APP_DIR, ip)

    @pyqtSlot(result="QVariant")
    def ensurePythonLoginDeps(self) -> dict[str, Any]:
        return {"ok": True, "message": "PyQt6 frontend runtime is ready."}

    @pyqtSlot(str, result="QVariant")
    def connectHostAndSync(self, host: str) -> dict[str, Any]:
        host = (host or "").strip()
        if not host:
            return {"ok": False, "message": "Host is empty."}

        connector = None
        try:
            device = load_device_for_login(host)
            if device is None:
                return {"ok": False, "message": f"Device {host} was not found in database."}

            from login.device_connector import DeviceConnector

            connector = DeviceConnector(
                device["host"],
                device["method"],
                device["port"],
                device["username"],
                device["password"],
                device_type=device["device_type"],
                start_config_mode=True,
            )

            if not connector.connect():
                update_device_flag(host, "success", -1)
                return {"ok": False, "message": f"Login failed for {host}."}

            update_device_flag(host, "success", 1)
            backup_dir = APP_DIR / "backup" / host
            backup_dir.mkdir(parents=True, exist_ok=True)
            backup_ok = connector.save_running_config(str(backup_dir))

            if backup_ok:
                return {"ok": True, "message": f"Connected {host}; running-config saved in backup/{host}."}
            return {"ok": True, "message": f"Connected {host}; running-config backup failed."}
        except Exception as exc:
            try:
                update_device_flag(host, "success", -1)
            except Exception:
                pass
            return {"ok": False, "message": f"Connect failed for {host}: {exc}"}
        finally:
            if connector is not None:
                connector.disconnect()


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
        self._ram_usage_percent = read_ram_usage_percent()
        self.systemInfoChanged.emit()

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
