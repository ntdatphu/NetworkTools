from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from typing import Any

from PyQt6.QtCore import QAbstractListModel, QModelIndex, Qt, pyqtSlot


def format_size(size: int) -> str:
    value = float(max(0, size))
    for unit in ("B", "KB", "MB", "GB", "TB"):
        if value < 1024 or unit == "TB":
            return f"{value:.0f} {unit}" if unit == "B" else f"{value:.1f} {unit}"
        value /= 1024
    return "0 B"


@dataclass(slots=True)
class FileItem:
    name: str
    path: str
    is_directory: bool
    size: int = 0
    modified_time: float = 0
    permissions: str = ""

    @property
    def modified_text(self) -> str:
        if not self.modified_time:
            return ""
        return datetime.fromtimestamp(self.modified_time).strftime("%Y-%m-%d %H:%M")


class FileListModel(QAbstractListModel):
    NameRole = Qt.ItemDataRole.UserRole + 1
    PathRole = Qt.ItemDataRole.UserRole + 2
    IsDirectoryRole = Qt.ItemDataRole.UserRole + 3
    SizeRole = Qt.ItemDataRole.UserRole + 4
    SizeTextRole = Qt.ItemDataRole.UserRole + 5
    ModifiedRole = Qt.ItemDataRole.UserRole + 6
    PermissionsRole = Qt.ItemDataRole.UserRole + 7

    def __init__(self, parent=None) -> None:
        super().__init__(parent)
        self._items: list[FileItem] = []

    def roleNames(self) -> dict[int, bytes]:
        return {
            self.NameRole: b"name",
            self.PathRole: b"path",
            self.IsDirectoryRole: b"isDirectory",
            self.SizeRole: b"size",
            self.SizeTextRole: b"sizeText",
            self.ModifiedRole: b"modified",
            self.PermissionsRole: b"permissions",
        }

    def rowCount(self, parent: QModelIndex = QModelIndex()) -> int:
        return 0 if parent.isValid() else len(self._items)

    def data(self, index: QModelIndex, role: int = Qt.ItemDataRole.DisplayRole) -> Any:
        if not index.isValid() or not 0 <= index.row() < len(self._items):
            return None
        item = self._items[index.row()]
        return {
            self.NameRole: item.name,
            self.PathRole: item.path,
            self.IsDirectoryRole: item.is_directory,
            self.SizeRole: item.size,
            self.SizeTextRole: "DIR" if item.is_directory else format_size(item.size),
            self.ModifiedRole: item.modified_text,
            self.PermissionsRole: item.permissions,
        }.get(role)

    def set_items(self, items: list[FileItem]) -> None:
        self.beginResetModel()
        self._items = items
        self.endResetModel()

    def clear(self) -> None:
        self.set_items([])

    @pyqtSlot(int, result="QVariant")
    def get(self, row: int) -> dict[str, Any]:
        if not 0 <= row < len(self._items):
            return {}
        item = self._items[row]
        return {
            "name": item.name,
            "path": item.path,
            "isDirectory": item.is_directory,
            "size": item.size,
            "sizeText": "DIR" if item.is_directory else format_size(item.size),
            "modified": item.modified_text,
            "permissions": item.permissions,
        }
