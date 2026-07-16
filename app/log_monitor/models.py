from __future__ import annotations

from PyQt6.QtCore import QAbstractListModel, QModelIndex, Qt, pyqtProperty, pyqtSignal, pyqtSlot

from .filtering import build_packet_predicate
from .types import PacketSummary


class PacketTableModel(QAbstractListModel):
    countChanged = pyqtSignal()
    MAX_LIVE_PACKETS = 5_000
    _roles = {
        Qt.ItemDataRole.UserRole + 1: b"packetId",
        Qt.ItemDataRole.UserRole + 2: b"packetNo",
        Qt.ItemDataRole.UserRole + 3: b"timeOffset",
        Qt.ItemDataRole.UserRole + 4: b"source",
        Qt.ItemDataRole.UserRole + 5: b"destination",
        Qt.ItemDataRole.UserRole + 6: b"protocol",
        Qt.ItemDataRole.UserRole + 7: b"packetLength",
        Qt.ItemDataRole.UserRole + 8: b"info",
    }

    def __init__(self) -> None:
        super().__init__()
        self._all: list[PacketSummary] = []
        self._visible: list[PacketSummary] = []
        self._filter = ""
        self._predicate = build_packet_predicate("")

    def rowCount(self, parent=QModelIndex()) -> int:
        return 0 if parent.isValid() else len(self._visible)

    def roleNames(self) -> dict:
        return self._roles

    def data(self, index: QModelIndex, role: int):
        if not index.isValid() or not 0 <= index.row() < len(self._visible):
            return None
        packet = self._visible[index.row()]
        values = {
            Qt.ItemDataRole.UserRole + 1: (
                packet.packet_id if packet.packet_id is not None else -packet.packet_no
            ),
            Qt.ItemDataRole.UserRole + 2: packet.packet_no,
            Qt.ItemDataRole.UserRole + 3: f"{packet.time_offset:.6f}",
            Qt.ItemDataRole.UserRole + 4: packet.source,
            Qt.ItemDataRole.UserRole + 5: packet.destination,
            Qt.ItemDataRole.UserRole + 6: packet.protocol,
            Qt.ItemDataRole.UserRole + 7: packet.length,
            Qt.ItemDataRole.UserRole + 8: packet.info,
        }
        return values.get(role)

    @pyqtProperty(int, notify=countChanged)
    def count(self) -> int:
        return len(self._visible)

    def append_many(self, packets: list[PacketSummary]) -> None:
        if not packets:
            return
        self._all.extend(packets)
        if len(self._all) > self.MAX_LIVE_PACKETS:
            self.replace(self._all[-self.MAX_LIVE_PACKETS :])
            return

        visible = [packet for packet in packets if self._predicate(packet)]
        if not visible:
            return
        first = len(self._visible)
        last = first + len(visible) - 1
        self.beginInsertRows(QModelIndex(), first, last)
        self._visible.extend(visible)
        self.endInsertRows()
        self.countChanged.emit()

    def replace(self, packets: list[PacketSummary]) -> None:
        self.beginResetModel()
        self._all = list(packets[-self.MAX_LIVE_PACKETS :])
        self._visible = [packet for packet in self._all if self._predicate(packet)]
        self.endResetModel()
        self.countChanged.emit()

    def apply_filter(self, expression: str) -> None:
        predicate = build_packet_predicate(expression)
        self._filter = str(expression or "").strip()
        self._predicate = predicate
        self.replace(self._all)

    @pyqtSlot()
    def clear(self) -> None:
        self.replace([])


class DictListModel(QAbstractListModel):
    countChanged = pyqtSignal()

    def __init__(self, roles: tuple[str, ...]) -> None:
        super().__init__()
        self._items: list[dict] = []
        self._role_map = {
            Qt.ItemDataRole.UserRole + index + 1: role.encode()
            for index, role in enumerate(roles)
        }

    def rowCount(self, parent=QModelIndex()) -> int:
        return 0 if parent.isValid() else len(self._items)

    def roleNames(self) -> dict:
        return self._role_map

    def data(self, index: QModelIndex, role: int):
        if not index.isValid() or not 0 <= index.row() < len(self._items):
            return None
        role_name = self._role_map.get(role, b"").decode()
        return self._items[index.row()].get(role_name)

    def replace(self, items: list[dict]) -> None:
        self.beginResetModel()
        self._items = list(items)
        self.endResetModel()
        self.countChanged.emit()


class PacketDetailModel(DictListModel):
    def __init__(self) -> None:
        super().__init__(("depth", "name", "value", "expandable"))


class PacketBytesModel(DictListModel):
    def __init__(self) -> None:
        super().__init__(("offset", "hexBytes", "asciiText"))
