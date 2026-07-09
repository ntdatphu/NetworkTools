from __future__ import annotations

import importlib.util
import os
import sys
import traceback
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
from PyQt6.QtCore import QtMsgType, qInstallMessageHandler

from backend import AppLogger, AppPaths, DatabaseManager, NetworkMonitor, QML_MODULE_DIR, StatusBarSettings, ThemeSettings, TerminalHelper


def _safe_log(app_logger: AppLogger, status: str, message: str, source: str, category: str = "") -> None:
    try:
        app_logger.log(status, message, source, category)
    except Exception:
        pass


def _install_runtime_logging(app_logger: AppLogger) -> None:
    app_logger.install_stdio_redirect()

    def excepthook(exc_type: type[BaseException], exc: BaseException, tb: object) -> None:
        if issubclass(exc_type, KeyboardInterrupt):
            return
        details = "".join(traceback.format_exception(exc_type, exc, tb)).strip()
        _safe_log(app_logger, "CRITICAL", details, "python")

    def qt_message_handler(mode: QtMsgType, context: object, message: str) -> None:
        if message.startswith("file:///") and ".qml:" in message:
            return
        if message == "Retrying to obtain clipboard.":
            return
        status = "INFO"
        if mode == QtMsgType.QtWarningMsg:
            status = "WARNING"
        elif mode == QtMsgType.QtCriticalMsg:
            status = "ERROR"
        elif mode == QtMsgType.QtFatalMsg:
            status = "CRITICAL"
        _safe_log(app_logger, status, message, "qt")

    sys.excepthook = excepthook
    qInstallMessageHandler(qt_message_handler)


def main() -> int:
    _set_windows_app_user_model_id()
    app = QApplication(sys.argv)
    app.setOrganizationName("3TM")
    app.setOrganizationDomain("ptit.edu.vn")
    app.setApplicationName("NetworkTools")

    icon_path = QML_MODULE_DIR / "resources" / "icons" / "logo.ico"
    if icon_path.exists():
        app.setWindowIcon(QIcon(str(icon_path)))

    app_logger = AppLogger()
    _install_runtime_logging(app_logger)
    app_logger.log("SUCCESS", "Application started.", "app")

    engine = QQmlApplicationEngine()
    engine.addImportPath(str(Path(__file__).resolve().parent))
    engine.warnings.connect(lambda warnings: [_safe_log(app_logger, "WARNING", w.toString(), "qml") for w in warnings])

    db_manager = DatabaseManager(app_logger=app_logger)
    cli = TerminalHelper(app_logger=app_logger)
    network_monitor = NetworkMonitor()
    status_bar_settings = StatusBarSettings()
    theme_settings = ThemeSettings()
    app_paths = AppPaths()

    context = engine.rootContext()
    context.setContextProperty("appLogger", app_logger)
    context.setContextProperty("dbManager", db_manager)
    context.setContextProperty("cli", cli)
    context.setContextProperty("networkMonitor", network_monitor)
    context.setContextProperty("statusBarSettings", status_bar_settings)
    context.setContextProperty("themeSettings", theme_settings)
    context.setContextProperty("AppPaths", app_paths)

    engine.loadFromModule("UI", "Main")
    if not engine.rootObjects():
        app_logger.log("CRITICAL", "Failed to load QML module UI/Main.", "qml")
        return 1
    if icon_path.exists():
        engine.rootObjects()[0].setIcon(QIcon(str(icon_path)))

    return app.exec()


if __name__ == "__main__":
    raise SystemExit(main())
