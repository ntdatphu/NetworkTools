"""Qt facade that wires the isolated Syslog services to QML."""

from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
from typing import Any

from PyQt6.QtCore import QObject, pyqtProperty, pyqtSignal, pyqtSlot

from infrastructure.database.paths import DEVICE_NETWORK_DB, INFO_COLLECTED_DB

from .configurator import SyslogConfigurator
from .receiver import SyslogReceiver
from .repository import SyslogRepository
from .retention import run_retention
from .settings import SyslogSettings
from .writer import SyslogWriter


def _variant_dict(value: Any) -> dict[str, Any]:
    """Normalize a QML JavaScript object or a regular Python mapping."""
    if value is None:
        return {}
    to_variant = getattr(value, "toVariant", None)
    if callable(to_variant):
        value = to_variant()
    if value is None:
        return {}
    if isinstance(value, dict):
        return dict(value)
    try:
        return dict(value)
    except (TypeError, ValueError) as exc:
        raise TypeError("Syslog filters must be a QML object or mapping") from exc


class SyslogManager(QObject):
    stateChanged = pyqtSignal()
    messagesInserted = pyqtSignal("QVariant")
    connectedDevicesChanged = pyqtSignal("QVariant")
    queryFinished = pyqtSignal(str, "QVariant", bool)
    deviceConfigStarted = pyqtSignal(str, str)
    deviceConfigFinished = pyqtSignal(str, str, bool, str)
    sourceInterfaceRequired = pyqtSignal(str, str)
    errorOccurred = pyqtSignal(str)

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self.settings = SyslogSettings(self)
        self.repository = SyslogRepository(INFO_COLLECTED_DB, DEVICE_NETWORK_DB)
        self.configurator = SyslogConfigurator(self.repository)
        self.writer = SyslogWriter(self.repository, self._messages_stored, self._error)
        self.receiver: SyslogReceiver | None = None
        self.executor = ThreadPoolExecutor(max_workers=3, thread_name_prefix="syslog-task")
        self._state = "stopped"
        self._status_message = "Syslog server is stopped."
        self._received_count = 0

    @pyqtProperty(str, notify=stateChanged)
    def listenerState(self) -> str:
        return self._state

    @pyqtProperty(str, notify=stateChanged)
    def statusMessage(self) -> str:
        return self._status_message

    @pyqtProperty(int, notify=stateChanged)
    def receivedCount(self) -> int:
        return self._received_count

    @pyqtProperty(int, notify=stateChanged)
    def droppedCount(self) -> int:
        return self.writer.dropped

    def _set_state(self, state: str, message: str) -> None:
        self._state = state
        self._status_message = message
        self.stateChanged.emit()

    @pyqtSlot(result="QVariant")
    def startServer(self) -> dict[str, object]:
        if self._state in {"starting", "listening"}:
            return {"ok": True, "message": self._status_message}
        try:
            config = self.settings.listener_config()
            self._set_state("starting", "Starting Syslog server...")
            self.writer.start()
            self.receiver = SyslogReceiver(config, self._receive, self._receiver_error)
            self.receiver.start()
            self.executor.submit(run_retention, self.repository, self.settings.retentionDays)
            self._set_state("listening", f"Listening on {config.bind_ip}:{config.port}/{config.protocol.upper()}")
            return {"ok": True, "message": self._status_message}
        except Exception as exc:
            if self.receiver:
                self.receiver.stop()
                self.receiver = None
            self.writer.stop()
            self._set_state("error", str(exc))
            return {"ok": False, "message": str(exc)}

    @pyqtSlot(result="QVariant")
    def stopServer(self) -> dict[str, object]:
        if self._state == "stopped":
            return {"ok": True, "message": self._status_message}
        self._set_state("stopping", "Stopping Syslog server...")
        if self.receiver:
            self.receiver.stop()
            self.receiver = None
        self.writer.stop()
        self._set_state("stopped", "Syslog server is stopped.")
        return {"ok": True, "message": self._status_message}

    def _receive(self, data: bytes, source_ip: str, protocol: str) -> None:
        self.writer.submit(data, source_ip, protocol)

    def _messages_stored(self, rows: list[dict[str, Any]]) -> None:
        self._received_count += len(rows)
        self.messagesInserted.emit(rows)
        self.stateChanged.emit()

    def _receiver_error(self, message: str) -> None:
        self._set_state("error", message)
        self.errorOccurred.emit(message)

    def _error(self, message: str) -> None:
        self.errorOccurred.emit(message)
        self.stateChanged.emit()

    @pyqtSlot()
    def loadConnectedDevices(self) -> None:
        def task() -> None:
            try:
                # Device listing still works before listener settings are complete.
                devices = self.repository.connected_devices()
                validation = self.settings.validate()
                configured_hosts: set[str] = set()
                if validation["ok"]:
                    config = self.settings.listener_config()
                    configured_hosts = self.repository.configured_hosts(
                        config.advertised_ip, config.protocol, config.port
                    )
                for row in devices:
                    row["configured"] = row["host"] in configured_hosts
                self.connectedDevicesChanged.emit(devices)
            except Exception as exc:
                self._error(str(exc))

        self.executor.submit(task)

    @pyqtSlot(str)
    def configureDevice(self, host: str) -> None:
        self._device_action(host, "configure")

    @pyqtSlot(str, str)
    def configureDeviceWithInterface(self, host: str, source_interface: str) -> None:
        self._device_action(host, "configure", source_interface)

    @pyqtSlot(str)
    def cancelDevice(self, host: str) -> None:
        self._device_action(host, "cancel")

    def _device_action(self, host: str, action: str, source_interface: str = "") -> None:
        host = host.strip()
        if not host:
            return
        self.deviceConfigStarted.emit(host, action)

        def task() -> None:
            try:
                validation = self.settings.validate()
                if not validation["ok"]:
                    result = {"ok": False, "message": str(validation["message"])}
                else:
                    config = self.settings.listener_config()
                    if action == "configure" and self._state != "listening":
                        result = {"ok": False, "message": "Start the Syslog listener before configuring a device."}
                    elif action == "configure":
                        result = self.configurator.configure(
                            host,
                            config.advertised_ip,
                            config.protocol,
                            config.port,
                            source_interface,
                        )
                    else:
                        result = self.configurator.cancel(host, config.advertised_ip, config.protocol, config.port)
            except Exception as exc:
                result = {"ok": False, "message": str(exc)}
            if result.get("code") == "source_interface_required":
                self.sourceInterfaceRequired.emit(host, str(result["message"]))
            else:
                self.deviceConfigFinished.emit(host, action, bool(result["ok"]), str(result["message"]))
            self.loadConnectedDevices()

        self.executor.submit(task)

    @pyqtSlot(str, "QVariant", int, int)
    def queryMessages(self, request_id: str, filters: Any, before_id: int = 0, limit: int = 200) -> None:
        # PyQt exposes JavaScript objects passed by QML as QJSValue instances.
        data = _variant_dict(filters)

        def task() -> None:
            try:
                rows = self.repository.query_messages(data, before_id, limit + 1)
                self.queryFinished.emit(request_id, rows[:limit], len(rows) > limit)
            except Exception as exc:
                self._error(str(exc))
                self.queryFinished.emit(request_id, [], False)

        self.executor.submit(task)

    @pyqtSlot()
    def shutdown(self) -> None:
        # Shutdown order stops sockets first, then flushes the writer queue.
        if self.receiver:
            self.receiver.stop()
            self.receiver = None
        self.writer.stop()
        self.executor.shutdown(wait=False, cancel_futures=True)
