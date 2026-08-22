"""Qt/QML composition, fixture lifecycle, and framebuffer capture."""

from __future__ import annotations

import hashlib
import os
import tempfile
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Callable

from .environment import configure_qt_environment
from .shots import ShotSpec

configure_qt_environment()

import main as _main_bootstrap  # noqa: F401 - configures PyQt DLL/QML paths
from PyQt6.QtCore import (
    QCoreApplication,
    QEvent,
    QEventLoop,
    QObject,
    QPoint,
    QSettings,
    QSize,
    QThread,
    pyqtProperty,
    pyqtSignal,
    pyqtSlot,
)
from PyQt6.QtGui import QImage
from PyQt6.QtQml import QQmlApplicationEngine
from PyQt6.QtQuick import QQuickItem, QQuickWindow
from PyQt6.QtWidgets import QApplication

from app_facade import (
    AppPaths,
    DatabaseManager,
    ExternalToolsManager,
    MenuPresentationController,
    QML_MODULE_DIR,
    StatusBarSettings,
    ThemeSettings,
    WindowSettings,
)
from features.config_backup import ConfigBackupService
from features.config_sync import ConfigSyncService
from features.devices import DeviceRepository
from features.sftp import SftpController
from features.syslog import SyslogManager
from infrastructure.database.paths import (
    DEVICE_NETWORK_SCHEMA_DIR,
    INFO_COLLECTED_SCHEMA_DIR,
)
from infrastructure.network.session_registry import DeviceSessionRegistry
from scripts.build_databases import build_database


class DocshotError(RuntimeError):
    """A deterministic rendering or capture step failed."""


@dataclass(frozen=True, slots=True)
class RenderRequest:
    width: int
    height: int
    scale: float
    theme: str
    output_dir: Path
    timeout_ms: int = 10_000

    @property
    def pixel_size(self) -> QSize:
        return QSize(round(self.width * self.scale), round(self.height * self.scale))


@dataclass(frozen=True, slots=True)
class RenderResult:
    path: Path
    width: int
    height: int


class DocumentationTerminal(QObject):
    """Network-free implementation of the terminal/session QML contract."""

    taskStarted = pyqtSignal(str)
    taskProgress = pyqtSignal(str)
    taskFinished = pyqtSignal(bool, str)
    connectHostFinished = pyqtSignal(str, bool, str)
    deviceSessionFinished = pyqtSignal(str, bool, str)
    deviceSessionClosed = pyqtSignal(str)
    deviceCommandFinished = pyqtSignal(str, str, bool, str, str)
    runningConfigFinished = pyqtSignal(str, bool, str)
    saveConfigFinished = pyqtSignal(str, bool, str)
    manualSyncPreviewFinished = pyqtSignal(str, bool, str, object)
    batchStarted = pyqtSignal(str, str, int)
    hostOperationChanged = pyqtSignal(str, str, str, str, int)
    batchProgress = pyqtSignal(str, int, int, int, int)
    batchFinished = pyqtSignal(str, bool, object)
    sessionStateChanged = pyqtSignal(str, str, str)
    terminalStateChanged = pyqtSignal(str, str)
    terminalError = pyqtSignal(str, str)

    def __init__(self) -> None:
        super().__init__()
        self.shut_down = False

    @pyqtSlot(result="QVariant")
    def ensurePythonLoginDeps(self) -> dict[str, object]:
        return {
            "ok": True,
            "statusText": "DOC FIXTURE",
            "message": "Documentation fixture is ready; network I/O is disabled.",
        }

    @pyqtSlot(str, result=bool)
    def hasDeviceSession(self, _host: str) -> bool:
        return True

    @pyqtSlot(str, result=bool)
    def openDeviceSessionAsync(self, _host: str) -> bool:
        return True

    @pyqtSlot(str, result=str)
    def deviceTerminalState(self, _host: str) -> str:
        return "closed"

    @pyqtSlot(str, result="QVariant")
    def openDeviceTerminal(self, host: str) -> dict[str, object]:
        return {"ok": False, "message": f"External terminal disabled for {host}."}

    @pyqtSlot(str, result="QVariant")
    def pingHost(self, host: str) -> dict[str, object]:
        return {"ok": False, "severity": "info", "message": f"Network disabled for {host}."}

    @pyqtSlot(str, result=bool)
    def connectHostAndSyncAsync(self, _host: str) -> bool:
        return False

    @pyqtSlot("QVariant", result="QVariant")
    def connectHostsAndSyncAsync(self, _hosts: Any) -> dict[str, object]:
        return {"ok": False, "accepted": [], "rejected": [], "message": "Network disabled."}

    @pyqtSlot(str, result=bool)
    def saveDeviceConfigAsync(self, _host: str) -> bool:
        return False

    @pyqtSlot("QVariantList", result=str)
    def connectHostsAsync(self, _hosts: list[str]) -> str:
        return ""

    @pyqtSlot("QVariantList", result=str)
    def getRunningConfigsAsync(self, _hosts: list[str]) -> str:
        return ""

    @pyqtSlot("QVariantList", result=str)
    def disconnectHostsAsync(self, _hosts: list[str]) -> str:
        return ""

    @pyqtSlot(str, result=bool)
    def cancelBatch(self, _batch_id: str) -> bool:
        return False

    @pyqtSlot(str, result=bool)
    def manualSyncAsync(self, _host: str) -> bool:
        return False

    @pyqtSlot(str, str, result=bool)
    def applyManualSyncAsync(self, _host: str, _mode: str) -> bool:
        return False

    @pyqtSlot(str, result="QVariant")
    def closeDeviceSession(self, host: str) -> dict[str, object]:
        self.deviceSessionClosed.emit(host)
        return {"ok": True, "message": "Fixture session closed."}

    def shutdown(self) -> None:
        self.shut_down = True


