"""Unsupported QML slots retained only when no implemented feature owns them."""

from __future__ import annotations

from typing import Any

from PyQt6.QtCore import pyqtSlot


class UnsupportedSlotsMixin:
    """Return predictable results for the remaining unsupported interface slots."""

    def _unsupported_write(self, operation: str) -> bool:
        """Report an unsupported mutation without changing application data."""
        logger = getattr(self, "_log", None)
        if callable(logger):
            logger("WARNING", f"{operation} is not implemented; no data was changed.", "SYSTEM", "db")
        return False

    @pyqtSlot(str, result="QVariant")
    def getRouterInterfaces(self, host: str) -> list[dict[str, Any]]:
        """Return an empty result until router-interface inventory is implemented."""
        return []

    @pyqtSlot(str, str, result="QVariant")
    def getRouterInterfaceByName(self, host: str, name: str) -> dict[str, Any]:
        """Return no router-interface detail until the feature is implemented."""
        return {}

    @pyqtSlot("QVariant", result=bool)
    def saveRouterInterface(self, payload: Any) -> bool:
        """Reject router-interface writes while the feature is unsupported."""
        return self._unsupported_write("saveRouterInterface")

    @pyqtSlot(int, result=bool)
    def deleteRouterInterface(self, iface_id: int) -> bool:
        """Reject router-interface deletion while the feature is unsupported."""
        return self._unsupported_write("deleteRouterInterface")
