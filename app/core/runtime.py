from __future__ import annotations

import os
import shlex
import sqlite3
import socket
import subprocess
import sys
import locale
import threading
from contextlib import closing
from ipaddress import ip_address
from pathlib import Path
from typing import Any

from PyQt6.QtCore import QObject, QSettings, QThread, QTimer, QUrl, pyqtProperty, pyqtSignal, pyqtSlot

from .background_task import BackgroundTask


APP_DIR = Path(__file__).resolve().parent.parent
QML_MODULE_DIR = APP_DIR / "UI"
DB_PATH = APP_DIR / "device_network.db"
EXTERNAL_TOOLS_DB_PATH = APP_DIR / "external_tools.db"
SQL_PATH = QML_MODULE_DIR / "main_numbered_tables.sql"
BACKEND_SERVICES_DIR = APP_DIR / "backend"
NETWORK_CODE_DIR = APP_DIR / "network_code"
NETWORK_CODE_DB_JSON_PATH = NETWORK_CODE_DIR / "database_paths.json"
NETWORK_TASK_TIMEOUT_SECONDS = 15

if str(BACKEND_SERVICES_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_SERVICES_DIR))
if str(NETWORK_CODE_DIR) not in sys.path:
    sys.path.insert(0, str(NETWORK_CODE_DIR))


