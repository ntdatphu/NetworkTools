from __future__ import annotations

from typing import Any

from PyQt6.QtCore import pyqtSlot

from features.interfaces import (
    delete_router_interface,
    get_router_interface_by_name,
    get_router_interfaces,
    save_router_interface,
)


class InterfaceSlotsMixin:
    """Expose router-interface persistence without coupling it to DHCP."""

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
