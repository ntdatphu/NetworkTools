import os
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PyQt6.QtCore import QUrl
from PyQt6.QtQml import QQmlApplicationEngine, QQmlComponent
from PyQt6.QtWidgets import QApplication

from syslog_server.settings import SyslogSettings


APP_DIR = Path(__file__).resolve().parents[2]


def test_syslog_table_renders_list_model_without_warnings() -> None:
    app = QApplication.instance() or QApplication([])
    engine = QQmlApplicationEngine()
    engine.addImportPath(str(APP_DIR))
    warnings: list[str] = []
    engine.warnings.connect(lambda rows: warnings.extend(row.toString() for row in rows))
    component = QQmlComponent(
        engine,
        QUrl.fromLocalFile(str(APP_DIR / "tests" / "qml" / "SyslogTableHarness.qml")),
    )
    instance = component.create()
    app.processEvents()
    try:
        assert instance is not None, [error.toString() for error in component.errors()]
        assert warnings == []
    finally:
        if instance is not None:
            instance.deleteLater()
        engine.deleteLater()


def test_syslog_settings_spinboxes_do_not_create_binding_loops() -> None:
    app = QApplication.instance() or QApplication([])
    engine = QQmlApplicationEngine()
    engine.addImportPath(str(APP_DIR))
    settings = SyslogSettings()
    engine.rootContext().setContextProperty("syslogSettings", settings)
    warnings: list[str] = []
    engine.warnings.connect(lambda rows: warnings.extend(row.toString() for row in rows))
    component = QQmlComponent(
        engine,
        QUrl.fromLocalFile(str(APP_DIR / "UI" / "qml" / "syslog" / "SyslogServerSettings.qml")),
    )
    instance = component.create()
    app.processEvents()
    try:
        assert instance is not None, [error.toString() for error in component.errors()]
        assert not any("Binding loop" in warning for warning in warnings)
    finally:
        if instance is not None:
            instance.deleteLater()
        engine.deleteLater()