def normalize_device_type(os_name: str | None) -> str:
    """Chuẩn hóa tên OS/device type trước khi backend đăng nhập thiết bị."""
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
    """Đọc thông tin đăng nhập thiết bị từ DB để phục vụ luồng connect."""
    host = (host or "").strip()
    if not host:
        return None

    with sqlite3.connect(DB_PATH) as conn:
        conn.row_factory = sqlite3.Row
        row = conn.execute(
            """
            SELECT host, method, portnumber, username, password, os, dev
            FROM t01_devices
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
        "dev": int(row["dev"] if row["dev"] is not None else 0),
    }


def is_dev_device(device: dict[str, Any] | None) -> bool:
    if not device:
        return False
    try:
        return int(device.get("dev") or 0) == 1
    except (TypeError, ValueError):
        return False


def update_device_flag(host: str, column: str, value: int) -> bool:
    """Ghi cờ trạng thái được phép cập nhật trực tiếp trong t01_devices."""
    if column not in {"dev", "success"}:
        raise ValueError(f"Unsupported t01_devices column: {column}")
    with sqlite3.connect(DB_PATH) as conn:
        cursor = conn.execute(f"UPDATE t01_devices SET {column} = ? WHERE host = ?;", (value, (host or "").strip()))
        conn.commit()
        return cursor.rowcount > 0


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


class DeviceSessionRegistry:
    """Owns network device sessions for the lifetime of open UI tabs."""

    def __init__(self) -> None:
        self._lock = threading.RLock()
        self._sessions: dict[str, Any] = {}

    def _is_alive(self, connector: Any) -> bool:
        if connector is None or not bool(getattr(connector, "connected", False)):
            return False

        connection = getattr(connector, "connection", None)
        if connection is None:
            return False

        is_alive = getattr(connection, "is_alive", None)
        if callable(is_alive):
            try:
                return bool(is_alive())
            except Exception:
                return False

        return True

    def _disconnect(self, connector: Any) -> None:
        try:
            connector.disconnect()
        except Exception as exc:
            print(f"[app] Device session disconnect failed: {exc}", file=sys.stderr)

    def _prepare_cli_session(self, connector: Any) -> None:
        connection = getattr(connector, "connection", None)
        if connection is None:
            raise RuntimeError("Netmiko connection was not created.")

        check_enable_mode = getattr(connection, "check_enable_mode", None)
        enable = getattr(connection, "enable", None)
        if callable(check_enable_mode) and callable(enable) and not check_enable_mode():
            enable()

        check_config_mode = getattr(connection, "check_config_mode", None)
        exit_config_mode = getattr(connection, "exit_config_mode", None)
        if callable(check_config_mode) and callable(exit_config_mode) and check_config_mode():
            exit_config_mode()

    def open(self, host: str) -> dict[str, Any]:
        host = (host or "").strip()
        if not host:
            return {"ok": False, "severity": "warning", "message": "Open session failed: host is empty."}

        with self._lock:
            current = self._sessions.get(host)
            if self._is_alive(current):
                return {"ok": True, "severity": "info", "message": f"Session for {host} is already open."}
            if current is not None:
                self._sessions.pop(host, None)
                self._disconnect(current)

        device = load_device_for_login(host)
        if device is None:
            return {"ok": False, "severity": "error", "message": f"Open session failed for {host}: device was not found in database."}
        if is_dev_device(device):
            return {
                "ok": True,
                "severity": "info",
                "message": f"{host} is a dev-test host; no SSH/Telnet session was opened.",
            }

        method = str(device.get("method") or "").strip().lower()
        if method not in {"ssh", "telnet"}:
            return {
                "ok": True,
                "severity": "info",
                "message": f"{host} uses {method.upper() or 'non-CLI'}; no persistent CLI session was opened.",
            }

        connector = None
        try:
            from login.device_connector import DeviceConnector

            connector = DeviceConnector(
                device["host"],
                method,
                device["port"],
                device["username"],
                device["password"],
                device_type=device["device_type"],
                start_config_mode=False,
                timeout=NETWORK_TASK_TIMEOUT_SECONDS,
            )
            if not connector.connect():
                reason = str(getattr(connector, "last_error", "") or "login failed")
                return {"ok": False, "severity": "error", "message": f"Open session failed for {host}: {reason}."}

            self._prepare_cli_session(connector)

            with self._lock:
                previous = self._sessions.pop(host, None)
                if previous is not None and previous is not connector:
                    self._disconnect(previous)
                self._sessions[host] = connector

            return {"ok": True, "severity": "success", "message": f"Session opened for {host}."}
        except Exception as exc:
            if connector is not None:
                self._disconnect(connector)
            print(f"[app] Open session failed for {host}: {exc}", file=sys.stderr)
            return {"ok": False, "severity": "error", "message": f"Open session failed for {host}: {exc}"}

    def close(self, host: str) -> dict[str, Any]:
        host = (host or "").strip()
        if not host:
            return {"ok": False, "severity": "warning", "message": "Close session failed: host is empty."}

        with self._lock:
            connector = self._sessions.pop(host, None)

        if connector is None:
            return {"ok": True, "severity": "info", "message": f"No open session for {host}."}

        self._disconnect(connector)
        return {"ok": True, "severity": "success", "message": f"Session closed for {host}."}

    def close_all(self) -> None:
        with self._lock:
            sessions = list(self._sessions.values())
            self._sessions.clear()
        for connector in sessions:
            self._disconnect(connector)

    def get_connector(self, host: str) -> Any | None:
        host = (host or "").strip()
        if not host:
            return None

        with self._lock:
            connector = self._sessions.get(host)
            if self._is_alive(connector):
                return connector
            if connector is not None:
                self._sessions.pop(host, None)

        if connector is not None:
            self._disconnect(connector)
        return None

    def has_session(self, host: str) -> bool:
        return self.get_connector(host) is not None


device_session_registry = DeviceSessionRegistry()


def _ping_probe_command(ip: str) -> list[str]:
    if os.name == "nt":
        return ["ping", "-n", "1", "-w", "1200", ip]
    if sys.platform == "darwin":
        return ["ping", "-c", "1", "-W", "1200", ip]
    return ["ping", "-c", "1", "-W", "2", ip]


def _last_non_empty_line(text: str) -> str:
    for line in reversed((text or "").splitlines()):
        stripped = line.strip()
        if stripped:
            return stripped
    return ""


def ping_host(app_dir: Path, ip: str) -> dict[str, Any]:
    probe_command = _ping_probe_command(ip)
    try:
        kwargs: dict[str, Any] = {
            "capture_output": True,
            "check": False,
            "timeout": 4,
        }
        if os.name == "nt":
            kwargs["creationflags"] = getattr(subprocess, "CREATE_NO_WINDOW", 0)
        result = subprocess.run(probe_command, **kwargs)
    except subprocess.TimeoutExpired:
        return {
            "ok": False,
            "severity": "error",
            "message": f"Ping failed for {ip}: request timed out.",
        }
    except OSError as exc:
        return {
            "ok": False,
            "severity": "error",
            "message": f"Ping failed for {ip}: could not start ping command ({exc}).",
        }

    output = _decode_command_output((result.stdout or b"") + (result.stderr or b""))
    if result.returncode != 0:
        detail = _last_non_empty_line(output)
        reason = detail or "host is unreachable or did not respond."
        return {
            "ok": False,
            "severity": "error",
            "message": f"Ping failed for {ip}: {reason}",
        }

    if os.name == "nt":
        try:
            subprocess.Popen(
                ["cmd.exe", "/k", "ping", ip],
                cwd=str(app_dir),
                creationflags=subprocess.CREATE_NEW_CONSOLE,
            )
        except OSError as exc:
            return {
                "ok": False,
                "severity": "warning",
                "message": f"Ping succeeded for {ip}, but opening the ping terminal failed: {exc}",
            }
        return {
            "ok": True,
            "severity": "success",
            "message": f"Ping succeeded for {ip}; terminal ping opened.",
        }

    try:
        subprocess.Popen(["x-terminal-emulator", "-e", "ping", ip])
        return {
            "ok": True,
            "severity": "success",
            "message": f"Ping succeeded for {ip}; terminal ping opened.",
        }
    except OSError:
        try:
            subprocess.Popen(["ping", ip])
            return {
                "ok": True,
                "severity": "success",
                "message": f"Ping succeeded for {ip}; background ping started.",
            }
        except OSError as exc:
            return {
                "ok": False,
                "severity": "warning",
                "message": f"Ping succeeded for {ip}, but opening a ping terminal failed: {exc}",
            }


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


VIRTUAL_INTERFACE_MARKERS = (
    "bluetooth",
    "docker",
    "hyper-v",
    "loopback",
    "npcap",
    "tap",
    "teredo",
    "tunnel",
    "virtual",
    "virtualbox",
    "vmware",
    "vethernet",
    "wsl",
)

WIFI_INTERFACE_MARKERS = (
    "802.11",
    "airport",
    "wi-fi",
    "wifi",
    "wireless",
    "wlan",
)

VPN_INTERFACE_MARKERS = (
    "cloudflarewarp",
    "openvpn",
    "ppp",
    "tailscale",
    "utun",
    "vpn",
    "warp",
    "wireguard",
    "zerotier",
)

ETHERNET_INTERFACE_MARKERS = (
    "ethernet",
    "eth",
    "en0",
    "eno",
    "enp",
    "ens",
    "gigabit",
    "lan",
    "local area connection",
)


def _is_usable_ip_address(raw_address: str | None) -> bool:
    if not raw_address:
        return False
    try:
        address = ip_address(raw_address.split("%", 1)[0])
    except ValueError:
        return False
    return not (
        address.is_loopback
        or address.is_link_local
        or address.is_multicast
        or address.is_unspecified
    )


def _connection_type_for_interface(name: str) -> str:
    normalized = name.casefold()
    if any(marker in normalized for marker in VPN_INTERFACE_MARKERS):
        return "vpn"
    if any(marker in normalized for marker in WIFI_INTERFACE_MARKERS):
        return "wifi"
    if any(marker in normalized for marker in ETHERNET_INTERFACE_MARKERS):
        return "ethernet"
    return "other"


def _is_virtual_interface(name: str) -> bool:
    normalized = name.casefold()
    return any(marker in normalized for marker in VIRTUAL_INTERFACE_MARKERS)


def _default_route_local_ip() -> str:
    for family, destination in (
        (socket.AF_INET, ("8.8.8.8", 80)),
        (socket.AF_INET6, ("2001:4860:4860::8888", 80, 0, 0)),
    ):
        try:
            with socket.socket(family, socket.SOCK_DGRAM) as sock:
                sock.connect(destination)
                return str(sock.getsockname()[0])
        except OSError:
            continue
    return ""


def _decode_command_output(data: bytes) -> str:
    encodings = ["utf-8-sig", locale.getpreferredencoding(False)]
    if os.name == "nt":
        encodings.extend(["mbcs", "cp65001", "cp850", "cp437"])

    seen: set[str] = set()
    for encoding in encodings:
        if not encoding or encoding in seen:
            continue
        seen.add(encoding)
        try:
            return data.decode(encoding)
        except (LookupError, UnicodeDecodeError):
            continue

    return data.decode("utf-8", errors="replace")


def _run_text_command(command: list[str], timeout: float = 2.0) -> str:
    try:
        kwargs: dict[str, Any] = {
            "capture_output": True,
            "check": False,
            "timeout": timeout,
        }
        if os.name == "nt":
            kwargs["creationflags"] = getattr(subprocess, "CREATE_NO_WINDOW", 0)

        result = subprocess.run(command, **kwargs)
    except (OSError, subprocess.TimeoutExpired):
        return ""

    output = result.stdout or result.stderr or b""
    return _decode_command_output(output).strip()


def _read_windows_wifi_ssid(interface_name: str) -> str:
    output = _run_text_command(["netsh", "wlan", "show", "interfaces"])
    if not output:
        return ""

    blocks: list[dict[str, str]] = []
    current: dict[str, str] = {}

    for raw_line in output.splitlines():
        if ":" not in raw_line:
            continue

        key, value = raw_line.split(":", 1)
        key = key.strip().casefold()
        value = value.strip()

        if key == "name":
            if current:
                blocks.append(current)
            current = {"name": value}
        elif key == "ssid" and value:
            current["ssid"] = value

    if current:
        blocks.append(current)

    interface_key = interface_name.casefold()
    for block in blocks:
        if block.get("name", "").casefold() == interface_key and block.get("ssid"):
            return block["ssid"]

    for block in blocks:
        if block.get("ssid"):
            return block["ssid"]

    return ""


def _read_macos_wifi_ssid(interface_name: str) -> str:
    output = _run_text_command(["networksetup", "-getairportnetwork", interface_name])
    if not output or ":" not in output:
        return ""
    return output.split(":", 1)[1].strip()


def _read_linux_wifi_ssid(interface_name: str) -> str:
    output = _run_text_command(["iwgetid", interface_name, "-r"])
    if output:
        return output.splitlines()[0].strip()

    output = _run_text_command(["iw", "dev", interface_name, "link"])
    for line in output.splitlines():
        stripped = line.strip()
        if stripped.startswith("SSID:"):
            return stripped.split(":", 1)[1].strip()
    return ""


def _read_wifi_ssid(interface_name: str) -> str:
    if os.name == "nt":
        return _read_windows_wifi_ssid(interface_name)
    if sys.platform == "darwin":
        return _read_macos_wifi_ssid(interface_name)
    return _read_linux_wifi_ssid(interface_name)


def read_network_info() -> tuple[bool, str, str]:
    try:
        import psutil  # type: ignore
    except Exception:
        return False, "none", ""

    try:
        stats_by_name = psutil.net_if_stats()
        addrs_by_name = psutil.net_if_addrs()
    except Exception:
        return False, "none", ""

    default_ip = _default_route_local_ip()
    candidates: list[dict[str, Any]] = []

    for name, addrs in addrs_by_name.items():
        stats = stats_by_name.get(name)
        if stats is None or not stats.isup:
            continue

        usable_addresses = []
        for addr in addrs:
            if addr.family in {socket.AF_INET, socket.AF_INET6} and _is_usable_ip_address(addr.address):
                usable_addresses.append(addr.address.split("%", 1)[0])

        if not usable_addresses:
            continue

        connection_type = _connection_type_for_interface(name)
        is_default = default_ip in usable_addresses
        is_virtual = _is_virtual_interface(name)
        type_rank = 0 if connection_type in {"wifi", "ethernet"} else 1
        virtual_rank = 1 if is_virtual else 0

        candidates.append(
            {
                "name": name,
                "type": connection_type,
                "is_default": is_default,
                "is_virtual": is_virtual,
                "rank": (0 if is_default else 1, virtual_rank, type_rank, name.casefold()),
            }
        )

    if not candidates:
        return False, "none", ""

    candidates.sort(key=lambda item: item["rank"])
    selected = candidates[0]
    network_name = selected["name"]
    if selected["type"] == "wifi":
        network_name = _read_wifi_ssid(network_name) or network_name
    return True, selected["type"], network_name


class AppPaths(QObject):
    @pyqtSlot(str, result=QUrl)
    def resource(self, relative_path: str) -> QUrl:
        return QUrl.fromLocalFile(str((QML_MODULE_DIR / relative_path).resolve()))


class TerminalHelper(QObject):
    taskStarted = pyqtSignal(str)
    taskProgress = pyqtSignal(str)
    taskFinished = pyqtSignal(bool, str)
    connectHostFinished = pyqtSignal(str, bool, str)
    deviceSessionFinished = pyqtSignal(str, bool, str)
    deviceCommandFinished = pyqtSignal(str, str, bool, str, str)
    runningConfigFinished = pyqtSignal(str, bool, str)

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._background_tasks: dict[str, dict[str, Any]] = {}

    def _start_background_task(
        self,
        task_key: str,
        kind: str,
        host: str,
        start_message: str,
        callback: Any,
        metadata: dict[str, Any] | None = None,
    ) -> bool:
        if task_key in self._background_tasks:
            message = f"A {kind.replace('-', ' ')} task is already running for {host}."
            self.taskFinished.emit(False, message)
            return False

        thread = QThread(self)
        worker = BackgroundTask(task_key, start_message, callback)
        worker.moveToThread(thread)

        self._background_tasks[task_key] = {
            "thread": thread,
            "worker": worker,
            "kind": kind,
            "host": host,
            "metadata": metadata or {},
        }

        thread.started.connect(worker.run)
        worker.taskStarted.connect(self._relay_task_started)
        worker.taskProgress.connect(self._relay_task_progress)
        worker.taskFinished.connect(self._handle_background_task_finished)
        worker.taskFinished.connect(lambda *_args, t=thread: t.quit())
        worker.taskFinished.connect(lambda *_args, w=worker: w.deleteLater())
        thread.finished.connect(thread.deleteLater)
        thread.start()
        return True

    @pyqtSlot(str)
    def _relay_task_started(self, message: str) -> None:
        self.taskStarted.emit(message)

    @pyqtSlot(str)
    def _relay_task_progress(self, message: str) -> None:
        self.taskProgress.emit(message)

    @pyqtSlot(str, bool, str, object)
    def _handle_background_task_finished(self, task_key: str, ok: bool, message: str, result: object) -> None:
        entry = self._background_tasks.pop(task_key, {})
        kind = str(entry.get("kind") or "")
        host = str(entry.get("host") or "")
        metadata = entry.get("metadata") if isinstance(entry.get("metadata"), dict) else {}

        if kind == "connect-host":
            self.connectHostFinished.emit(host, ok, message)
        elif kind == "open-session":
            self.deviceSessionFinished.emit(host, ok, message)
        elif kind == "device-command":
            command = str(metadata.get("command") or "")
            output = str(result.get("output") or "") if isinstance(result, dict) else ""
            self.deviceCommandFinished.emit(host, command, ok, message, output)
        elif kind == "running-config":
            self.runningConfigFinished.emit(host, ok, message)

        self.taskFinished.emit(ok, message)

    @pyqtSlot()
    def openTerminal(self) -> None:
        open_terminal(APP_DIR)

    @pyqtSlot(str, result="QVariant")
    def pingHost(self, ip: str) -> dict[str, Any]:
        ip = (ip or "").strip()
        if not ip:
            return {"ok": False, "severity": "warning", "message": "Ping failed: host is empty."}
        result = ping_host(APP_DIR, ip)
        return result

    @pyqtSlot(result="QVariant")
    def ensurePythonLoginDeps(self) -> dict[str, Any]:
        return {"ok": True, "message": "PyQt6 frontend runtime is ready."}

    @pyqtSlot(str, result="QVariant")
    def openDeviceSession(self, host: str) -> dict[str, Any]:
        return device_session_registry.open(host)

    @pyqtSlot(str, result=bool)
    def openDeviceSessionAsync(self, host: str) -> bool:
        host = (host or "").strip()
        if not host:
            message = "Open session failed: host is empty."
            self.deviceSessionFinished.emit("", False, message)
            self.taskFinished.emit(False, message)
            return False

        task_key = f"open-session:{host}"
        start_message = f"Opening CLI session to {host}..."

        def run_open_session(progress: Any) -> dict[str, Any]:
            progress(f"Connecting to {host} with SSH/Telnet...")
            return device_session_registry.open(host)

        return self._start_background_task(task_key, "open-session", host, start_message, run_open_session)

    @pyqtSlot(str, result="QVariant")
    def closeDeviceSession(self, host: str) -> dict[str, Any]:
        return device_session_registry.close(host)

    @pyqtSlot(str, result=bool)
    def hasDeviceSession(self, host: str) -> bool:
        return device_session_registry.has_session(host)

    @pyqtSlot(str, str, result="QVariant")
    def runDeviceCommand(self, host: str, command: str) -> dict[str, Any]:
        host = (host or "").strip()
        command = (command or "").strip()
        if not host:
            return {"ok": False, "severity": "warning", "message": "Command failed: host is empty.", "output": ""}
        if not command:
            return {"ok": False, "severity": "warning", "message": "Command failed: command is empty.", "output": ""}

        connector = device_session_registry.get_connector(host)
        if connector is None:
            return {
                "ok": False,
                "severity": "error",
                "message": f"Command failed for {host}: no active tab session.",
                "output": "",
            }

        try:
            output = connector.send_command(command)
            if output is None:
                return {"ok": False, "severity": "error", "message": f"Command failed for {host}: no output returned.", "output": ""}
            return {"ok": True, "severity": "success", "message": f"Command completed for {host}.", "output": str(output)}
        except Exception as exc:
            print(f"[app] Command failed for {host}: {exc}", file=sys.stderr)
            return {"ok": False, "severity": "error", "message": f"Command failed for {host}: {exc}", "output": ""}

    @pyqtSlot(str, str, result=bool)
    def runDeviceCommandAsync(self, host: str, command: str) -> bool:
        host = (host or "").strip()
        command = (command or "").strip()
        if not host or not command:
            message = "Command failed: host or command is empty."
            self.deviceCommandFinished.emit(host, command, False, message, "")
            self.taskFinished.emit(False, message)
            return False

        task_key = f"device-command:{host}:{command}"
        start_message = f"Running command on {host}: {command}"

        def run_command(progress: Any) -> dict[str, Any]:
            progress(f"Waiting for device response from {host}...")
            return self.runDeviceCommand(host, command)

        return self._start_background_task(
            task_key,
            "device-command",
            host,
            start_message,
            run_command,
            {"command": command},
        )

    @pyqtSlot()
    def closeAllDeviceSessions(self) -> None:
        device_session_registry.close_all()

    @pyqtSlot(str, result="QVariant")
    def saveRunningConfigBackup(self, host: str) -> dict[str, Any]:
        host = (host or "").strip()
        if not host:
            return {"ok": False, "severity": "warning", "message": "Get running-config failed: host is empty."}

        device = load_device_for_login(host)
        if device is None:
            return {"ok": False, "severity": "error", "message": f"Get running-config failed for {host}: device was not found in database."}
        if is_dev_device(device):
            return {"ok": False, "severity": "warning", "message": f"{host} is a dev-test host; no running-config can be collected."}

        backup_dir = APP_DIR / "backup" / host
        backup_dir.mkdir(parents=True, exist_ok=True)

        connector = device_session_registry.get_connector(host)
        owns_connector = False
        if connector is None:
            method = str(device.get("method") or "").strip().lower()
            if method not in {"ssh", "telnet"}:
                return {
                    "ok": False,
                    "severity": "warning",
                    "message": f"Get running-config failed for {host}: {method.upper() or 'non-CLI'} is not supported.",
                }

            try:
                from login.device_connector import DeviceConnector

                connector = DeviceConnector(
                    device["host"],
                    method,
                    device["port"],
                    device["username"],
                    device["password"],
                    device_type=device["device_type"],
                    start_config_mode=False,
                    timeout=NETWORK_TASK_TIMEOUT_SECONDS,
                )
                owns_connector = True
                if not connector.connect():
                    reason = str(getattr(connector, "last_error", "") or "login failed")
                    return {"ok": False, "severity": "error", "message": f"Get running-config failed for {host}: {reason}."}
            except Exception as exc:
                print(f"[app] Get running-config failed for {host}: {exc}", file=sys.stderr)
                return {"ok": False, "severity": "error", "message": f"Get running-config failed for {host}: {exc}"}

        try:
            ok = bool(connector.save_running_config(str(backup_dir)))
            sync_error = str(getattr(connector, "last_sync_error", "") or "").strip()
            sync_summary = getattr(connector, "last_sync_summary", {}) or {}
            sync_text = (
                f" Synced {sync_summary.get('interfaces', 0)} interface(s)"
                f" and {sync_summary.get('ospf_processes', 0)} OSPF process(es)."
                if sync_summary
                else ""
            )
            if ok and sync_error:
                return {
                    "ok": True,
                    "severity": "warning",
                    "message": f"Running-config saved in backup/{host}, but DB sync failed: {sync_error}.",
                }
            if ok:
                return {"ok": True, "severity": "success", "message": f"Running-config saved in backup/{host}.{sync_text}"}
            return {"ok": False, "severity": "error", "message": f"Get running-config failed for {host}: command returned no output."}
        finally:
            if owns_connector and connector is not None:
                connector.disconnect()

    @pyqtSlot(str, result=bool)
    def saveRunningConfigBackupAsync(self, host: str) -> bool:
        host = (host or "").strip()
        if not host:
            message = "Get running-config failed: host is empty."
            self.runningConfigFinished.emit("", False, message)
            self.taskFinished.emit(False, message)
            return False

        task_key = f"running-config:{host}"
        start_message = f"Getting running-config from {host}..."

        def run_running_config(progress: Any) -> dict[str, Any]:
            progress(f"Running output rcfg for {host}...")
            result = self.saveRunningConfigBackup(host)
            progress(f"Finished running-config task for {host}.")
            return result

        return self._start_background_task(task_key, "running-config", host, start_message, run_running_config)

    @pyqtSlot(str, result="QVariant")
    def connectHostAndSync(self, host: str) -> dict[str, Any]:
        host = (host or "").strip()
        if not host:
            print("[app] connectHostAndSync failed: host is empty.", file=sys.stderr)
            return {"ok": False, "severity": "warning", "message": "Connect failed: host is empty."}

        connector = None
        try:
            device = load_device_for_login(host)
            if device is None:
                print(f"[app] connectHostAndSync failed: device {host} was not found in database.", file=sys.stderr)
                return {"ok": False, "severity": "error", "message": f"Connect failed for {host}: device was not found in database."}
            if is_dev_device(device):
                update_device_flag(host, "success", 1)
                return {
                    "ok": True,
                    "severity": "info",
                    "message": f"{host} is a dev-test host; marked connected without SSH/Telnet login or device sync.",
                }

            from login.device_connector import DeviceConnector

            connector = DeviceConnector(
                device["host"],
                device["method"],
                device["port"],
                device["username"],
                device["password"],
                device_type=device["device_type"],
                start_config_mode=True,
                timeout=NETWORK_TASK_TIMEOUT_SECONDS,
            )

            if not connector.connect():
                update_device_flag(host, "success", -1)
                reason = str(getattr(connector, "last_error", "") or "login failed")
                print(f"[app] connectHostAndSync failed for {host}: {reason}.", file=sys.stderr)
                return {"ok": False, "severity": "error", "message": f"Connect failed for {host}: {reason}."}

            status_updated = update_device_flag(host, "success", 1)
            backup_dir = APP_DIR / "backup" / host
            backup_dir.mkdir(parents=True, exist_ok=True)
            backup_ok = connector.save_running_config(str(backup_dir))
            sync_summary = getattr(connector, "last_sync_summary", {}) or {}
            sync_error = str(getattr(connector, "last_sync_error", "") or "").strip()
            sync_text = (
                f" Synced {sync_summary.get('interfaces', 0)} interface(s)"
                f" and {sync_summary.get('ospf_processes', 0)} OSPF process(es)."
                if sync_summary
                else ""
            )

            if backup_ok and status_updated:
                if sync_error:
                    return {
                        "ok": True,
                        "severity": "warning",
                        "message": f"Connected {host}; running-config saved in backup/{host}, but DB sync failed: {sync_error}.",
                    }
                return {"ok": True, "severity": "success", "message": f"Connected {host}; running-config saved in backup/{host}.{sync_text}"}
            if backup_ok:
                return {"ok": True, "severity": "warning", "message": f"Connected {host}; running-config saved, but database status was not updated.{sync_text}"}
            print(f"[app] connectHostAndSync warning: running-config backup failed for {host}.", file=sys.stderr)
            if not status_updated:
                return {"ok": True, "severity": "warning", "message": f"Connected {host}; running-config backup failed and database status was not updated."}
            return {"ok": True, "severity": "warning", "message": f"Connected {host}; running-config backup failed."}
        except Exception as exc:
            try:
                update_device_flag(host, "success", -1)
            except Exception:
                pass
            print(f"[app] connectHostAndSync failed for {host}: {exc}", file=sys.stderr)
            return {"ok": False, "severity": "error", "message": f"Connect failed for {host}: {exc}"}
        finally:
            if connector is not None:
                connector.disconnect()

    @pyqtSlot(str, result=bool)
    def connectHostAndSyncAsync(self, host: str) -> bool:
        host = (host or "").strip()
        if not host:
            message = "Connect failed: host is empty."
            self.connectHostFinished.emit("", False, message)
            self.taskFinished.emit(False, message)
            return False

        task_key = f"connect:{host}"
        start_message = f"Connecting to {host}..."

        def run_connect(progress: Any) -> dict[str, Any]:
            progress(f"Opening device connection to {host}...")
            result = self.connectHostAndSync(host)
            progress(f"Finished connection task for {host}.")
            return result

        return self._start_background_task(task_key, "connect-host", host, start_message, run_connect)


class ExternalToolsManager(QObject):
    toolsChanged = pyqtSignal()
    browserChanged = pyqtSignal()

    TOOL_TYPES = ("SSH Client", "Terminal", "DB Browser")

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self.db_path = EXTERNAL_TOOLS_DB_PATH
        self.device_db_path = DB_PATH
        self._active_table = ""
        self._ensure_database()

    def _connect(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        return conn

    def _ensure_database(self) -> None:
        with closing(self._connect()) as conn:
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS apps (
                    id          INTEGER PRIMARY KEY AUTOINCREMENT,
                    app         TEXT NOT NULL UNIQUE,
                    type        TEXT NOT NULL,
                    executable  TEXT NOT NULL,
                    arguments   TEXT DEFAULT '',
                    enabled     INTEGER DEFAULT 1,
                    description TEXT DEFAULT ''
                );
                """
            )
            conn.commit()

    def _dict_rows(self, rows: list[sqlite3.Row]) -> list[dict[str, Any]]:
        return [dict(row) for row in rows]

    def _file_url_to_path(self, value: str) -> Path:
        text = (value or "").strip()
        parsed = QUrl(text)
        if parsed.isLocalFile():
            return Path(parsed.toLocalFile())
        return Path(text)

    def _split_arguments(self, value: str) -> list[str]:
        arguments = shlex.split(value or "", posix=os.name != "nt")
        if os.name != "nt":
            return arguments
        return [
            argument[1:-1]
            if len(argument) >= 2 and argument[0] == argument[-1] and argument[0] in {'"', "'"}
            else argument
            for argument in arguments
        ]

    def _enabled_db_browser(self) -> sqlite3.Row | None:
        with closing(self._connect()) as conn:
            return conn.execute(
                """
                SELECT *
                FROM apps
                WHERE enabled = 1 AND type = 'DB Browser'
                ORDER BY app COLLATE NOCASE
                LIMIT 1;
                """
            ).fetchone()

    def _quote_identifier(self, name: str) -> str:
        return '"' + name.replace('"', '""') + '"'

    @pyqtSlot(result="QVariant")
    def getToolTypes(self) -> list[str]:
        return list(self.TOOL_TYPES)

    @pyqtSlot(result="QVariant")
    def getTools(self) -> list[dict[str, Any]]:
        self._ensure_database()
        with closing(self._connect()) as conn:
            rows = conn.execute(
                """
                SELECT id, app, type, executable, arguments, enabled, description
                FROM apps
                ORDER BY type COLLATE NOCASE, app COLLATE NOCASE;
                """
            ).fetchall()
        return self._dict_rows(rows)

    @pyqtSlot(str, str, str, str, bool, str, result="QVariant")
    def saveTool(self, app: str, app_type: str, executable: str, arguments: str, enabled: bool, description: str) -> dict[str, Any]:
        app = (app or "").strip()
        app_type = (app_type or "").strip()
        executable = (executable or "").strip()
        if not app:
            return {"ok": False, "message": "App name is required."}
        if app_type not in self.TOOL_TYPES:
            return {"ok": False, "message": "Tool type is invalid."}
        if not executable:
            return {"ok": False, "message": "Executable path is required."}

        try:
            with closing(self._connect()) as conn:
                conn.execute(
                    """
                    INSERT INTO apps (app, type, executable, arguments, enabled, description)
                    VALUES (?, ?, ?, ?, ?, ?)
                    ON CONFLICT(app) DO UPDATE SET
                        type = excluded.type,
                        executable = excluded.executable,
                        arguments = excluded.arguments,
                        enabled = excluded.enabled,
                        description = excluded.description;
                    """,
                    (app, app_type, executable, arguments or "", 1 if enabled else 0, description or ""),
                )
                conn.commit()
            self.toolsChanged.emit()
            return {"ok": True, "message": "External tool saved."}
        except sqlite3.Error as exc:
            return {"ok": False, "message": str(exc)}

    @pyqtSlot(str, result=bool)
    def deleteTool(self, app: str) -> bool:
        try:
            with closing(self._connect()) as conn:
                conn.execute("DELETE FROM apps WHERE app = ?;", ((app or "").strip(),))
                conn.commit()
            self.toolsChanged.emit()
            return True
        except sqlite3.Error:
            return False

    @pyqtSlot(result="QVariant")
    def openDeviceDatabase(self) -> dict[str, Any]:
        self._ensure_database()
        browser = self._enabled_db_browser()
        if browser is None:
            result = self.loadDefaultDatabase()
            return {**result, "mode": "default"}

        executable = self._file_url_to_path(str(browser["executable"]))
        if not executable.is_file():
            self.loadDefaultDatabase()
            return {"ok": False, "mode": "default", "message": f"DB Browser path not found: {executable}"}

        args_text = str(browser["arguments"] or "")
        db_text = str(self.device_db_path.resolve())
        try:
            arguments = self._split_arguments(args_text)
            has_database_placeholder = any("{db}" in argument for argument in arguments)
            arguments = [argument.replace("{db}", db_text) for argument in arguments]
            if not has_database_placeholder:
                arguments.append(db_text)
            command = [str(executable), *arguments]
            kwargs: dict[str, Any] = {"cwd": str(APP_DIR)}
            if os.name == "nt":
                kwargs["creationflags"] = getattr(subprocess, "CREATE_NO_WINDOW", 0)
            subprocess.Popen(command, **kwargs)
            return {"ok": True, "mode": "external", "message": f"Opened with {browser['app']}."}
        except Exception as exc:
            self.loadDefaultDatabase()
            return {"ok": False, "mode": "default", "message": f"External DB Browser failed: {exc}"}

    @pyqtSlot(result="QVariant")
    def loadDefaultDatabase(self) -> dict[str, Any]:
        if not self.device_db_path.exists():
            return {"ok": False, "message": f"Database not found: {self.device_db_path}"}
        tables = self.getDatabaseTables()
        if tables and not self._active_table:
            self._active_table = tables[0]
        self.browserChanged.emit()
        return {"ok": True, "message": "Opened with the built-in DB browser.", "tables": tables}

    @pyqtSlot(result="QVariant")
    def getDatabaseTables(self) -> list[str]:
        if not self.device_db_path.exists():
            return []
        try:
            with closing(sqlite3.connect(self.device_db_path)) as conn:
                rows = conn.execute(
                    """
                    SELECT name
                    FROM sqlite_master
                    WHERE type = 'table' AND name NOT LIKE 'sqlite_%'
                    ORDER BY name COLLATE NOCASE;
                    """
                ).fetchall()
        except sqlite3.Error:
            return []
        return [str(row[0]) for row in rows]

    @pyqtSlot(str, result="QVariant")
    def getTableRows(self, table_name: str) -> dict[str, Any]:
        table_name = (table_name or "").strip()
        if table_name not in self.getDatabaseTables():
            return {"ok": False, "message": "Invalid table.", "columns": [], "rows": [], "editable": False}
        table_sql = self._quote_identifier(table_name)
        try:
            with closing(sqlite3.connect(self.device_db_path)) as conn:
                conn.row_factory = sqlite3.Row
                columns = [row[1] for row in conn.execute(f"PRAGMA table_info({table_sql});")]
                try:
                    rows = conn.execute(f"SELECT rowid AS __rowid__, * FROM {table_sql} LIMIT 500;").fetchall()
                    editable = True
                except sqlite3.Error:
                    rows = conn.execute(f"SELECT * FROM {table_sql} LIMIT 500;").fetchall()
                    editable = False
        except sqlite3.Error as exc:
            return {"ok": False, "message": str(exc), "columns": [], "rows": [], "editable": False}
        self._active_table = table_name
        self.browserChanged.emit()
        return {
            "ok": True,
            "message": f"Loaded {table_name}",
            "columns": columns,
            "rows": self._dict_rows(rows),
            "editable": editable,
        }

    @pyqtSlot(str, int, str, str, result="QVariant")
    def updateTableCell(self, table_name: str, rowid: int, column_name: str, value: str) -> dict[str, Any]:
        table_name = (table_name or "").strip()
        column_name = (column_name or "").strip()
        if table_name not in self.getDatabaseTables():
            return {"ok": False, "message": "Invalid table."}

        table_sql = self._quote_identifier(table_name)
        try:
            with closing(sqlite3.connect(self.device_db_path)) as conn:
                columns = [row[1] for row in conn.execute(f"PRAGMA table_info({table_sql});")]
                if column_name not in columns:
                    return {"ok": False, "message": "Invalid column."}
                conn.execute(
                    f"UPDATE {table_sql} SET {self._quote_identifier(column_name)} = ? WHERE rowid = ?;",
                    (value, rowid),
                )
                conn.commit()
        except sqlite3.Error as exc:
            return {"ok": False, "message": str(exc)}

        self.browserChanged.emit()
        return {"ok": True, "message": f"Updated {table_name}.{column_name}."}


