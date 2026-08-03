from __future__ import annotations

import importlib.util
import os
import signal
import sys
from pathlib import Path


_QT_DLL_DIRECTORY_HANDLES: list[object] = []
APP_USER_MODEL_ID = "3TM.NetworkTools.App"


def _prepend_env_path(name: str, value: Path) -> None:
    current = os.environ.get(name)
    value_text = str(value)
    if current:
        paths = current.split(os.pathsep)
        if value_text in paths:
            return
        os.environ[name] = f"{value_text}{os.pathsep}{current}"
    else:
        os.environ[name] = value_text


def _bootstrap_pyqt6_paths() -> None:
    spec = importlib.util.find_spec("PyQt6")
    if spec is None or spec.submodule_search_locations is None:
        return

    pyqt6_dir = Path(next(iter(spec.submodule_search_locations)))
    qt6_dir = pyqt6_dir / "Qt6"
    qt_bin_dir = qt6_dir / "bin"
    qt_plugins_dir = qt6_dir / "plugins"
    qt_platforms_dir = qt_plugins_dir / "platforms"
    qt_qml_dir = qt6_dir / "qml"

    if os.name == "nt" and qt_bin_dir.exists():
        _QT_DLL_DIRECTORY_HANDLES.append(os.add_dll_directory(str(qt_bin_dir)))
        _prepend_env_path("PATH", qt_bin_dir)
    if qt_plugins_dir.exists():
        _prepend_env_path("QT_PLUGIN_PATH", qt_plugins_dir)
    if qt_platforms_dir.exists():
        _prepend_env_path("QT_QPA_PLATFORM_PLUGIN_PATH", qt_platforms_dir)
    if qt_qml_dir.exists():
        _prepend_env_path("QML2_IMPORT_PATH", qt_qml_dir)


def _set_windows_app_user_model_id() -> None:
    if os.name != "nt":
        return
    try:
        import ctypes

        ctypes.windll.shell32.SetCurrentProcessExplicitAppUserModelID(APP_USER_MODEL_ID)
    except Exception:
        pass


_bootstrap_pyqt6_paths()

from PyQt6.QtGui import QIcon
from PyQt6.QtQml import QQmlApplicationEngine
from PyQt6.QtWidgets import QApplication

from app_facade import (
    AppPaths,
    DatabaseManager,
    ExternalToolsManager,
    NetworkMonitor,
    QML_MODULE_DIR,
    StatusBarSettings,
    SystemAppearance,
    TerminalHelper,
    ThemeSettings,
    WindowSettings,
    WelcomeController,
    WorkspaceSaveController,
)
from scripts.build_databases import ensure_runtime_databases
from features.config_backup import ConfigBackupService
from features.config_sync import ConfigSyncService
from features.devices import DeviceLoginService, DeviceRepository, DeviceService
from features.sftp import SftpController
from features.syslog import SyslogManager
from infrastructure.network.session_registry import DeviceSessionRegistry
from infrastructure.database.paths import DEVICE_NETWORK_DB


def _runtime_arguments(argv: list[str]) -> tuple[list[str], str]:
    """Remove private brand flags and return the last selected Easter Egg."""
    brand_flags = {"-v": "nqv", "--nqv": "nqv", "-p": "ptit", "--ptit": "ptit"}
    brand_mode = ""
    for argument in argv[1:]:
        if argument in brand_flags:
            brand_mode = brand_flags[argument]
    qt_arguments = [
        argument for index, argument in enumerate(argv)
        if index == 0 or argument not in brand_flags
    ]
    return qt_arguments, brand_mode


