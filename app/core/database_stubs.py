from __future__ import annotations

from typing import Any

from PyQt6.QtCore import pyqtSlot


class StubSlotsMixin:
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
