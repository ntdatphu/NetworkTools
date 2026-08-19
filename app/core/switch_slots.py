from __future__ import annotations

from typing import Any

from PyQt6.QtCore import pyqtSlot

# Imports use the canonical feature package; no sys.path mutation is required.
from features.switching import (
    get_ip_routing,
    get_mac_table,
    get_port_counters,
    get_svis,
    get_switch_interfaces,
    get_vlans,
    navigation_for_role,
    save_ip_routing,
    save_svi,
    save_switch_interface,
    save_vlan,
    VtpGroupService,
)


class SwitchSlotsMixin:
    """QML bridge for local switch workspace operations."""

    @pyqtSlot(str, result="QVariant")
    def getSwitchNavigation(self, role: str) -> list[dict[str, Any]]:
        return navigation_for_role(role)

    @pyqtSlot(str, result="QVariant")
    def getSwitchVlans(self, host: str) -> list[dict[str, Any]]:
        return get_vlans(self, host)

    @pyqtSlot(str, "QVariant", result="QVariant")
    def saveSwitchVlan(self, host: str, payload: Any) -> dict[str, Any]:
        return save_vlan(self, host, self._as_dict(payload))

    @pyqtSlot(str, result="QVariant")
    def getSwitchInterfaces(self, host: str) -> list[dict[str, Any]]:
        return get_switch_interfaces(self, host)

    @pyqtSlot(str, "QVariant", result="QVariant")
    def saveSwitchInterface(self, host: str, payload: Any) -> dict[str, Any]:
        return save_switch_interface(self, host, self._as_dict(payload))

    @pyqtSlot(str, result="QVariant")
    def getSwitchSvis(self, host: str) -> list[dict[str, Any]]:
        return get_svis(self, host)

    @pyqtSlot(str, "QVariant", result="QVariant")
    def saveSwitchSvi(self, host: str, payload: Any) -> dict[str, Any]:
        return save_svi(self, host, self._as_dict(payload))

    @pyqtSlot(str, result="QVariant")
    def getSwitchIpRouting(self, host: str) -> dict[str, Any]:
        return get_ip_routing(self, host)

    @pyqtSlot(str, "QVariant", result="QVariant")
    def saveSwitchIpRouting(self, host: str, enabled: Any) -> dict[str, Any]:
        return save_ip_routing(self, host, enabled)

    @pyqtSlot(result="QVariant")
    def getVtpGroupOptions(self) -> dict[str, Any]:
        """Return connected switches eligible for a VTP group."""
        return VtpGroupService(self).options()

    @pyqtSlot(result="QVariant")
    def getVtpGroups(self) -> dict[str, Any]:
        """Return locally stored VTP domains and their switch members."""
        return VtpGroupService(self).groups()

    @pyqtSlot("QVariant", result="QVariant")
    def saveVtpGroup(self, payload: Any) -> dict[str, Any]:
        """Stage one VTP domain for several switches."""
        return VtpGroupService(self).save(self._as_dict(payload))

    @pyqtSlot(str, result="QVariant")
    def getSwitchPortCounters(self, host: str) -> list[dict[str, Any]]:
        return get_port_counters(self, host)

    @pyqtSlot(str, result="QVariant")
    def getSwitchMacTable(self, host: str) -> list[dict[str, Any]]:
        return get_mac_table(self, host)