class DocumentationNetworkMonitor(QObject):
    networkChanged = pyqtSignal()
    systemInfoChanged = pyqtSignal()

    @pyqtProperty(bool, constant=True)
    def isConnected(self) -> bool:
        return False

    @pyqtProperty(str, constant=True)
    def connectionType(self) -> str:
        return "none"

    @pyqtProperty(str, constant=True)
    def networkName(self) -> str:
        return ""

    @pyqtProperty("QVariantList", constant=True)
    def virtualLabs(self) -> list[object]:
        return []

    @pyqtProperty(int, constant=True)
    def virtualLabCount(self) -> int:
        return 0

    @pyqtProperty(str, constant=True)
    def virtualLabName(self) -> str:
        return ""

    @pyqtProperty(str, constant=True)
    def virtualLabState(self) -> str:
        return "offline"

    @pyqtProperty(bool, constant=True)
    def virtualLabActive(self) -> bool:
        return False

    @pyqtProperty(str, constant=True)
    def virtualLabPlatform(self) -> str:
        return ""

    @pyqtProperty(str, constant=True)
    def virtualLabServerIp(self) -> str:
        return ""

    @pyqtProperty(str, constant=True)
    def virtualLabUrl(self) -> str:
        return ""

    @pyqtProperty(str, constant=True)
    def virtualLabNameDetected(self) -> str:
        return ""

    @pyqtProperty(str, constant=True)
    def virtualLabDetail(self) -> str:
        return ""

    @pyqtProperty(int, constant=True)
    def virtualLabRunningNodeCount(self) -> int:
        return 0

    @pyqtProperty(int, constant=True)
    def ramUsagePercent(self) -> int:
        return 0

    def shutdown(self) -> None:
        pass


class DocumentationSystemAppearance(QObject):
    appearanceChanged = pyqtSignal()

    @pyqtProperty(int, constant=True)
    def colorScheme(self) -> int:
        return 1

    @pyqtProperty(bool, constant=True)
    def prefersDark(self) -> bool:
        return False