def main() -> int:
    _set_windows_app_user_model_id()
    qt_arguments, brand_easter_egg = _runtime_arguments(sys.argv)
    try:
        bootstrap_report = ensure_runtime_databases()
    except Exception as exc:
        print(f"Failed to create missing databases: {exc}", file=sys.stderr)
        return 1

    app = QApplication(qt_arguments)
    app.setOrganizationName("3TM")
    app.setOrganizationDomain("ptit.edu.vn")
    app.setApplicationName("NetworkTools")

    icon_path = QML_MODULE_DIR / "resources" / "brand" / "logo.ico"
    if icon_path.exists():
        app.setWindowIcon(QIcon(str(icon_path)))

    engine = QQmlApplicationEngine()
    engine.addImportPath(str(Path(__file__).resolve().parent))
    engine.warnings.connect(lambda warnings: [print(w.toString(), file=sys.stderr) for w in warnings])

    config_backup_service = ConfigBackupService(Path(__file__).resolve().parent / "backup")
    device_repository = DeviceRepository()
    config_sync_service = ConfigSyncService(DEVICE_NETWORK_DB, device_repository.get_role)
    device_login_service = DeviceLoginService(device_repository)
    device_service = DeviceService(device_repository)
    session_registry = DeviceSessionRegistry(device_login_service.load)
    db_manager = DatabaseManager(config_backup_service=config_backup_service)
    cli = TerminalHelper(
        config_backup_service=config_backup_service,
        config_sync_service=config_sync_service,
        session_registry=session_registry,
        injected_device_service=device_service,
        injected_login_service=device_login_service,
        bootstrap_report=bootstrap_report,
    )
    status_bar_settings = StatusBarSettings()
    network_monitor = NetworkMonitor(settings=status_bar_settings)
    theme_settings = ThemeSettings()
    system_appearance = SystemAppearance()
    window_settings = WindowSettings()
    welcome_controller = WelcomeController()
    workspace_save_controller = WorkspaceSaveController(welcome_controller)
    app_paths = AppPaths()
    external_tools = ExternalToolsManager()
    sftp_controller = SftpController()
    # Syslog owns its own threads/database boundary.
    syslog_manager = SyslogManager()
    shutdown_complete = False

    def shutdown() -> None:
        nonlocal shutdown_complete
        if shutdown_complete:
            return
        shutdown_complete = True
        # Stop new callbacks/tasks first, then abort network I/O before releasing sessions.
        network_monitor.shutdown()
        db_manager.shutdown()
        cli.shutdown()
        try:
            device_repository.reset_connected_to_waiting()
        except Exception as exc:
            print(f"Failed to reset connected devices during shutdown: {exc}", file=sys.stderr)
        syslog_manager.shutdown()
        sftp_controller.shutdown()
        workspace_save_controller.shutdown()
        welcome_controller.shutdown()

    app.aboutToQuit.connect(shutdown)

    context = engine.rootContext()
    context.setContextProperty("dbManager", db_manager)
    context.setContextProperty("cli", cli)
    context.setContextProperty("networkMonitor", network_monitor)
    context.setContextProperty("statusBarSettings", status_bar_settings)
    context.setContextProperty("themeSettings", theme_settings)
    context.setContextProperty("systemAppearance", system_appearance)
    context.setContextProperty("windowSettings", window_settings)
    context.setContextProperty("welcomeController", welcome_controller)
    context.setContextProperty("workspaceSaveController", workspace_save_controller)
    context.setContextProperty("AppPaths", app_paths)
    context.setContextProperty("externalTools", external_tools)
    context.setContextProperty("sftpController", sftp_controller)
    context.setContextProperty("syslogManager", syslog_manager)
    context.setContextProperty("syslogSettings", syslog_manager.settings)
    context.setContextProperty("nqvEasterEggEnabled", brand_easter_egg == "nqv")
    context.setContextProperty("ptitEasterEggEnabled", brand_easter_egg == "ptit")

    workspace_window: object | None = None
    welcome_window: object | None = None

    def open_workspace(project_name: str, project_path: str) -> None:
        nonlocal workspace_window
        if workspace_window is None:
            existing_roots = set(engine.rootObjects())
            engine.loadFromModule("UI", "Main")
            created_roots = [
                root for root in engine.rootObjects() if root not in existing_roots
            ]
            if not created_roots:
                print("Failed to load QML module UI/Main.", file=sys.stderr)
                return
            workspace_window = created_roots[-1]
            if icon_path.exists():
                workspace_window.setIcon(QIcon(str(icon_path)))

        workspace_window.setProperty("workspaceDisplayName", project_name)
        workspace_window.setProperty("workspacePath", project_path)
        workspace_window.show()
        workspace_window.raise_()
        workspace_window.requestActivate()
        if welcome_window is not None:
            welcome_window.hide()

    def show_welcome(mode: str) -> None:
        if welcome_window is None:
            return
        welcome_window.show()
        welcome_window.raise_()
        welcome_window.requestActivate()
        if mode:
            welcome_window.setProperty("requestedMode", mode)
        if workspace_window is not None:
            workspace_window.hide()

    welcome_controller.workspaceRequested.connect(open_workspace)
    welcome_controller.welcomeRequested.connect(show_welcome)

    engine.loadFromModule("UI", "Welcome")
    if not engine.rootObjects():
        print("Failed to load QML module UI/Welcome.", file=sys.stderr)
        return 1
    welcome_window = engine.rootObjects()[0]
    if icon_path.exists():
        welcome_window.setIcon(QIcon(str(icon_path)))

    if syslog_manager.settings.enabledOnStartup:
        result = syslog_manager.startServer()
        if not result["ok"]:
            print(f"Syslog auto-start failed: {result['message']}", file=sys.stderr)

    def request_shutdown(_signum: int, _frame: object) -> None:
        app.quit()

    console_signals = [signal.SIGINT]
    if hasattr(signal, "SIGBREAK"):
        console_signals.append(signal.SIGBREAK)
    previous_signal_handlers = {
        console_signal: signal.getsignal(console_signal) for console_signal in console_signals
    }
    for console_signal in console_signals:
        signal.signal(console_signal, request_shutdown)
    try:
        return app.exec()
    except KeyboardInterrupt:
        # Defensive fallback for platforms that raise before the SIGINT handler is installed.
        return 0
    finally:
        shutdown()
        for console_signal, previous_handler in previous_signal_handlers.items():
            signal.signal(console_signal, previous_handler)


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        raise SystemExit(0) from None
