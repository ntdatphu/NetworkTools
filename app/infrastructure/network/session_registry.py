"""Thread-safe owner for reusable device sessions."""

from __future__ import annotations

import threading
from typing import Any, Callable

from .connector import ConnectorFactory, create_connector


class DeviceSessionRegistry:
    def __init__(
        self,
        device_loader: Callable[[str], dict[str, Any] | None],
        *,
        connector_factory: ConnectorFactory = create_connector,
    ) -> None:
        self._device_loader = device_loader
        self._connector_factory = connector_factory
        self._lock = threading.RLock()
        self._sessions: dict[str, Any] = {}

    @staticmethod
    def _is_alive(connector: Any) -> bool:
        if connector is None or not bool(getattr(connector, "connected", False)):
            return False
        connection = getattr(connector, "connection", None)
        if connection is None:
            return False
        probe = getattr(connection, "is_alive", None)
        try:
            return bool(probe()) if callable(probe) else True
        except Exception:
            return False

    @staticmethod
    def _disconnect(connector: Any) -> None:
        try:
            connector.disconnect()
        except Exception:
            pass

    @staticmethod
    def _prepare(connector: Any) -> None:
        connection = getattr(connector, "connection", None)
        if connection is None:
            raise RuntimeError("Network connection was not created")
        if callable(getattr(connection, "check_enable_mode", None)) and not connection.check_enable_mode():
            connection.enable()
        if callable(getattr(connection, "check_config_mode", None)) and connection.check_config_mode():
            connection.exit_config_mode()

    def open(self, host: str) -> dict[str, Any]:
        host = (host or "").strip()
        if not host:
            return {"ok": False, "severity": "warning", "message": "Open session failed: host is empty."}
        with self._lock:
            current = self._sessions.get(host)
            if self._is_alive(current):
                return {"ok": True, "severity": "info", "message": f"Session for {host} is already open."}
        device = self._device_loader(host)
        if device is None:
            return {"ok": False, "severity": "error", "message": f"Device {host} was not found."}
        if int(device.get("dev") or 0) == 1 or device.get("method") not in {"ssh", "telnet"}:
            return {"ok": True, "severity": "info", "message": f"No persistent CLI session required for {host}."}
        connector = None
        try:
            connector = self._connector_factory(device)
            if not connector.connect():
                reason = getattr(connector, "last_error", "login failed")
                return {"ok": False, "severity": "error", "message": f"Open session failed for {host}: {reason}."}
            self._prepare(connector)
            with self._lock:
                previous = self._sessions.pop(host, None)
                if previous is not None:
                    self._disconnect(previous)
                self._sessions[host] = connector
            return {"ok": True, "severity": "success", "message": f"Session opened for {host}."}
        except Exception as exc:
            if connector is not None:
                self._disconnect(connector)
            return {"ok": False, "severity": "error", "message": f"Open session failed for {host}: {exc}"}

    def close(self, host: str) -> dict[str, Any]:
        host = (host or "").strip()
        with self._lock:
            connector = self._sessions.pop(host, None)
        if connector is not None:
            self._disconnect(connector)
        return {"ok": True, "severity": "success" if connector else "info", "message": f"Session closed for {host}."}

    def close_all(self) -> None:
        with self._lock:
            sessions = list(self._sessions.values())
            self._sessions.clear()
        for connector in sessions:
            self._disconnect(connector)

    def get_connector(self, host: str) -> Any | None:
        with self._lock:
            connector = self._sessions.get((host or "").strip())
            if self._is_alive(connector):
                return connector
        return None

    def has_session(self, host: str) -> bool:
        return self.get_connector(host) is not None