class DocumentationWelcomeController(QObject):
    recentProjectsChanged = pyqtSignal()
    workspaceRequested = pyqtSignal(str, str)
    welcomeRequested = pyqtSignal(str)
    passwordRequired = pyqtSignal(str)
    operationFailed = pyqtSignal(str, str)
    activeWorkspaceChanged = pyqtSignal()

    _RECENTS = [
        {
            "id": "doc-core-lab",
            "name": "Core Lab",
            "path": "/documentation/networktools/Core-Lab.ntp",
            "url": "file:///documentation/networktools/Core-Lab.ntp",
            "openedAtDisplay": "20/08/2026 09:42:00",
            "lastOpened": "20 Aug 2026",
            "isMock": True,
        },
        {
            "id": "doc-campus-network",
            "name": "Campus Network",
            "path": "/documentation/networktools/Campus-Network.ntp",
            "url": "file:///documentation/networktools/Campus-Network.ntp",
            "openedAtDisplay": "19/08/2026 16:10:00",
            "lastOpened": "19 Aug 2026",
            "isMock": True,
        },
        {
            "id": "doc-branch-rollout",
            "name": "Branch Rollout",
            "path": "/documentation/networktools/Branch-Rollout.ntp",
            "url": "file:///documentation/networktools/Branch-Rollout.ntp",
            "openedAtDisplay": "18/08/2026 13:25:00",
            "lastOpened": "18 Aug 2026",
            "isMock": True,
        },
    ]

    @pyqtProperty("QVariantList", notify=recentProjectsChanged)
    def recentProjects(self) -> list[dict[str, object]]:
        return [dict(item) for item in self._RECENTS]

    @pyqtSlot(str)
    def requestWelcome(self, mode: str) -> None:
        self.welcomeRequested.emit(mode)

    @pyqtSlot(str)
    def openRecent(self, project_id: str) -> None:
        project = next((item for item in self._RECENTS if item["id"] == project_id), None)
        if project:
            self.workspaceRequested.emit(str(project["name"]), str(project["path"]))

    @pyqtSlot(str)
    def openProject(self, _project_url: str) -> None:
        pass

    @pyqtSlot(str, str, str)
    def createProjectIn(self, _name: str, _folder_url: str, _password: str) -> None:
        pass

    @pyqtSlot(str)
    def unlockProject(self, _password: str) -> None:
        pass

    @pyqtSlot(str)
    def removeRecent(self, _project_id: str) -> None:
        pass

    def shutdown(self) -> None:
        pass


class DocumentationWorkspaceController(QObject):
    stateChanged = pyqtSignal()
    snapshotsChanged = pyqtSignal()
    notificationRequested = pyqtSignal(str, str)
    saveCompleted = pyqtSignal(str)
    saveFailed = pyqtSignal(str)
    workspaceCloseCompleted = pyqtSignal()

    @pyqtProperty(bool, constant=True)
    def hasWorkspace(self) -> bool:
        return True

    @pyqtProperty(bool, constant=True)
    def busy(self) -> bool:
        return False

    @pyqtProperty(bool, constant=True)
    def dirty(self) -> bool:
        return False

    @pyqtProperty(str, constant=True)
    def state(self) -> str:
        return "saved"

    @pyqtProperty(str, constant=True)
    def statusText(self) -> str:
        return "All changes saved"

    @pyqtProperty(str, constant=True)
    def lastSavedAt(self) -> str:
        return "20/08/2026 09:45"

    @pyqtProperty("QVariantList", constant=True)
    def snapshots(self) -> list[object]:
        return []

    @pyqtSlot(result=bool)
    def requestManualSave(self) -> bool:
        return True

    @pyqtSlot(result=bool)
    def requestCloseWorkspace(self) -> bool:
        return True

    @pyqtSlot(str, result=bool)
    def createSnapshot(self, _label: str = "") -> bool:
        return True

    @pyqtSlot(str, result=bool)
    def rollbackSnapshot(self, _snapshot_id: str) -> bool:
        return True

    def shutdown(self) -> None:
        pass


