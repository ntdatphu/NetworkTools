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
    TerminalHelper,
    ThemeSettings,
    WindowSettings,
)
from scripts.build_databases import ensure_runtime_databases
from features.config_backup import ConfigBackupService
from features.devices import DeviceLoginService, DeviceRepository, DeviceService
from features.sftp import SftpController
from features.syslog import SyslogManager
from infrastructure.network.session_registry import DeviceSessionRegistry


def main() -> int:
    _set_windows_app_user_model_id()
    try:
        bootstrap_report = ensure_runtime_databases()
    except Exception as exc:
        print(f"Failed to create missing databases: {exc}", file=sys.stderr)
        return 1

    app = QApplication(sys.argv)
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
    device_login_service = DeviceLoginService(device_repository)
    device_service = DeviceService(device_repository)
    session_registry = DeviceSessionRegistry(device_login_service.load)
    db_manager = DatabaseManager(config_backup_service=config_backup_service)
    cli = TerminalHelper(
        config_backup_service=config_backup_service,
        session_registry=session_registry,
        injected_device_service=device_service,
        injected_login_service=device_login_service,
        bootstrap_report=bootstrap_report,
    )
    status_bar_settings = StatusBarSettings()
    network_monitor = NetworkMonitor(settings=status_bar_settings)
    theme_settings = ThemeSettings()
    window_settings = WindowSettings()
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
        syslog_manager.shutdown()
        sftp_controller.shutdown()

    app.aboutToQuit.connect(shutdown)

    context = engine.rootContext()
    context.setContextProperty("dbManager", db_manager)
    context.setContextProperty("cli", cli)
    context.setContextProperty("networkMonitor", network_monitor)
    context.setContextProperty("statusBarSettings", status_bar_settings)
    context.setContextProperty("themeSettings", theme_settings)
    context.setContextProperty("windowSettings", window_settings)
    context.setContextProperty("AppPaths", app_paths)
    context.setContextProperty("externalTools", external_tools)
    context.setContextProperty("sftpController", sftp_controller)
    context.setContextProperty("syslogManager", syslog_manager)
    context.setContextProperty("syslogSettings", syslog_manager.settings)

    engine.loadFromModule("UI", "Main")
    if not engine.rootObjects():
        print("Failed to load QML module UI/Main.", file=sys.stderr)
        return 1
    if icon_path.exists():
        engine.rootObjects()[0].setIcon(QIcon(str(icon_path)))

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
