"""Stable QML facade composed from responsibility-specific slot mixins."""

from __future__ import annotations

import sys
from pathlib import Path
from typing import Any

from PyQt6.QtCore import QObject, pyqtSignal, pyqtSlot

from features.config_backup import ConfigBackupService
from infrastructure.database.health import configure_worker_paths, validate_device_database

from ..acl_slots import AclSlotsMixin
from ..app_paths import APP_DIR
from ..config_backup_slots import ConfigBackupSlotsMixin
from ..dhcp_slots import DhcpSlotsMixin
from ..fhrp_slots import FhrpSlotsMixin
from ..interface_slots import InterfaceSlotsMixin
from ..nat_slots import NatSlotsMixin
from ..switch_slots import SwitchSlotsMixin
from ..tasks import AsyncTaskCoordinator
from ..view_push import ViewPushControllerFactory
from infrastructure.database.paths import (
    DEVICE_NETWORK_DB as DB_PATH,
    INFO_COLLECTED_DB as INFO_DB_PATH,
)
from .conversion import ConversionMixin
from .device_import_slots import DeviceImportSlotsMixin
from .device_slots import DeviceSlotsMixin
from .routing_slots import RoutingSlotsMixin
from features.devices import DeviceRepository
from .unsupported_slots import UnsupportedSlotsMixin
from .view_push_slots import ViewPushSlotsMixin


class DatabaseManager(
    ConversionMixin,
    DeviceSlotsMixin,
    DeviceImportSlotsMixin,
    RoutingSlotsMixin,
    ViewPushSlotsMixin,
    ConfigBackupSlotsMixin,
    InterfaceSlotsMixin,
    DhcpSlotsMixin,
    FhrpSlotsMixin,
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
    sshTestFinished = pyqtSignal(str, bool, str, object)

    def __init__(
        self,
        parent: QObject | None = None,
        config_backup_service: Any | None = None,
        task_coordinator: AsyncTaskCoordinator | None = None,
        db_path: Any | None = None,
        info_db_path: Any | None = None,
        session_registry: Any | None = None,
        config_sync_service: Any | None = None,
    ) -> None:
        """Initialize the facade and share config-backup locking when injected."""
        super().__init__(parent)
        self.app_dir = APP_DIR
        self.db_path = DB_PATH if db_path is None else Path(db_path)
        self.info_db_path = (
            INFO_DB_PATH if info_db_path is None else Path(info_db_path)
        )
        self._last_routing_error = ""
        self._background_tasks: dict[str, dict[str, Any]] = {}
        self._task_coordinator = task_coordinator or AsyncTaskCoordinator(self)
        self._config_backup_service = config_backup_service or ConfigBackupService(self.app_dir / "backup")
        self._config_sync_service = config_sync_service
        self.initializeDatabase()
        self._view_push = ViewPushControllerFactory(self, session_registry)

    def set_workspace_databases(
        self, device_database: Any, info_database: Any
    ) -> bool:
        """Route all subsequent facade operations to the active workspace."""
        previous_device = self.db_path
        previous_info = self.info_db_path
        self.db_path = Path(device_database)
        self.info_db_path = Path(info_database)
        if self.initializeDatabase():
            return True
        self.db_path = previous_device
        self.info_db_path = previous_info
        self.initializeDatabase()
        return False

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
