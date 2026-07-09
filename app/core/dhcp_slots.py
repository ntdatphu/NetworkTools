from __future__ import annotations

from typing import Any

from PyQt6.QtCore import pyqtSlot

from dhcp import (
    add_dhcp_helper_address,
    add_dhcp_pool,
    add_excluded_address,
    delete_dhcp_helper_address,
    delete_dhcp_pool,
    delete_router_interface,
    delete_excluded_address,
    get_router_interface_by_name,
    get_dhcp_helper_addresses,
    get_dhcp_pools,
    get_excluded_addresses,
    get_router_interfaces,
    save_router_interface,
    update_dhcp_pool,
)


class DhcpSlotsMixin:
    @pyqtSlot(str, result="QVariant")
    def getRouterInterfaces(self, host: str) -> list[dict[str, Any]]:
        return get_router_interfaces(self, host)

    @pyqtSlot(str, str, result="QVariant")
    def getRouterInterfaceByName(self, host: str, name: str) -> dict[str, Any]:
        return get_router_interface_by_name(self, host, name)

    @pyqtSlot("QVariant", result=bool)
    def saveRouterInterface(self, payload: Any) -> bool:
        return save_router_interface(self, payload)

    @pyqtSlot(int, result=bool)
    def deleteRouterInterface(self, iface_id: int) -> bool:
        return delete_router_interface(self, iface_id)

    @pyqtSlot(str, result="QVariant")
    def getDhcpPools(self, host: str) -> list[dict[str, Any]]:
        return get_dhcp_pools(self, host)

    @pyqtSlot(str, str, str, str, str, str, str, result=bool)
    def addDhcpPool(self, host: str, pool: str, network: str, subnetmask: str, default: str, dns: str, lease: str) -> bool:
        return add_dhcp_pool(self, host, pool, network, subnetmask, default, dns, lease)

    @pyqtSlot(int, str, str, str, str, str, str, result=bool)
    def updateDhcpPool(self, dhcp_id: int, pool: str, network: str, subnetmask: str, default: str, dns: str, lease: str) -> bool:
        return update_dhcp_pool(self, dhcp_id, pool, network, subnetmask, default, dns, lease)

    @pyqtSlot(int, result=bool)
    def deleteDhcpPool(self, dhcp_id: int) -> bool:
        return delete_dhcp_pool(self, dhcp_id)

    @pyqtSlot(str, result="QVariant")
    def getExcludedAddresses(self, host: str) -> list[dict[str, Any]]:
        return get_excluded_addresses(self, host)

    @pyqtSlot(str, str, str, result=bool)
    def addExcludedAddress(self, host: str, start_ip: str, end_ip: str) -> bool:
        return add_excluded_address(self, host, start_ip, end_ip)

    @pyqtSlot(int, result=bool)
    def deleteExcludedAddress(self, ex_id: int) -> bool:
        return delete_excluded_address(self, ex_id)

    @pyqtSlot(str, result="QVariant")
    def getDhcpHelperAddresses(self, host: str) -> list[dict[str, Any]]:
        return get_dhcp_helper_addresses(self, host)

    @pyqtSlot(int, str, result=bool)
    def addDhcpHelperAddress(self, iface_id: int, helper_ip: str) -> bool:
        return add_dhcp_helper_address(self, iface_id, helper_ip)

    @pyqtSlot(int, result=bool)
    def deleteDhcpHelperAddress(self, helper_id: int) -> bool:
        return delete_dhcp_helper_address(self, helper_id)
