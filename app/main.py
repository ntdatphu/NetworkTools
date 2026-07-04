from __future__ import annotations

import sys
from pathlib import Path

from PyQt6.QtGui import QIcon
from PyQt6.QtQml import QQmlApplicationEngine
from PyQt6.QtWidgets import QApplication

from backend import AppPaths, DatabaseManager, NetworkMonitor, QML_MODULE_DIR, TerminalHelper


def main() -> int:
    app = QApplication(sys.argv)
    app.setOrganizationName("3TM")
    app.setOrganizationDomain("ptit.edu.vn")
    app.setApplicationName("NetworkTools")

    icon_path = QML_MODULE_DIR / "resources" / "icons" / "logo.png"
    if icon_path.exists():
        app.setWindowIcon(QIcon(str(icon_path)))

    engine = QQmlApplicationEngine()
    engine.addImportPath(str(Path(__file__).resolve().parent))

    db_manager = DatabaseManager()
    cli = TerminalHelper()
    network_monitor = NetworkMonitor()
    app_paths = AppPaths()

    context = engine.rootContext()
    context.setContextProperty("dbManager", db_manager)
    context.setContextProperty("cli", cli)
    context.setContextProperty("networkMonitor", network_monitor)
    context.setContextProperty("AppPaths", app_paths)

    engine.loadFromModule("NetworkTools", "Main")
    if not engine.rootObjects():
        return 1

    return app.exec()


if __name__ == "__main__":
    raise SystemExit(main())