class ThemeSettings(QObject):
    settingsChanged = pyqtSignal()

    DEFAULTS: dict[str, Any] = {
        "themeMode": 0,
        "accentColorIndex": 4,
        "lightDarkSideBar": False,
        "useCustomAccentColor": False,
        "customAccentColor": "#356FD6",
    }

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._settings = QSettings()
        self._values: dict[str, Any] = {
            key: self._read_value(key, default)
            for key, default in self.DEFAULTS.items()
        }

    def _read_value(self, key: str, default: Any) -> Any:
        value_type = type(default)
        try:
            value = self._settings.value(f"Theme/{key}", default, type=value_type)
        except TypeError:
            value = self._settings.value(f"Theme/{key}", default)
        return self._normalize_value(key, value)

    def _normalize_value(self, key: str, value: Any) -> Any:
        if key == "themeMode":
            try:
                value = int(value)
            except (TypeError, ValueError):
                return self.DEFAULTS[key]
            return value if value in {0, 1, 2, 3, 4} else self.DEFAULTS[key]
        if key == "accentColorIndex":
            try:
                value = int(value)
            except (TypeError, ValueError):
                return self.DEFAULTS[key]
            return value if 0 <= value <= 11 else self.DEFAULTS[key]
        if key == "lightDarkSideBar":
            if isinstance(value, str):
                return value.strip().casefold() in {"1", "true", "yes", "on"}
            return bool(value)
        if key == "useCustomAccentColor":
            if isinstance(value, str):
                return value.strip().casefold() in {"1", "true", "yes", "on"}
            return bool(value)
        if key == "customAccentColor":
            value = str(value or "").strip()
            return value if value else self.DEFAULTS[key]
        return value

    def _set_value(self, key: str, value: Any) -> None:
        value = self._normalize_value(key, value)
        if self._values.get(key) == value:
            return

        self._values[key] = value
        self._settings.setValue(f"Theme/{key}", value)
        self._settings.sync()
        self.settingsChanged.emit()

    @pyqtProperty(int, notify=settingsChanged)
    def themeMode(self) -> int:
        return int(self._values["themeMode"])

    @themeMode.setter
    def themeMode(self, value: int) -> None:
        self._set_value("themeMode", value)

    @pyqtProperty(int, notify=settingsChanged)
    def accentColorIndex(self) -> int:
        return int(self._values["accentColorIndex"])

    @accentColorIndex.setter
    def accentColorIndex(self, value: int) -> None:
        self._set_value("accentColorIndex", value)

    @pyqtProperty(bool, notify=settingsChanged)
    def lightDarkSideBar(self) -> bool:
        return bool(self._values["lightDarkSideBar"])

    @lightDarkSideBar.setter
    def lightDarkSideBar(self, value: bool) -> None:
        self._set_value("lightDarkSideBar", value)

    @pyqtProperty(bool, notify=settingsChanged)
    def useCustomAccentColor(self) -> bool:
        return bool(self._values["useCustomAccentColor"])

    @useCustomAccentColor.setter
    def useCustomAccentColor(self, value: bool) -> None:
        self._set_value("useCustomAccentColor", value)

    @pyqtProperty(str, notify=settingsChanged)
    def customAccentColor(self) -> str:
        return str(self._values["customAccentColor"])

    @customAccentColor.setter
    def customAccentColor(self, value: str) -> None:
        self._set_value("customAccentColor", value)


