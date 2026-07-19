from __future__ import annotations

from ipaddress import ip_address

from PyQt6.QtCore import QObject, QSettings, pyqtProperty, pyqtSignal, pyqtSlot

from .models import ListenerConfig


class SyslogSettings(QObject):
    changed = pyqtSignal()

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._store = QSettings()

    def _get(self, key: str, default: object) -> object:
        return self._store.value(f"syslog/{key}", default)

    def _set(self, key: str, value: object) -> None:
        self._store.setValue(f"syslog/{key}", value)
        self.changed.emit()

    @pyqtProperty(bool, notify=changed)
    def enabledOnStartup(self) -> bool:
        return str(self._get("enabled_on_startup", "false")).lower() in {"1", "true"}

    @enabledOnStartup.setter
    def enabledOnStartup(self, value: bool) -> None:
        self._set("enabled_on_startup", bool(value))

    @pyqtProperty(str, notify=changed)
    def protocol(self) -> str:
        value = str(self._get("protocol", "udp")).lower()
        return value if value in {"udp", "tcp"} else "udp"

    @protocol.setter
    def protocol(self, value: str) -> None:
        self._set("protocol", value.lower())

    @pyqtProperty(str, notify=changed)
    def bindIp(self) -> str:
        return str(self._get("bind_ip", "0.0.0.0"))

    @bindIp.setter
    def bindIp(self, value: str) -> None:
        self._set("bind_ip", value.strip())

    @pyqtProperty(str, notify=changed)
    def advertisedIp(self) -> str:
        return str(self._get("advertised_ip", ""))

    @advertisedIp.setter
    def advertisedIp(self, value: str) -> None:
        self._set("advertised_ip", value.strip())

    @pyqtProperty(int, notify=changed)
    def port(self) -> int:
        return int(self._get("port", 5514))

    @port.setter
    def port(self, value: int) -> None:
        self._set("port", int(value))

    @pyqtProperty(int, notify=changed)
    def retentionDays(self) -> int:
        return int(self._get("retention_days", 30))

    @retentionDays.setter
    def retentionDays(self, value: int) -> None:
        self._set("retention_days", max(1, int(value)))

    @pyqtSlot(result="QVariant")
    def validate(self) -> dict[str, object]:
        try:
            ip_address(self.bindIp)
            advertised = ip_address(self.advertisedIp)
            if advertised.is_unspecified:
                raise ValueError("Advertised IP cannot be 0.0.0.0/::")
            if not 1 <= self.port <= 65535:
                raise ValueError("Port must be between 1 and 65535")
            if self.protocol not in {"udp", "tcp"}:
                raise ValueError("Protocol must be UDP or TCP")
        except ValueError as exc:
            return {"ok": False, "message": str(exc)}
        return {"ok": True, "message": "Syslog settings are valid."}

    def listener_config(self) -> ListenerConfig:
        result = self.validate()
        if not result["ok"]:
            raise ValueError(str(result["message"]))
        return ListenerConfig(self.bindIp, self.advertisedIp, self.port, self.protocol)

