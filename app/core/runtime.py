from __future__ import annotations

import os
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

if str(BACKEND_SERVICES_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_SERVICES_DIR))


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