class FixtureBundle:
    """Own every temporary backend made visible to one QML engine."""

    def __init__(self, request: RenderRequest) -> None:
        self._temporary = tempfile.TemporaryDirectory(prefix="networktools-docshots-")
        self.root = Path(self._temporary.name)
        self._closed = False
        self._configure_settings(request)

        self.device_db = self.root / "data" / "device_network.db"
        self.info_db = self.root / "data" / "info_collected.db"
        build_database(DEVICE_NETWORK_SCHEMA_DIR, self.device_db)
        build_database(INFO_COLLECTED_SCHEMA_DIR, self.info_db)

        repository = DeviceRepository(self.device_db)
        backup_service = ConfigBackupService(self.root / "backup")
        sync_service = ConfigSyncService(self.device_db, repository.get_role)
        registry = DeviceSessionRegistry(lambda _host: None)
        self.db_manager = DatabaseManager(
            db_path=self.device_db,
            info_db_path=self.info_db,
            config_backup_service=backup_service,
            config_sync_service=sync_service,
            session_registry=registry,
        )
        self._populate_devices()

        self.cli = DocumentationTerminal()
        self.status_bar_settings = StatusBarSettings()
        for name in ("showDate", "showTime", "showNetwork", "showNetworkName", "showRam"):
            setattr(self.status_bar_settings, name, False)
        self.network_monitor = DocumentationNetworkMonitor()
        self.theme_settings = ThemeSettings()
        self.theme_settings.themeMode = 1 if request.theme == "light" else 2
        self.theme_settings.highContrast = False
        self.theme_settings.lightDarkSideBar = False
        self.theme_settings.useSystemAccentColor = False
        self.theme_settings.useCustomAccentColor = False
        self.menu_presentation = MenuPresentationController()
        self.system_appearance = DocumentationSystemAppearance()
        self.window_settings = WindowSettings()
        self.welcome_controller = DocumentationWelcomeController()
        self.workspace_controller = DocumentationWorkspaceController()
        self.app_paths = AppPaths()
        self.external_tools = ExternalToolsManager(
            db_path=self.root / "external_tools.db",
            device_db_path=self.device_db,
        )
        self.sftp_controller = SftpController(
            settings=QSettings(),
            device_login_service=None,
        )
        self.syslog_manager = SyslogManager()
        self.syslog_manager.set_database_paths(self.info_db, self.device_db)

    def _configure_settings(self, request: RenderRequest) -> None:
        QSettings.setDefaultFormat(QSettings.Format.IniFormat)
        QSettings.setPath(
            QSettings.Format.IniFormat,
            QSettings.Scope.UserScope,
            str(self.root / "settings"),
        )
        app = QCoreApplication.instance()
        if app is not None:
            app.setOrganizationName("NetworkToolsDocumentation")
            app.setApplicationName("Docshots")
        settings = QSettings()
        settings.clear()
        settings.setValue("Window/isFirstLaunch", False)
        settings.setValue("Window/isMaximized", False)
        settings.setValue("Window/savedX", 0)
        settings.setValue("Window/savedY", 0)
        settings.setValue("Window/savedWidth", request.width)
        settings.setValue("Window/savedHeight", request.height)
        settings.setValue("Appearance/menuStyle", "custom")
        settings.setValue("SFTP/defaultLocalPath", str(self.root / "sftp"))
        settings.sync()
        (self.root / "sftp").mkdir(parents=True, exist_ok=True)

    def _populate_devices(self) -> None:
        rows = (
            ("192.0.2.1", "R1", "rou", "connected"),
            ("192.0.2.2", "R2", "rou", "waiting"),
            ("192.0.2.11", "SW1", "sw2", "connected"),
        )
        for host, name, role, status in rows:
            if not self.db_manager.addDevice(
                host, name, "SSH", "22", "admin", "fixture-not-a-secret",
                "cisco_ios", role, "",
            ):
                raise DocshotError(f"Could not create fixture device {host}.")
            if not self.db_manager.updateDeviceConnectionStatus(host, status):
                raise DocshotError(f"Could not set fixture status for {host}.")

    def context_properties(self) -> dict[str, object]:
        return {
            "dbManager": self.db_manager,
            "cli": self.cli,
            "networkMonitor": self.network_monitor,
            "statusBarSettings": self.status_bar_settings,
            "themeSettings": self.theme_settings,
            "menuPresentation": self.menu_presentation,
            "systemAppearance": self.system_appearance,
            "windowSettings": self.window_settings,
            "welcomeController": self.welcome_controller,
            "workspaceSaveController": self.workspace_controller,
            "AppPaths": self.app_paths,
            "externalTools": self.external_tools,
            "sftpController": self.sftp_controller,
            "syslogManager": self.syslog_manager,
            "syslogSettings": self.syslog_manager.settings,
            "nqvEasterEggEnabled": False,
            "ptitEasterEggEnabled": False,
            "documentationMode": True,
        }

    def shutdown(self) -> None:
        if self._closed:
            return
        self._closed = True
        self.syslog_manager.shutdown()
        self.sftp_controller.shutdown()
        self.db_manager.shutdown()
        self.cli.shutdown()
        self.workspace_controller.shutdown()
        self.welcome_controller.shutdown()
        self._temporary.cleanup()

    def __enter__(self) -> "FixtureBundle":
        return self

    def __exit__(self, _type: object, _value: object, _traceback: object) -> None:
        self.shutdown()