class StatusBarSettings(QObject):
    settingsChanged = pyqtSignal()

    DEFAULTS: dict[str, Any] = {
        "showStatusBar": True,
        "showPythonStatus": True,
        "showNetwork": True,
        "showNetworkName": True,
        "showRam": True,
        "showRamBar": True,
        "showRamText": True,
        "ramWarningEnabled": True,
        "ramBlinkOnHigh": True,
        "ramWarningThreshold": 85,
        "showDate": True,
        "showTime": True,
        "showNotifications": True,
        "dateTimeFormatMode": 0,
        "customDateFormat": "dd/MM/yyyy",
        "customTimeFormat": "HH:mm",
    }

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._settings = QSettings()
        self._values: dict[str, Any] = {
            key: self._read_value(key, default)
            for key, default in self.DEFAULTS.items()
        }

    def _read_value(self, key: str, default: Any) -> Any:
        value_type = type(default)
        try:
            return self._settings.value(f"StatusBar/{key}", default, type=value_type)
        except TypeError:
            return self._settings.value(f"StatusBar/{key}", default)

    def _set_value(self, key: str, value: Any) -> None:
        default = self.DEFAULTS[key]
        if isinstance(default, bool):
            value = bool(value)
        elif isinstance(default, int):
            value = int(value)
        else:
            value = str(value)

        if key == "ramWarningThreshold":
            value = max(1, min(100, value))
        elif key == "dateTimeFormatMode":
            value = 1 if value == 1 else 0

        if self._values.get(key) == value:
            return

        self._values[key] = value
        self._settings.setValue(f"StatusBar/{key}", value)
        self._settings.sync()
        self.settingsChanged.emit()

    @pyqtSlot()
    def resetDefaults(self) -> None:
        changed = False
        for key, default in self.DEFAULTS.items():
            if self._values.get(key) != default:
                self._values[key] = default
                self._settings.setValue(f"StatusBar/{key}", default)
                changed = True
        if changed:
            self._settings.sync()
            self.settingsChanged.emit()

    @pyqtProperty(bool, notify=settingsChanged)
    def showStatusBar(self) -> bool:
        return bool(self._values["showStatusBar"])

    @showStatusBar.setter
    def showStatusBar(self, value: bool) -> None:
        self._set_value("showStatusBar", value)

    @pyqtProperty(bool, notify=settingsChanged)
    def showPythonStatus(self) -> bool:
        return bool(self._values["showPythonStatus"])

    @showPythonStatus.setter
    def showPythonStatus(self, value: bool) -> None:
        self._set_value("showPythonStatus", value)

    @pyqtProperty(bool, notify=settingsChanged)
    def showNetwork(self) -> bool:
        return bool(self._values["showNetwork"])

    @showNetwork.setter
    def showNetwork(self, value: bool) -> None:
        self._set_value("showNetwork", value)

    @pyqtProperty(bool, notify=settingsChanged)
    def showNetworkName(self) -> bool:
        return bool(self._values["showNetworkName"])

    @showNetworkName.setter
    def showNetworkName(self, value: bool) -> None:
        self._set_value("showNetworkName", value)

    @pyqtProperty(bool, notify=settingsChanged)
    def showRam(self) -> bool:
        return bool(self._values["showRam"])

    @showRam.setter
    def showRam(self, value: bool) -> None:
        self._set_value("showRam", value)

    @pyqtProperty(bool, notify=settingsChanged)
    def showRamBar(self) -> bool:
        return bool(self._values["showRamBar"])

    @showRamBar.setter
    def showRamBar(self, value: bool) -> None:
        self._set_value("showRamBar", value)

    @pyqtProperty(bool, notify=settingsChanged)
    def showRamText(self) -> bool:
        return bool(self._values["showRamText"])

    @showRamText.setter
    def showRamText(self, value: bool) -> None:
        self._set_value("showRamText", value)

    @pyqtProperty(bool, notify=settingsChanged)
    def ramWarningEnabled(self) -> bool:
        return bool(self._values["ramWarningEnabled"])

    @ramWarningEnabled.setter
    def ramWarningEnabled(self, value: bool) -> None:
        self._set_value("ramWarningEnabled", value)

    @pyqtProperty(bool, notify=settingsChanged)
    def ramBlinkOnHigh(self) -> bool:
        return bool(self._values["ramBlinkOnHigh"])

    @ramBlinkOnHigh.setter
    def ramBlinkOnHigh(self, value: bool) -> None:
        self._set_value("ramBlinkOnHigh", value)

    @pyqtProperty(int, notify=settingsChanged)
    def ramWarningThreshold(self) -> int:
        return int(self._values["ramWarningThreshold"])

    @ramWarningThreshold.setter
    def ramWarningThreshold(self, value: int) -> None:
        self._set_value("ramWarningThreshold", value)

    @pyqtProperty(bool, notify=settingsChanged)
    def showDate(self) -> bool:
        return bool(self._values["showDate"])

    @showDate.setter
    def showDate(self, value: bool) -> None:
        self._set_value("showDate", value)

    @pyqtProperty(bool, notify=settingsChanged)
    def showTime(self) -> bool:
        return bool(self._values["showTime"])

    @showTime.setter
    def showTime(self, value: bool) -> None:
        self._set_value("showTime", value)

    @pyqtProperty(bool, notify=settingsChanged)
    def showNotifications(self) -> bool:
        return bool(self._values["showNotifications"])

    @showNotifications.setter
    def showNotifications(self, value: bool) -> None:
        self._set_value("showNotifications", value)

    @pyqtProperty(int, notify=settingsChanged)
    def dateTimeFormatMode(self) -> int:
        return int(self._values["dateTimeFormatMode"])

    @dateTimeFormatMode.setter
    def dateTimeFormatMode(self, value: int) -> None:
        self._set_value("dateTimeFormatMode", value)

    @pyqtProperty(str, notify=settingsChanged)
    def customDateFormat(self) -> str:
        return str(self._values["customDateFormat"])

    @customDateFormat.setter
    def customDateFormat(self, value: str) -> None:
        self._set_value("customDateFormat", value)

    @pyqtProperty(str, notify=settingsChanged)
    def customTimeFormat(self) -> str:
        return str(self._values["customTimeFormat"])

    @customTimeFormat.setter
    def customTimeFormat(self, value: str) -> None:
        self._set_value("customTimeFormat", value)


class NetworkMonitor(QObject):
    networkChanged = pyqtSignal()
    systemInfoChanged = pyqtSignal()

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._connected = False
        self._connection_type = "none"
        self._network_name = ""
        self._ram_usage_percent = 0
        self._timer = QTimer(self)
        self._timer.timeout.connect(self._refresh)
        self._timer.start(3000)
        self._refresh()

    def _refresh(self) -> None:
        ram_usage_percent = read_ram_usage_percent()
        if ram_usage_percent != self._ram_usage_percent:
            self._ram_usage_percent = ram_usage_percent
            self.systemInfoChanged.emit()

        connected, connection_type, network_name = read_network_info()
        if (
            connected != self._connected
            or connection_type != self._connection_type
            or network_name != self._network_name
        ):
            self._connected = connected
            self._connection_type = connection_type
            self._network_name = network_name
            self.networkChanged.emit()

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
