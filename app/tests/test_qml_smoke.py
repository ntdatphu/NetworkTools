from __future__ import annotations

import os
import unittest
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

import main as _main_bootstrap  # noqa: F401 - configures PyQt DLL/QML paths
from PyQt6.QtCore import Q_ARG, QMetaObject, QObject, QUrl
from PyQt6.QtGui import QColor
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

    def test_standard_button_tab_focus_uses_accent_ring_and_text_underline(self) -> None:
        harness = self._create("tests/qml/ButtonFocusHarness.qml")
        cancel_label = harness.findChild(QObject, "testCancelChangesButtonLabel")

        self.assertIsNotNone(cancel_label)
        self.assertFalse(harness.property("cancelVisualFocus"))
        self.assertEqual(harness.property("cancelBorderWidth"), 0)

        QMetaObject.invokeMethod(harness, "focusCancelWithTabReason")
        self.app.processEvents()

        self.assertTrue(harness.property("cancelVisualFocus"))
        self.assertGreater(harness.property("cancelBorderWidth"), 0)
        self.assertEqual(harness.property("cancelBorderColor"), harness.property("accentColor"))
        self.assertFalse(cancel_label.property("font").bold())
        self.assertTrue(cancel_label.property("font").underline())
        self.assertEqual(self.warnings, [])

    def test_password_field_masks_by_default_and_preserves_cursor_on_toggle(self) -> None:
        harness = self._create("tests/qml/PasswordFieldHarness.qml")
        reveal_button = harness.findChild(QObject, "passwordRevealButton")

        self.assertIsNotNone(reveal_button)
        self.assertFalse(harness.property("passwordVisible"))
        self.assertNotEqual(harness.property("displayText"), "secret-value")
        self.assertEqual(harness.property("cursorPosition"), 4)
        self.assertTrue(harness.property("inputHasFocus"))
        self.assertTrue(str(reveal_button.property("iconSource")).endswith("/resources/general/eye.svg"))

        QMetaObject.invokeMethod(harness, "togglePassword")
        self.app.processEvents()

        self.assertTrue(harness.property("passwordVisible"))
        self.assertEqual(harness.property("displayText"), "secret-value")
        self.assertEqual(harness.property("cursorPosition"), 4)
        self.assertTrue(harness.property("inputHasFocus"))
        self.assertTrue(
            str(reveal_button.property("iconSource")).endswith("/resources/general/eye-closed.svg")
        )

        QMetaObject.invokeMethod(harness, "togglePassword")
        self.app.processEvents()
        self.assertFalse(harness.property("passwordVisible"))
        self.assertNotEqual(harness.property("displayText"), "secret-value")
        self.assertEqual(self.warnings, [])

    def test_selection_tokens_keep_text_contrast_across_themes_and_accents(self) -> None:
        harness = self._create("tests/qml/SelectionThemeHarness.qml")

        def relative_luminance(color: QColor) -> float:
            channels = (color.redF(), color.greenF(), color.blueF())
            linear = [
                channel / 12.92
                if channel <= 0.04045
                else ((channel + 0.055) / 1.055) ** 2.4
                for channel in channels
            ]
            return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]

        def contrast_ratio(first: QColor, second: QColor) -> float:
            first_luminance = relative_luminance(first)
            second_luminance = relative_luminance(second)
            return (max(first_luminance, second_luminance) + 0.05) / (
                min(first_luminance, second_luminance) + 0.05
            )

        for theme_mode in (1, 2, 3, 4):
            for custom_accent in ("#000000", "#FFFFFF", "#FFD400", "#777777", "#356FD6"):
                with self.subTest(theme_mode=theme_mode, accent=custom_accent):
                    QMetaObject.invokeMethod(
                        harness,
                        "setSelectionContext",
                        Q_ARG("QVariant", theme_mode),
                        Q_ARG("QVariant", custom_accent),
                    )
                    self.app.processEvents()
                    background = harness.property("selectionBackground")
                    foreground = harness.property("selectionForeground")
                    self.assertIsInstance(background, QColor)
                    self.assertIsInstance(foreground, QColor)
                    self.assertGreaterEqual(contrast_ratio(background, foreground), 4.5)

        self.assertEqual(self.warnings, [])

    def test_activity_bar_reserved_items_stay_visible_and_inert(self) -> None:
        activity_bar = self._create("UI/qml/layout/ActivityBar.qml")
        activity_bar.setProperty("width", 48)
        activity_bar.setProperty("height", 480)
        self.app.processEvents()

        for object_name in (
            "consoleSerialActivityItem",
            "logsActivityItem",
            "sftpActivityItem",
        ):
            with self.subTest(item=object_name):
                item = activity_bar.findChild(QObject, object_name)
                self.assertIsNotNone(item)
                self.assertTrue(item.property("visible"))
                self.assertFalse(item.property("enabled"))
                self.assertFalse(item.property("isActive"))
                self.assertAlmostEqual(item.property("opacity"), 0.35)
                self.assertEqual(item.parent().objectName(), "activityTopGroup")

        database_item = activity_bar.findChild(QObject, "databaseActivityItem")
        settings_item = activity_bar.findChild(QObject, "settingsActivityItem")
        self.assertIsNotNone(database_item)
        self.assertIsNotNone(settings_item)
        self.assertEqual(database_item.parent().objectName(), "activityBottomGroup")
        self.assertEqual(settings_item.parent().objectName(), "activityBottomGroup")
        self.assertLess(database_item.property("y"), settings_item.property("y"))

        self.assertEqual(activity_bar.property("activeIndex"), 0)
        self.assertEqual(activity_bar.property("appMode"), "devices")
        self.assertEqual(self.warnings, [])

    def test_notification_center_copy_layout_and_dnd_controls(self) -> None:
        copy_button = self._create("UI/components/standard/CopyButton.qml")
        message = "Device R1 configuration completed"
        copy_button.setProperty("textToCopy", message)
        QApplication.clipboard().clear()

        QMetaObject.invokeMethod(copy_button, "copyText")
        self.app.processEvents()

        self.assertEqual(QApplication.clipboard().text(), message)
        self.assertTrue(copy_button.property("copied"))

        notification_harness = self._create("tests/qml/NotificationCopyHarness.qml")
        toast_manager = notification_harness.findChild(QObject, "testToastManager")
        notification_center = notification_harness.findChild(QObject, "testNotificationCenter")
        dnd_button = notification_harness.findChild(QObject, "notificationDndButton")
        dnd_icon = notification_harness.findChild(QObject, "notificationDndButtonIcon")
        header_text = notification_harness.findChild(QObject, "notificationHeaderText")

        self.assertIsNotNone(toast_manager)
        self.assertIsNotNone(notification_center)
        self.assertIsNotNone(dnd_button)
        self.assertIsNotNone(dnd_icon)
        self.assertIsNotNone(header_text)
        self.assertIsNone(notification_harness.findChild(QObject, "toastCopyButton"))

        icon_parent = dnd_icon.parent()
        self.assertAlmostEqual(
            dnd_icon.property("x") + dnd_icon.property("width") / 2,
            icon_parent.property("width") / 2,
        )
        self.assertAlmostEqual(
            dnd_icon.property("y") + dnd_icon.property("height") / 2,
            icon_parent.property("height") / 2,
        )

        populated_height = notification_harness.property("notificationPanelHeight")
        self.assertGreater(populated_height, 96)
        self.assertLessEqual(populated_height, 400)

        QMetaObject.invokeMethod(notification_harness, "clearHistory")
        self.app.processEvents()
        self.assertEqual(notification_harness.property("notificationPanelHeight"), 44)
        self.assertEqual(header_text.property("text"), "No New Notifications")
        self.assertIsNone(notification_harness.findChild(QObject, "emptyNotificationText"))

        for index in range(12):
            QMetaObject.invokeMethod(
                notification_harness,
                "addHistory",
                Q_ARG("QVariant", f"Notification {index + 1} with enough content to verify scrolling."),
                Q_ARG("QVariant", "warning" if index % 3 == 0 else "info"),
            )
        self.app.processEvents()
        self.assertEqual(notification_center.property("notificationCount"), 12)
        self.assertEqual(header_text.property("text"), "Notifications")
        self.assertEqual(notification_harness.property("notificationPanelHeight"), 400)
        self.assertTrue(notification_center.property("hasScrollableOverflow"))

        QMetaObject.invokeMethod(dnd_button, "clicked")
        self.app.processEvents()
        self.assertTrue(notification_harness.property("doNotDisturb"))
        self.assertFalse(dnd_button.property("checked"))
        self.assertFalse(dnd_button.property("_selected"))

        notification_harness.setProperty("visible", False)
        self.assertEqual(self.warnings, [])

    def test_status_bar_dnd_indicator_blinks_only_for_unread(self) -> None:
        status_bar = self._create("UI/qml/layout/StatusBar.qml")
        notification_button = status_bar.findChild(QObject, "statusBarNotificationButton")
        self.assertIsNotNone(notification_button)

        status_bar.setProperty("isDND", True)
        status_bar.setProperty("unreadCount", 1)
        status_bar.setProperty("isNotificationOpen", False)
        self.app.processEvents()

        self.assertTrue(status_bar.property("notificationShouldBlink"))
        self.assertTrue(str(notification_button.property("iconSource")).endswith("/resources/statusbar/dnd.svg"))

        status_bar.setProperty("isNotificationOpen", True)
        self.app.processEvents()
        self.assertFalse(status_bar.property("notificationShouldBlink"))
        self.assertEqual(self.warnings, [])

    def test_action_icon_dialogs_and_menu_load(self) -> None:
        for relative_path in (
            "UI/qml/sidebar/new_device/NewDevice.qml",
            "UI/qml/sidebar/new_device/BatchNewDevice.qml",
            "UI/qml/sidebar/devices/DeviceContextMenu.qml",
            "UI/qml/shared/ViewPushDialog.qml",
        ):
            with self.subTest(qml=relative_path):
                component = self._create(relative_path)
                component.setProperty("visible", False)
                self.app.processEvents()
        self.assertEqual(self.warnings, [])

    def test_main_module_loads(self) -> None:
        self.engine.loadFromModule("UI", "Main")
        self.app.processEvents()
        self.assertEqual(len(self.engine.rootObjects()), 1)
        self.assertEqual(self.warnings, [])

    def test_main_dnd_archives_notification_without_showing_toast(self) -> None:
        self.engine.loadFromModule("UI", "Main")
        self.app.processEvents()
        root = self.engine.rootObjects()[0]
        toast_manager = root.findChild(QObject, "mainToastManager")
        notification_center = root.findChild(QObject, "notificationCenter")

        self.assertIsNotNone(toast_manager)
        self.assertIsNotNone(notification_center)
        initial_count = root.property("notificationHistoryCount")

        QMetaObject.invokeMethod(root, "setDoNotDisturb", Q_ARG("QVariant", True))
        QMetaObject.invokeMethod(
            root,
            "recordNotification",
            Q_ARG("QVariant", "DND archived notification"),
            Q_ARG("QVariant", "warning"),
            Q_ARG("QVariant", True),
        )
        self.app.processEvents()

        self.assertTrue(root.property("isDoNotDisturb"))
        self.assertEqual(toast_manager.property("toastCount"), 0)
        self.assertEqual(root.property("notificationHistoryCount"), initial_count + 1)
        self.assertEqual(root.property("unreadNotifications"), 1)

        notification_center.setProperty("visible", True)
        self.app.processEvents()
        self.assertEqual(
            notification_center.property("notificationCount"),
            root.property("notificationHistoryCount"),
        )
        self.assertEqual(root.property("unreadNotifications"), 0)
        self.assertEqual(self.warnings, [])

    def test_main_notification_toggle_clears_and_deduplicates_toasts(self) -> None:
        self.engine.loadFromModule("UI", "Main")
        self.app.processEvents()
        root = self.engine.rootObjects()[0]
        toast_manager = root.findChild(QObject, "mainToastManager")
        notification_center = root.findChild(QObject, "notificationCenter")
        notification_button = root.findChild(QObject, "statusBarNotificationButton")

        self.assertIsNotNone(toast_manager)
        self.assertIsNotNone(notification_center)
        self.assertIsNotNone(notification_button)
        initial_history_count = root.property("notificationHistoryCount")

        for _ in range(2):
            QMetaObject.invokeMethod(
                root,
                "recordNotification",
                Q_ARG("QVariant", "Added a new EIGRP process card."),
                Q_ARG("QVariant", "info"),
                Q_ARG("QVariant", True),
            )
        self.app.processEvents()

        # Duplicate events remain auditable in history but share one popup.
        self.assertEqual(root.property("notificationHistoryCount"), initial_history_count + 2)
        self.assertEqual(toast_manager.property("toastCount"), 1)

        # The short suppression window still applies if the first popup was
        # dismissed before the immediately repeated event arrives.
        QMetaObject.invokeMethod(toast_manager, "clearToasts")
        QMetaObject.invokeMethod(
            root,
            "recordNotification",
            Q_ARG("QVariant", "Added a new EIGRP process card."),
            Q_ARG("QVariant", "info"),
            Q_ARG("QVariant", True),
        )
        self.app.processEvents()
        self.assertEqual(root.property("notificationHistoryCount"), initial_history_count + 3)
        self.assertEqual(toast_manager.property("toastCount"), 0)

        QMetaObject.invokeMethod(
            root,
            "recordNotification",
            Q_ARG("QVariant", "A distinct notification"),
            Q_ARG("QVariant", "info"),
            Q_ARG("QVariant", True),
        )
        self.app.processEvents()
        self.assertEqual(toast_manager.property("toastCount"), 1)

        QMetaObject.invokeMethod(notification_button, "clicked")
        self.app.processEvents()
        self.assertTrue(notification_center.property("visible"))
        self.assertEqual(toast_manager.property("toastCount"), 0)

        # Notifications arriving while the Center is open go to history only.
        QMetaObject.invokeMethod(
            root,
            "recordNotification",
            Q_ARG("QVariant", "Notification while Center is open"),
            Q_ARG("QVariant", "warning"),
            Q_ARG("QVariant", True),
        )
        self.app.processEvents()
        self.assertEqual(root.property("notificationHistoryCount"), initial_history_count + 5)
        self.assertEqual(toast_manager.property("toastCount"), 0)

        QMetaObject.invokeMethod(notification_button, "clicked")
        self.app.processEvents()
        self.assertFalse(notification_center.property("visible"))
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
