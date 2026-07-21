"""Qt monitoring facade backed by infrastructure system probes."""

from PyQt6.QtCore import QObject, QTimer, pyqtProperty, pyqtSignal

from infrastructure.system.network_info import read_network_info
from infrastructure.system.resource_monitor import read_ram_usage_percent

class NetworkMonitor(QObject):
    networkChanged = pyqtSignal()
    systemInfoChanged = pyqtSignal()

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._connected = False
        self._connection_type = "none"
        self._network_name = ""
        self._virtual_lab_name = ""
        self._ram_usage_percent = 0
        self._timer = QTimer(self)
        self._timer.timeout.connect(self._refresh)
        self._timer.start(3000)
        self._refresh()

    def _refresh(self) -> None:
        ram_usage_percent = read_ram_usage_percent()
        if ram_usage_percent != self._ram_usage_percent:
            self._ram_usage_percent = ram_usage_percent
            self.systemInfoChanged.emit()

        connected, connection_type, network_name, virtual_lab_name = read_network_info()
        if (
            connected != self._connected
            or connection_type != self._connection_type
            or network_name != self._network_name
            or virtual_lab_name != self._virtual_lab_name
        ):
            self._connected = connected
            self._connection_type = connection_type
            self._network_name = network_name
            self._virtual_lab_name = virtual_lab_name
            self.networkChanged.emit()

    def shutdown(self) -> None:
        """Stop periodic probes before application teardown begins."""
        self._timer.stop()

    @pyqtProperty(bool, notify=networkChanged)
    def isConnected(self) -> bool:
        return self._connected

    @pyqtProperty(str, notify=networkChanged)
    def connectionType(self) -> str:
        return self._connection_type

    @pyqtProperty(str, notify=networkChanged)
    def networkName(self) -> str:
        return self._network_name

    @pyqtProperty(str, notify=networkChanged)
    def virtualLabName(self) -> str:
        return self._virtual_lab_name

    @pyqtProperty(int, notify=systemInfoChanged)
    def ramUsagePercent(self) -> int:
        return self._ram_usage_percent

__all__ = ["NetworkMonitor"]