def _application() -> QApplication:
    app = QApplication.instance()
    if app is None:
        app = QApplication(["networktools-docshots"])
    app.setOrganizationName("NetworkToolsDocumentation")
    app.setOrganizationDomain("documentation.invalid")
    app.setApplicationName("Docshots")
    return app


def _wait_until(
    app: QApplication,
    predicate: Callable[[], bool],
    timeout_ms: int,
    description: str,
) -> None:
    deadline = time.monotonic() + timeout_ms / 1000
    while time.monotonic() < deadline:
        app.processEvents(QEventLoop.ProcessEventsFlag.AllEvents, 25)
        if predicate():
            return
        QThread.msleep(5)
    app.processEvents(QEventLoop.ProcessEventsFlag.AllEvents, 25)
    if not predicate():
        raise DocshotError(f"Timed out waiting for {description} ({timeout_ms} ms).")


def capture_item(item: QQuickItem, pixel_size: QSize, timeout_ms: int = 10_000) -> QImage:
    """Render one Qt Quick item into a true target-resolution QImage."""

    if pixel_size.width() <= 0 or pixel_size.height() <= 0:
        raise DocshotError("Capture size must be positive.")
    result = item.grabToImage(pixel_size)
    if result is None:
        raise DocshotError("QQuickItem.grabToImage() did not start.")
    app = _application()
    _wait_until(
        app,
        lambda: not result.image().isNull(),
        timeout_ms,
        "QQuickItem image render",
    )
    image = result.image()
    if image.isNull():
        raise DocshotError("QQuickItem capture returned a null image.")
    if image.size() != pixel_size:
        raise DocshotError(
            f"Qt returned {image.width()}x{image.height()}, expected "
            f"{pixel_size.width()}x{pixel_size.height()}."
        )
    return image


def capture_window(window: QQuickWindow, scale: float, timeout_ms: int = 10_000) -> QImage:
    """Capture a full QML window, supersampling through the scene graph when needed."""

    logical_size = window.size()
    pixel_size = QSize(
        round(logical_size.width() * scale),
        round(logical_size.height() * scale),
    )
    if abs(scale - 1.0) < 1e-9:
        image = window.grabWindow()
        if not image.isNull() and image.size() == pixel_size:
            return image
    return capture_item(window.contentItem(), pixel_size, timeout_ms)


def _digest(image: QImage) -> bytes:
    normalized = image.convertToFormat(QImage.Format.Format_RGBA8888)
    return hashlib.sha256(normalized.bits().asstring(normalized.sizeInBytes())).digest()


def _wait_for_stable_scene(
    app: QApplication,
    engine: QQmlApplicationEngine,
    window: QQuickWindow,
    timeout_ms: int,
) -> None:
    controller = engine.incubationController()
    if controller is not None:
        _wait_until(
            app,
            lambda: controller.incubatingObjectCount() == 0,
            timeout_ms,
            "asynchronous QML components",
        )

    deadline = time.monotonic() + timeout_ms / 1000
    previous: bytes | None = None
    while time.monotonic() < deadline:
        window.requestUpdate()
        image = capture_item(window.contentItem(), window.size(), timeout_ms)
        current = _digest(image)
        if current == previous:
            return
        previous = current
        settle_deadline = min(deadline, time.monotonic() + 0.08)
        while time.monotonic() < settle_deadline:
            app.processEvents(QEventLoop.ProcessEventsFlag.AllEvents, 20)
            QThread.msleep(5)
    raise DocshotError("The QML scene did not become visually stable before timeout.")


