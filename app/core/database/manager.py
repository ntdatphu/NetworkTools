"""Stable QML facade composed from responsibility-specific slot mixins."""

from __future__ import annotations

import sys
from typing import Any

from PyQt6.QtCore import QObject, pyqtSignal, pyqtSlot

from features.config_backup import ConfigBackupService
from infrastructure.database.health import configure_worker_paths, validate_device_database

from ..acl_slots import AclSlotsMixin
from ..app_paths import APP_DIR
from ..config_backup_slots import ConfigBackupSlotsMixin
from ..dhcp_slots import DhcpSlotsMixin
from ..nat_slots import NatSlotsMixin
from ..switch_slots import SwitchSlotsMixin
from ..tasks import AsyncTaskCoordinator
from ..view_push import ViewPushControllerFactory
from infrastructure.database.paths import DEVICE_NETWORK_DB as DB_PATH
from .conversion import ConversionMixin
from .device_import_slots import DeviceImportSlotsMixin
from .device_slots import DeviceSlotsMixin
from .routing_slots import RoutingSlotsMixin
from features.devices import DeviceRepository
from .unsupported_slots import UnsupportedSlotsMixin
from .view_push_slots import ViewPushSlotsMixin
from .yang_slots import YangSlotsMixin


class DatabaseManager(
    ConversionMixin,
    DeviceSlotsMixin,
    DeviceImportSlotsMixin,
    RoutingSlotsMixin,
    ViewPushSlotsMixin,
    YangSlotsMixin,
    ConfigBackupSlotsMixin,
    DhcpSlotsMixin,
    AclSlotsMixin,
    NatSlotsMixin,
    SwitchSlotsMixin,
    UnsupportedSlotsMixin,
    QObject,
):
    """Compose the stable DatabaseManager QML API without feature SQL."""

    taskStarted = pyqtSignal(str)
    taskProgress = pyqtSignal(str)
    taskFinished = pyqtSignal(bool, str)
    viewPushPreviewFinished = pyqtSignal(str, str, str, bool, str, str)
    viewPushFinished = pyqtSignal(str, str, str, bool, str)

    def __init__(
        self,
        parent: QObject | None = None,
        config_backup_service: Any | None = None,
        task_coordinator: AsyncTaskCoordinator | None = None,
    ) -> None:
        """Initialize the facade and share config-backup locking when injected."""
        super().__init__(parent)
        self.app_dir = APP_DIR
        self.db_path = DB_PATH
        self._last_routing_error = ""
        self._background_tasks: dict[str, dict[str, Any]] = {}
        self._task_coordinator = task_coordinator or AsyncTaskCoordinator(self)
        self._config_backup_service = config_backup_service or ConfigBackupService(self.app_dir / "backup")
        self.initializeDatabase()
        self._view_push = ViewPushControllerFactory(self)

    @pyqtSlot(result=bool)
    def initializeDatabase(self) -> bool:
        """Validate the managed schema and synchronize compatibility worker paths."""
        try:
            validate_device_database(self.db_path)
            DeviceRepository(self.db_path).synchronize_classification()
            configure_worker_paths(self.db_path)
            return True
        except Exception as exc:
            print(f"[db] initialize failed: {exc}", file=sys.stderr)
            return False

    def shutdown(self) -> None:
        """Request active database workers to stop accepting Qt events."""
        self._task_coordinator.shutdown()
