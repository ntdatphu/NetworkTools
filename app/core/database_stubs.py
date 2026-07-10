from __future__ import annotations

from typing import Any

from PyQt6.QtCore import pyqtSlot


class StubSlotsMixin:
    def _unsupported_write(self, operation: str) -> bool:
        logger = getattr(self, "_log", None)
        if callable(logger):
            logger("WARNING", f"{operation} is not implemented; no data was changed.", "SYSTEM", "db")
        return False

    @pyqtSlot(str, result="QVariant")
    def getRouterInterfaces(self, host: str) -> list[dict[str, Any]]:
        return []

    @pyqtSlot(str, str, result="QVariant")
    def getRouterInterfaceByName(self, host: str, name: str) -> dict[str, Any]:
        return {}

    @pyqtSlot("QVariant", result=bool)
    def saveRouterInterface(self, payload: Any) -> bool:
        return self._unsupported_write("saveRouterInterface")

    @pyqtSlot(int, result=bool)
    def deleteRouterInterface(self, iface_id: int) -> bool:
        return self._unsupported_write("deleteRouterInterface")

    @pyqtSlot(str, result="QVariant")
    def getDhcpPools(self, host: str) -> list[dict[str, Any]]:
        return []

    @pyqtSlot(str, str, str, str, str, str, str, result=bool)
    def addDhcpPool(self, host: str, pool: str, network: str, subnetmask: str, default: str, dns: str, lease: str) -> bool:
        return self._unsupported_write("addDhcpPool")

    @pyqtSlot(int, str, str, str, str, str, str, result=bool)
    def updateDhcpPool(self, dhcp_id: int, pool: str, network: str, subnetmask: str, default: str, dns: str, lease: str) -> bool:
        return self._unsupported_write("updateDhcpPool")

    @pyqtSlot(int, result=bool)
    def deleteDhcpPool(self, dhcp_id: int) -> bool:
        return self._unsupported_write("deleteDhcpPool")

    @pyqtSlot(str, result="QVariant")
    def getExcludedAddresses(self, host: str) -> list[dict[str, Any]]:
        return []

    @pyqtSlot(str, str, str, result=bool)
    def addExcludedAddress(self, host: str, start_ip: str, end_ip: str) -> bool:
        return self._unsupported_write("addExcludedAddress")

    @pyqtSlot(int, result=bool)
    def deleteExcludedAddress(self, ex_id: int) -> bool:
        return self._unsupported_write("deleteExcludedAddress")

    @pyqtSlot(str, result="QVariant")
    def getDhcpHelperAddresses(self, host: str) -> list[dict[str, Any]]:
        return []

    @pyqtSlot(int, str, result=bool)
    def addDhcpHelperAddress(self, iface_id: int, helper_ip: str) -> bool:
        return self._unsupported_write("addDhcpHelperAddress")

    @pyqtSlot(int, result=bool)
    def deleteDhcpHelperAddress(self, helper_id: int) -> bool:
        return self._unsupported_write("deleteDhcpHelperAddress")

    @pyqtSlot(str, str, result="QVariant")
    def getAcls(self, host: str, acl_type: str) -> list[dict[str, Any]]:
        return []

    @pyqtSlot("QVariant", result=bool)
    def saveAcl(self, payload: Any) -> bool:
        return self._unsupported_write("saveAcl")

    @pyqtSlot(int, result=bool)
    def deleteAcl(self, acl_id: int) -> bool:
        return self._unsupported_write("deleteAcl")

    @pyqtSlot(str, result="QVariant")
    def getNatStaticEntries(self, host: str) -> list[dict[str, Any]]:
        return []

    # UI-P0-01: Keep these placeholder slot contracts identical to the QML
    # forms. A stub must fail predictably through _unsupported_write(), not at
    # Qt's argument-dispatch boundary before the UI can show a useful warning.
    @pyqtSlot(str, str, str, str, str, str, result=bool)
    def addNatStaticEntry(
        self,
        host: str,
        local_ip: str,
        global_ip: str,
        protocol: str,
        local_port: str,
        global_port: str,
    ) -> bool:
        return self._unsupported_write("addNatStaticEntry")

    @pyqtSlot(int, result=bool)
    def deleteNatStaticEntry(self, nat_static_id: int) -> bool:
        return self._unsupported_write("deleteNatStaticEntry")

    @pyqtSlot(str, result="QVariant")
    def getNatInterfaces(self, host: str) -> list[dict[str, Any]]:
        return []

    @pyqtSlot(str, str, str, result=bool)
    def addNatInterface(self, host: str, interface_name: str, nat_role: str) -> bool:
        return self._unsupported_write("addNatInterface")

    @pyqtSlot(int, result=bool)
    def deleteNatInterface(self, nat_intf_id: int) -> bool:
        return self._unsupported_write("deleteNatInterface")

    @pyqtSlot(str, result="QVariant")
    def getNatDynamicPools(self, host: str) -> list[dict[str, Any]]:
        return []

    @pyqtSlot(str, str, str, str, str, str, result=bool)
    def addNatDynamicPool(
        self,
        host: str,
        pool_name: str,
        start_ip: str,
        end_ip: str,
        netmask: str,
        acl_name: str,
    ) -> bool:
        return self._unsupported_write("addNatDynamicPool")

    @pyqtSlot(int, result=bool)
    def deleteNatDynamicPool(self, nat_dynamic_id: int) -> bool:
        return self._unsupported_write("deleteNatDynamicPool")

    @pyqtSlot(str, result="QVariant")
    def getNatPatRules(self, host: str) -> list[dict[str, Any]]:
        return []

    @pyqtSlot(str, str, str, str, bool, result=bool)
    def addNatPatRule(
        self,
        host: str,
        acl_name: str,
        source_type: str,
        source_value: str,
        overload: bool,
    ) -> bool:
        return self._unsupported_write("addNatPatRule")

    @pyqtSlot(int, result=bool)
    def deleteNatPatRule(self, nat_pat_id: int) -> bool:
        return self._unsupported_write("deleteNatPatRule")

    @pyqtSlot(str, result="QVariant")
    def getNatAcls(self, host: str) -> list[dict[str, Any]]:
        return []

    @pyqtSlot(str, str, str, str, str, result=bool)
    def addNatAcl(self, host: str, acl_name: str, action: str, source_network: str, wildcard: str) -> bool:
        return self._unsupported_write("addNatAcl")

    @pyqtSlot(int, result=bool)
    def deleteNatAcl(self, nat_acl_id: int) -> bool:
        return self._unsupported_write("deleteNatAcl")

    @pyqtSlot(str, result="QVariant")
    def getNatRouteMapEntries(self, host: str) -> list[dict[str, Any]]:
        return []

    @pyqtSlot(str, str, str, int, str, str, result=bool)
    def addNatRouteMapEntry(
        self,
        host: str,
        route_map_name: str,
        description: str,
        sequence: int,
        action: str,
        acl_name: str,
    ) -> bool:
        return self._unsupported_write("addNatRouteMapEntry")

    @pyqtSlot(int, result=bool)
    def deleteNatRouteMapEntry(self, route_map_entry_id: int) -> bool:
        return self._unsupported_write("deleteNatRouteMapEntry")