def _prepare_window(
    app: QApplication,
    engine: QQmlApplicationEngine,
    window: QQuickWindow,
    shot: ShotSpec,
    request: RenderRequest,
) -> None:
    window.setMinimumSize(QSize(1, 1))
    window.setMaximumSize(QSize(16_384, 16_384))
    window.showNormal()
    window.resize(request.width, request.height)
    window.setPosition(QPoint(0, 0))
    if shot.workspace_name:
        window.setProperty("workspaceDisplayName", shot.workspace_name)
        window.setProperty(
            "workspacePath", "/documentation/networktools/Campus-Network.ntp"
        )
    window.show()
    _wait_until(
        app,
        lambda: (
            window.isVisible()
            and window.width() == request.width
            and window.height() == request.height
            and window.contentItem().width() == request.width
            and window.contentItem().height() == request.height
        ),
        request.timeout_ms,
        "fixed QML window geometry",
    )

    if shot.selected_host:
        sidebar = window.findChild(QObject, "mainPanelSideBar")
        if sidebar is None:
            raise DocshotError("The workspace sidebar was not created.")
        activate = getattr(sidebar, "activateDevice", None)
        if not callable(activate):
            raise DocshotError("The workspace sidebar cannot activate fixture devices.")
        activate(shot.selected_host)

    _wait_for_stable_scene(app, engine, window, request.timeout_ms)


def _save_png_atomic(image: QImage, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{destination.stem}-", suffix=".png", dir=destination.parent
    )
    os.close(descriptor)
    temporary_path = Path(temporary_name)
    try:
        if not image.save(str(temporary_path), "PNG"):
            raise DocshotError(f"Qt could not encode PNG: {destination}")
        temporary_path.replace(destination)
    finally:
        temporary_path.unlink(missing_ok=True)


def render_shot(shot: ShotSpec, request: RenderRequest) -> RenderResult:
    if request.width <= 0 or request.height <= 0 or request.scale <= 0:
        raise DocshotError("Width, height, and scale must be greater than zero.")
    app = _application()
    engine: QQmlApplicationEngine | None = None
    window: QQuickWindow | None = None
    with FixtureBundle(request) as fixture:
        try:
            engine = QQmlApplicationEngine()
            engine.addImportPath(str(QML_MODULE_DIR.parent))
            warnings: list[str] = []
            engine.warnings.connect(
                lambda messages: warnings.extend(message.toString() for message in messages)
            )
            context = engine.rootContext()
            for name, value in fixture.context_properties().items():
                context.setContextProperty(name, value)

            engine.loadFromModule("UI", shot.qml_type)
            roots = engine.rootObjects()
            if not roots or not isinstance(roots[-1], QQuickWindow):
                detail = f" QML warnings: {' | '.join(warnings)}" if warnings else ""
                raise DocshotError(f"Could not load UI/{shot.qml_type}.{detail}")
            window = roots[-1]
            _prepare_window(app, engine, window, shot, request)
            image = capture_window(window, request.scale, request.timeout_ms)
            if image.isNull() or image.width() <= 0 or image.height() <= 0:
                raise DocshotError(f"Capture for {shot.name!r} was empty.")
            if image.size() != request.pixel_size:
                raise DocshotError(
                    f"Capture for {shot.name!r} is {image.width()}x{image.height()}, "
                    f"expected {request.pixel_size.width()}x{request.pixel_size.height()}."
                )
            destination = request.output_dir / f"{shot.name}.png"
            _save_png_atomic(image, destination)
            return RenderResult(destination, image.width(), image.height())
        finally:
            if window is not None:
                window.close()
                window.deleteLater()
            if engine is not None:
                engine.clearComponentCache()
                engine.deleteLater()
            app.processEvents(QEventLoop.ProcessEventsFlag.AllEvents, 50)
            QCoreApplication.sendPostedEvents(None, QEvent.Type.DeferredDelete)
            app.processEvents(QEventLoop.ProcessEventsFlag.AllEvents, 50)


__all__ = [
    "DocshotError",
    "DocumentationTerminal",
    "FixtureBundle",
    "RenderRequest",
    "RenderResult",
    "capture_item",
    "capture_window",
    "render_shot",
]
