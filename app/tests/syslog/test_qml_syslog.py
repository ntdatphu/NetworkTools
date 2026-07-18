import unittest
from pathlib import Path

from PyQt6.QtCore import QUrl
from PyQt6.QtQml import QQmlApplicationEngine, QQmlComponent
from PyQt6.QtWidgets import QApplication

from syslog_server.settings import SyslogSettings


APP_DIR = Path(__file__).resolve().parents[2]


class SyslogQmlTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.app = QApplication.instance() or QApplication([])

    def _create(self, relative_path: str, context: dict | None = None):
        engine = QQmlApplicationEngine()
        engine.addImportPath(str(APP_DIR))
        for name, value in (context or {}).items():
            engine.rootContext().setContextProperty(name, value)
        warnings: list[str] = []
        engine.warnings.connect(
            lambda rows: warnings.extend(row.toString() for row in rows)
        )
        component = QQmlComponent(
            engine,
            QUrl.fromLocalFile(str(APP_DIR / relative_path)),
        )
        instance = component.create()
        self.app.processEvents()
        self.assertIsNotNone(
            instance,
            [error.toString() for error in component.errors()],
        )
        return engine, instance, warnings

    def test_syslog_table_renders_list_model_without_warnings(self) -> None:
        engine, instance, warnings = self._create(
            "tests/qml/SyslogTableHarness.qml"
        )
        try:
            self.assertEqual(warnings, [])
        finally:
            instance.deleteLater()
            engine.deleteLater()

    def test_syslog_settings_spinboxes_do_not_create_binding_loops(self) -> None:
        settings = SyslogSettings()
        engine, instance, warnings = self._create(
            "UI/qml/syslog/SyslogServerSettings.qml",
            {"syslogSettings": settings, "syslogManager": None},
        )
        try:
            self.assertFalse(
                any("Binding loop" in warning for warning in warnings),
                warnings,
            )
        finally:
            instance.deleteLater()
            engine.deleteLater()


if __name__ == "__main__":
    unittest.main()
