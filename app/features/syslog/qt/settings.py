"""Persistent and validated QSettings adapter exposed to QML."""

from __future__ import annotations

import socket
from ipaddress import ip_address

from PyQt6.QtCore import QObject, QSettings, pyqtProperty, pyqtSignal, pyqtSlot

from ..domain.models import ListenerConfig


def _local_ipv4_addresses() -> list[str]:
    try:
        import psutil  # type: ignore
        addresses_by_name = psutil.net_if_addrs()
        stats_by_name = psutil.net_if_stats()
    except Exception:
        return []
    addresses: list[str] = []
    for interface_name, interface_addresses in addresses_by_name.items():
        stats = stats_by_name.get(interface_name)
        if stats is not None and not stats.isup:
            continue
        for item in interface_addresses:
            if item.family != socket.AF_INET:
                continue
            value = str(item.address or "").strip()
            try:
                address = ip_address(value)
            except ValueError:
                continue
            if address.is_loopback or address.is_unspecified or address.is_link_local:
                continue
            if value not in addresses:
                addresses.append(value)
    return addresses


def _validate_ip(value: str, field_name: str, *, allow_unspecified: bool) -> None:
    value = (value or "").strip()
    if not value:
        raise ValueError(f"{field_name} is required")
    try:
        address = ip_address(value)
    except ValueError as exc:
        raise ValueError(f"{field_name} must be a valid IPv4 or IPv6 address") from exc
    if not allow_unspecified and address.is_unspecified:
        raise ValueError(f"{field_name} cannot be 0.0.0.0 or ::")


class SyslogSettings(QObject):
    changed = pyqtSignal()

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._store = QSettings()
        self._available_advertised_ips = _local_ipv4_addresses()

    def _get(self, key: str, default: object) -> object:
        return self._store.value(f"syslog/{key}", default)

    def _set(self, key: str, value: object) -> None:
        self._store.setValue(f"syslog/{key}", value)
        self._store.sync()
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
        stored = str(self._get("advertised_ip", "")).strip()
        if stored:
            return stored
        return self._available_advertised_ips[0] if self._available_advertised_ips else ""

    @advertisedIp.setter
    def advertisedIp(self, value: str) -> None:
        self._set("advertised_ip", value.strip())

    @pyqtProperty("QVariantList", notify=changed)
    def availableAdvertisedIps(self) -> list[str]:
        return list(self._available_advertised_ips)

    @pyqtSlot()
    def refreshLocalIps(self) -> None:
        addresses = _local_ipv4_addresses()
        if addresses == self._available_advertised_ips:
            return
        self._available_advertised_ips = addresses
        self.changed.emit()

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
    def validateListener(self) -> dict[str, object]:
        try:
            _validate_ip(self.bindIp, "Bind IP", allow_unspecified=True)
            if not 1 <= self.port <= 65535:
                raise ValueError("Port must be between 1 and 65535")
            if self.protocol not in {"udp", "tcp"}:
                raise ValueError("Protocol must be UDP or TCP")
        except ValueError as exc:
            return {"ok": False, "message": str(exc)}
        return {"ok": True, "message": "Syslog listener settings are valid."}

    @pyqtSlot(result="QVariant")
    def validate(self) -> dict[str, object]:
        listener_result = self.validateListener()
        if not listener_result["ok"]:
            return listener_result
        try:
            _validate_ip(self.advertisedIp, "Advertised/server IP", allow_unspecified=False)
            if self.advertisedIp not in self._available_advertised_ips:
                raise ValueError(
                    "Advertised/server IP must be assigned to an active network interface on this machine"
                )
        except ValueError as exc:
            return {"ok": False, "message": str(exc)}
        return {"ok": True, "message": "Syslog settings are valid."}

    def listener_config(self) -> ListenerConfig:
        result = self.validateListener()
        if not result["ok"]:
            raise ValueError(str(result["message"]))
        return ListenerConfig(self.bindIp, self.advertisedIp, self.port, self.protocol)


__all__ = ["SyslogSettings", "_local_ipv4_addresses", "_validate_ip"]
