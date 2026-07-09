from __future__ import annotations

import os
import sqlite3
import socket
import subprocess
import sys
import locale
import threading
from ipaddress import ip_address
from pathlib import Path
from typing import Any

from PyQt6.QtCore import QObject, QSettings, QTimer, QUrl, pyqtProperty, pyqtSignal, pyqtSlot


APP_DIR = Path(__file__).resolve().parent.parent
QML_MODULE_DIR = APP_DIR / "UI"
DB_PATH = APP_DIR / "device_network.db"
SQL_PATH = QML_MODULE_DIR / "main_numbered_tables.sql"
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
    }


def update_device_flag(host: str, column: str, value: int) -> bool:
    if column not in {"admin", "success"}:
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
    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)

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

    @pyqtSlot()
    def closeAllDeviceSessions(self) -> None:
        device_session_registry.close_all()

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
