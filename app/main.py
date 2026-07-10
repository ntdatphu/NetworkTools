from __future__ import annotations

import importlib.util
import os
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

from backend import AppPaths, DatabaseManager, ExternalToolsManager, NetworkMonitor, QML_MODULE_DIR, StatusBarSettings, ThemeSettings, TerminalHelper


def main() -> int:
    _set_windows_app_user_model_id()
    app = QApplication(sys.argv)
    app.setOrganizationName("3TM")
    app.setOrganizationDomain("ptit.edu.vn")
    app.setApplicationName("NetworkTools")

    icon_path = QML_MODULE_DIR / "resources" / "icons" / "logo.ico"
    if icon_path.exists():
        app.setWindowIcon(QIcon(str(icon_path)))

    engine = QQmlApplicationEngine()
    engine.addImportPath(str(Path(__file__).resolve().parent))
    engine.warnings.connect(lambda warnings: [print(w.toString(), file=sys.stderr) for w in warnings])

    db_manager = DatabaseManager()
    cli = TerminalHelper()
    network_monitor = NetworkMonitor()
    status_bar_settings = StatusBarSettings()
    theme_settings = ThemeSettings()
    app_paths = AppPaths()
    external_tools = ExternalToolsManager()

    context = engine.rootContext()
    context.setContextProperty("dbManager", db_manager)
    context.setContextProperty("cli", cli)
    context.setContextProperty("networkMonitor", network_monitor)
    context.setContextProperty("statusBarSettings", status_bar_settings)
    context.setContextProperty("themeSettings", theme_settings)
    context.setContextProperty("AppPaths", app_paths)
    context.setContextProperty("externalTools", external_tools)

    engine.loadFromModule("UI", "Main")
    if not engine.rootObjects():
        print("Failed to load QML module UI/Main.", file=sys.stderr)
        return 1
    if icon_path.exists():
        engine.rootObjects()[0].setIcon(QIcon(str(icon_path)))

    return app.exec()


if __name__ == "__main__":
    raise SystemExit(main())
