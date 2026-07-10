from __future__ import annotations

import os
import unittest
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

import main as _main_bootstrap  # noqa: F401 - configures PyQt DLL/QML paths
from PyQt6.QtCore import QUrl
from PyQt6.QtQml import QQmlApplicationEngine, QQmlComponent
from PyQt6.QtWidgets import QApplication

from backend import (
    AppPaths,
    DatabaseManager,
    ExternalToolsManager,
    NetworkMonitor,
    StatusBarSettings,
    TerminalHelper,
    ThemeSettings,
    WindowSettings,
)


APP_DIR = Path(__file__).resolve().parents[1]


class QmlSmokeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.app = QApplication.instance() or QApplication([])

    def setUp(self) -> None:
        self.engine = QQmlApplicationEngine()
        self.engine.addImportPath(str(APP_DIR))
        self.warnings: list[str] = []
        self.engine.warnings.connect(
            lambda warnings: self.warnings.extend(warning.toString() for warning in warnings)
        )
        self.context_objects = {
            "dbManager": DatabaseManager(),
            "cli": TerminalHelper(),
            "networkMonitor": NetworkMonitor(),
            "statusBarSettings": StatusBarSettings(),
            "themeSettings": ThemeSettings(),
            "windowSettings": WindowSettings(),
            "AppPaths": AppPaths(),
            "externalTools": ExternalToolsManager(),
        }
        context = self.engine.rootContext()
        for name, value in self.context_objects.items():
            context.setContextProperty(name, value)

    def _create(self, relative_path: str):
        component = QQmlComponent(
            self.engine,
            QUrl.fromLocalFile(str((APP_DIR / relative_path).resolve())),
        )
        instance = component.create()
        self.app.processEvents()
        self.assertTrue(instance, [error.toString() for error in component.errors()])
        return instance

    def test_network_prefix_harness(self) -> None:
        harness = self._create("tests/qml/NetworkFieldHarness.qml")
        self.assertEqual(harness.property("subnetResult"), "255.255.255.0")
        self.assertEqual(harness.property("wildcardResult"), "0.0.0.255")
        self.assertEqual(self.warnings, [])

    def test_main_module_loads(self) -> None:
        self.engine.loadFromModule("UI", "Main")
        self.app.processEvents()
        self.assertEqual(len(self.engine.rootObjects()), 1)
        self.assertEqual(self.warnings, [])

    def test_content_area_loads_every_feature_and_mode(self) -> None:
        content = self._create("UI/qml/content/ContentArea.qml")
        content.setProperty("tabCount", 1)

        for feature_index in (0, 2, 3, 5):  # Routing, DHCP, ACL, NAT
            content.setProperty("activeTextFeature", feature_index)
            self.app.processEvents()

        content.setProperty("activeTextFeature", -1)
        for feature_index in (2, 0):  # Interface, Information
            content.setProperty("activeMainFeature", feature_index)
            self.app.processEvents()

        for mode in ("settings", "database", "devices"):
            content.setProperty("appMode", mode)
            self.app.processEvents()

        flags = (
            "routingViewLoaded",
            "dhcpViewLoaded",
            "aclViewLoaded",
            "natViewLoaded",
            "interfaceViewLoaded",
            "informationViewLoaded",
            "settingsViewLoaded",
            "databaseViewLoaded",
        )
        self.assertTrue(all(content.property(flag) for flag in flags))
        self.assertEqual(self.warnings, [])

    def test_heavy_feature_tabs_load_on_first_visit(self) -> None:
        routing = self._create("UI/qml/routing/RoutingView.qml")
        for tab in ("Static", "OSPF", "EIGRP", "Info"):
            routing.setProperty("currentTab", tab)
            self.app.processEvents()
        self.assertTrue(all(routing.property(name) for name in ("infoLoaded", "staticLoaded", "ospfLoaded", "eigrpLoaded")))

        dhcp = self._create("UI/qml/dhcp/DhcpView.qml")
        for tab in ("Excluded", "Helper", "Pool"):
            dhcp.setProperty("currentTab", tab)
            self.app.processEvents()
        self.assertTrue(all(dhcp.property(name) for name in ("poolLoaded", "excludedLoaded", "helperLoaded")))

        nat = self._create("UI/qml/nat/NatView.qml")
        for tab in ("Dynamic", "PAT", "Interfaces", "ACL", "Route Map", "Static"):
            nat.setProperty("currentTab", tab)
            self.app.processEvents()
        nat_flags = ("staticLoaded", "dynamicLoaded", "patLoaded", "interfacesLoaded", "aclLoaded", "routeMapLoaded")
        self.assertTrue(all(nat.property(name) for name in nat_flags))
        self.assertEqual(self.warnings, [])


if __name__ == "__main__":
    unittest.main()
