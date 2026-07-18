from __future__ import annotations

import os
import tempfile
import time
import unittest
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

import main as _main_bootstrap  # noqa: F401 - configures PyQt DLL/QML paths
from PyQt6.QtCore import Q_ARG, QCoreApplication, QMetaObject, QObject, QPoint, QPointF, Qt, QUrl
from PyQt6.QtGui import QColor, QWheelEvent
from PyQt6.QtQml import QQmlApplicationEngine, QQmlComponent, QQmlEngine, QQmlExpression
from PyQt6.QtTest import QTest
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
from sftp_client import SftpController


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

    def _create_with_properties(self, relative_path: str, properties: dict):
        component = QQmlComponent(
            self.engine,
            QUrl.fromLocalFile(str((APP_DIR / relative_path).resolve())),
        )
        instance = component.createWithInitialProperties(properties)
        self.app.processEvents()
        self.assertTrue(instance, [error.toString() for error in component.errors()])
        return instance

    def _wait_until(self, predicate, timeout_ms: int = 5000) -> bool:
        deadline = time.perf_counter() + timeout_ms / 1000
        while time.perf_counter() < deadline:
            self.app.processEvents()
            if predicate():
                return True
            QTest.qWait(5)
        self.app.processEvents()
        return bool(predicate())

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

    def test_config_text_viewer_search_zoom_and_line_selection(self) -> None:
        viewer = self._create("UI/components/standard/ConfigTextViewer.qml")
        viewer.setProperty("width", 900)
        viewer.setProperty("height", 560)
        viewer.setProperty("highlightingChunkLineCount", 1)
        viewer.setProperty(
            "text",
            "interface GigabitEthernet0/0\n ip address 10.0.0.1 255.255.255.0\n permit inside 2026-07-14 12:30:00\ninterface Loopback0",
        )
        QMetaObject.invokeMethod(viewer, "startHighlighting")
        QMetaObject.invokeMethod(viewer, "processHighlightChunk")
        self.assertTrue(viewer.property("highlightingInProgress"))
        self.assertFalse(viewer.property("highlightingReady"))
        for _ in range(8):
            if not viewer.property("highlightingInProgress"):
                break
            QMetaObject.invokeMethod(viewer, "processHighlightChunk")
        self.app.processEvents()

        self.assertTrue(viewer.property("highlightingReady"))
        self.assertTrue(viewer.property("syntaxHighlightingActive"))
        self.assertIn("<span", viewer.property("highlightedText"))
        self.assertIn("GigabitEthernet0/0", viewer.property("highlightedText"))
        self.assertIn("font-weight:600", viewer.property("highlightedText"))
        light_highlighted_text = viewer.property("highlightedText")

        theme_harness = self._create("tests/qml/SelectionThemeHarness.qml")
        QMetaObject.invokeMethod(
            theme_harness,
            "setSelectionContext",
            Q_ARG("QVariant", 2),
            Q_ARG("QVariant", "#356FD6"),
        )
        QMetaObject.invokeMethod(viewer, "startHighlighting")
        for _ in range(8):
            if not viewer.property("highlightingInProgress"):
                break
            QMetaObject.invokeMethod(viewer, "processHighlightChunk")
        self.app.processEvents()
        self.assertNotEqual(viewer.property("highlightedText"), light_highlighted_text)

        viewer.setProperty("searchText", "interface")
        QMetaObject.invokeMethod(viewer, "runSearchNow")
        self.app.processEvents()

        self.assertEqual(viewer.property("lineCount"), 4)
        self.assertEqual(viewer.property("matchCount"), 2)
        self.assertEqual(viewer.property("currentMatchIndex"), -1)

        search_field = viewer.findChild(QObject, "configViewerSearchField")
        content = viewer.findChild(QObject, "configViewerContent")
        bottom_toolbar = viewer.findChild(QObject, "configViewerBottomToolbar")
        zoom_out_button = viewer.findChild(QObject, "configViewerZoomOutButton")
        zoom_in_button = viewer.findChild(QObject, "configViewerZoomInButton")
        reset_zoom_button = viewer.findChild(QObject, "configViewerResetZoomButton")
        line_numbers = viewer.findChild(QObject, "configViewerLineNumbers")
        text_area = viewer.findChild(QObject, "configViewerTextArea")
        self.assertIsNotNone(search_field)
        self.assertIsNotNone(content)
        self.assertIsNotNone(bottom_toolbar)
        self.assertIsNotNone(zoom_out_button)
        self.assertIsNotNone(zoom_in_button)
        self.assertIsNotNone(reset_zoom_button)
        self.assertIsNotNone(line_numbers)
        self.assertIsNotNone(text_area)
        self.assertGreater(bottom_toolbar.property("y"), content.property("y"))
        self.assertAlmostEqual(
            line_numbers.property("bottomPadding"),
            text_area.property("bottomPadding"),
            delta=0.01,
        )
        second_line_position = viewer.property("text").index("\n") + 1
        gutter_second_line_position = viewer.property("lineNumberText").index("\n") + 1
        text_line_advance_expression = QQmlExpression(
            QQmlEngine.contextForObject(text_area),
            text_area,
            f"positionToRectangle({second_line_position}).y - positionToRectangle(0).y",
        )
        gutter_line_advance_expression = QQmlExpression(
            QQmlEngine.contextForObject(line_numbers),
            line_numbers,
            f"positionToRectangle({gutter_second_line_position}).y - positionToRectangle(0).y",
        )
        text_first_line_expression = QQmlExpression(
            QQmlEngine.contextForObject(text_area),
            text_area,
            "positionToRectangle(0).y",
        )
        gutter_first_line_expression = QQmlExpression(
            QQmlEngine.contextForObject(line_numbers),
            line_numbers,
            "positionToRectangle(0).y",
        )
        self.assertAlmostEqual(
            text_first_line_expression.evaluate()[0],
            gutter_first_line_expression.evaluate()[0],
            delta=0.01,
        )
        self.assertAlmostEqual(
            text_line_advance_expression.evaluate()[0],
            gutter_line_advance_expression.evaluate()[0],
            delta=0.01,
        )

        QMetaObject.invokeMethod(viewer, "focusSearch")
        self.app.processEvents()

        focus_harness = self._create("tests/qml/ConfigTextViewerHarness.qml")
        focus_harness.setProperty("configText", viewer.property("text"))
        QTest.qWait(100)
        self.app.processEvents()
        self.assertTrue(focus_harness.property("highlightingReady"))
        self.assertTrue(focus_harness.property("syntaxHighlightingActive"))
        self.assertIn("<span", focus_harness.property("highlightedText"))
        QTest.keyClick(
            focus_harness,
            Qt.Key.Key_F,
            Qt.KeyboardModifier.ControlModifier,
        )
        self.app.processEvents()
        self.assertTrue(focus_harness.property("searchHasFocus"))

        # Enter must compute fresh matches synchronously even when the 180 ms
        # typing debounce has not fired yet. Shift+Enter navigates backwards.
        for character in "interface":
            QTest.keyClick(
                focus_harness,
                getattr(Qt.Key, f"Key_{character.upper()}"),
            )
        QTest.keyClick(focus_harness, Qt.Key.Key_Return)
        self.app.processEvents()
        self.assertEqual(focus_harness.property("matchCount"), 2)
        self.assertEqual(focus_harness.property("currentMatchIndex"), 0)
        QTest.keyClick(focus_harness, Qt.Key.Key_Return)
        self.assertEqual(focus_harness.property("currentMatchIndex"), 1)
        QTest.keyClick(
            focus_harness,
            Qt.Key.Key_Return,
            Qt.KeyboardModifier.ShiftModifier,
        )
        self.assertEqual(focus_harness.property("currentMatchIndex"), 0)

        wheel_font_size = focus_harness.property("fontPixelSize")
        wheel_event = QWheelEvent(
            QPointF(450, 250),
            QPointF(450, 250),
            QPoint(0, 0),
            QPoint(0, 120),
            Qt.MouseButton.NoButton,
            Qt.KeyboardModifier.ControlModifier,
            Qt.ScrollPhase.ScrollUpdate,
            False,
        )
        QCoreApplication.sendEvent(focus_harness, wheel_event)
        self.app.processEvents()
        self.assertEqual(focus_harness.property("fontPixelSize"), wheel_font_size + 1)

        focus_harness.setProperty(
            "configText",
            "\n".join(f"interface Loopback{index}" for index in range(100)),
        )
        QTest.qWait(50)
        self.app.processEvents()
        line_height = focus_harness.property("codeLineHeight")
        self.assertGreater(line_height, 0)
        self.assertTrue(
            self._wait_until(
                lambda: focus_harness.property("maximumScrollY") >= line_height * 2,
                timeout_ms=2000,
            )
        )

        QMetaObject.invokeMethod(
            focus_harness,
            "setScrollContentY",
            Q_ARG("QVariant", line_height * 2 + line_height * 0.4),
        )
        self.app.processEvents()
        self.assertAlmostEqual(
            focus_harness.property("scrollContentY"),
            line_height * 2,
            delta=0.01,
        )

        line_scroll_event = QWheelEvent(
            QPointF(450, 250),
            QPointF(450, 250),
            QPoint(0, 0),
            QPoint(0, -120),
            Qt.MouseButton.NoButton,
            Qt.KeyboardModifier.NoModifier,
            Qt.ScrollPhase.ScrollUpdate,
            False,
        )
        QCoreApplication.sendEvent(focus_harness, line_scroll_event)
        self.app.processEvents()
        self.assertAlmostEqual(
            focus_harness.property("scrollContentY"),
            line_height * 5,
            delta=0.01,
        )
        focus_harness.setProperty("visible", False)

        QMetaObject.invokeMethod(search_field, "accepted")
        self.app.processEvents()
        self.assertEqual(viewer.property("currentMatchIndex"), 0)
        self.assertEqual(viewer.property("selectedText"), "interface")

        QMetaObject.invokeMethod(search_field, "accepted")
        QMetaObject.invokeMethod(search_field, "reverseAccepted")
        self.app.processEvents()
        self.assertEqual(viewer.property("currentMatchIndex"), 0)

        default_font_size = viewer.property("defaultFontPixelSize")
        self.assertEqual(default_font_size, 13)
        QMetaObject.invokeMethod(zoom_in_button, "clicked")
        self.assertEqual(viewer.property("fontPixelSize"), default_font_size + 1)
        QMetaObject.invokeMethod(zoom_out_button, "clicked")
        self.assertEqual(viewer.property("fontPixelSize"), default_font_size)
        QMetaObject.invokeMethod(zoom_in_button, "clicked")
        QMetaObject.invokeMethod(reset_zoom_button, "clicked")
        self.assertEqual(viewer.property("fontPixelSize"), default_font_size)
        for _ in range(50):
            QMetaObject.invokeMethod(zoom_in_button, "clicked")
        self.app.processEvents()
        self.assertEqual(viewer.property("fontPixelSize"), 40)
        self.assertEqual(
            len(viewer.property("lineNumberText").splitlines()),
            viewer.property("lineCount"),
        )
        self.assertAlmostEqual(
            text_first_line_expression.evaluate()[0],
            gutter_first_line_expression.evaluate()[0],
            delta=0.01,
        )
        self.assertAlmostEqual(
            text_line_advance_expression.evaluate()[0],
            gutter_line_advance_expression.evaluate()[0],
            delta=0.01,
        )
        QMetaObject.invokeMethod(reset_zoom_button, "clicked")

        QApplication.clipboard().clear()
        QMetaObject.invokeMethod(viewer, "copyAll")
        self.app.processEvents()
        self.assertEqual(QApplication.clipboard().text(), viewer.property("text"))
        self.assertTrue(viewer.property("copyFeedbackVisible"))

        QMetaObject.invokeMethod(viewer, "selectLine", Q_ARG("QVariant", 1))
        self.app.processEvents()
        self.assertEqual(
            viewer.property("selectedText"),
            " ip address 10.0.0.1 255.255.255.0",
        )

        viewer.setProperty("syntaxHighlightCharacterLimit", 8)
        QMetaObject.invokeMethod(viewer, "startHighlighting")
        self.assertTrue(viewer.property("highlightingSkippedForLargeText"))
        self.assertFalse(viewer.property("syntaxHighlightingActive"))
        QMetaObject.invokeMethod(
            theme_harness,
            "setSelectionContext",
            Q_ARG("QVariant", 1),
            Q_ARG("QVariant", "#356FD6"),
        )
        self.assertEqual(self.warnings, [])

    def test_config_text_viewer_uses_distinct_semantic_highlight_colors(self) -> None:
        viewer = self._create("UI/components/standard/ConfigTextViewer.qml")
        viewer.setProperty("width", 900)
        viewer.setProperty("height", 560)
        viewer.setProperty(
            "text",
            "\n".join(
                (
                    "ip address 192.168.1.1 255.255.255.0",
                    "network 10.0.0.0 0.0.0.255 area 1",
                    "route 10.0.0.0/24",
                    "interface GigabitEthernet0/0",
                    "metric 42 yes 2026-07-14 12:30:00",
                    "permit deny inside outside",
                    "! comment",
                )
            ),
        )
        QMetaObject.invokeMethod(viewer, "startHighlighting")
        for _ in range(8):
            if not viewer.property("highlightingInProgress"):
                break
            QMetaObject.invokeMethod(viewer, "processHighlightChunk")
        self.app.processEvents()

        palette_properties = (
            "syntaxIpAddressColor",
            "syntaxPrefixColor",
            "syntaxMaskColor",
            "syntaxWildcardColor",
            "syntaxInterfaceColor",
            "syntaxNumberColor",
            "syntaxBooleanColor",
            "syntaxDateTimeColor",
            "syntaxPermitColor",
            "syntaxDenyColor",
            "syntaxInsideColor",
            "syntaxOutsideColor",
            "syntaxCommentColor",
        )
        palette = [viewer.property(name).name().lower() for name in palette_properties]
        highlighted_text = viewer.property("highlightedText").lower()
        self.assertEqual(len(set(palette)), len(palette))
        for color in palette:
            with self.subTest(color=color):
                self.assertIn(f"color:{color}", highlighted_text)

        viewer.setProperty("text", "interface Loopback0\n")
        QMetaObject.invokeMethod(viewer, "startHighlighting")
        for _ in range(4):
            if not viewer.property("highlightingInProgress"):
                break
            QMetaObject.invokeMethod(viewer, "processHighlightChunk")
        self.app.processEvents()
        self.assertEqual(viewer.property("lineCount"), 2)
        self.assertIn("&#8203;", viewer.property("highlightedText"))
        self.assertEqual(self.warnings, [])

    def test_config_text_viewer_highlights_ten_thousand_lines_in_chunks(self) -> None:
        viewer = self._create("UI/components/standard/ConfigTextViewer.qml")
        viewer.setProperty("width", 900)
        viewer.setProperty("height", 560)
        viewer.setProperty("highlightingChunkLineCount", 250)
        large_config = "\n".join(
            f"interface GigabitEthernet0/{index} ip address 10.0.0.1 255.255.255.0 permit inside"
            for index in range(10_000)
        )

        started_at = time.perf_counter()
        viewer.setProperty("text", large_config)
        QMetaObject.invokeMethod(viewer, "startHighlighting")
        self.assertTrue(viewer.property("highlightingInProgress"))
        for _ in range(50):
            if not viewer.property("highlightingInProgress"):
                break
            QMetaObject.invokeMethod(viewer, "processHighlightChunk")
        elapsed = time.perf_counter() - started_at

        self.assertFalse(viewer.property("highlightingInProgress"))
        self.assertTrue(viewer.property("highlightingReady"))
        self.assertEqual(viewer.property("lineCount"), 10_000)
        self.assertLess(elapsed, 8.0)
        self.assertEqual(self.warnings, [])

    def test_information_reload_coalesces_activation_and_running_command(self) -> None:
        information = self._create("UI/qml/content/InformationView.qml")
        information.setProperty("width", 900)
        information.setProperty("height", 560)
        information.setProperty("currentHostIp", "192.0.2.10")
        self.app.processEvents()

        reload_button = information.findChild(QObject, "informationReloadButton")
        copy_button = information.findChild(QObject, "informationCopyAllButton")
        self.assertIsNotNone(reload_button)
        self.assertIsNotNone(copy_button)
        self.assertEqual(copy_button.property("y"), reload_button.property("y"))
        self.assertEqual(copy_button.property("height"), reload_button.property("height"))

        first_started_at = information.property("lastLoadStartedAt")
        self.assertGreater(first_started_at, 0)
        QMetaObject.invokeMethod(
            information,
            "reloadData",
            Q_ARG("QVariant", "activation"),
            Q_ARG("QVariant", False),
        )
        self.app.processEvents()
        self.assertEqual(information.property("lastLoadStartedAt"), first_started_at)

        information.setProperty("isLoadingLive", True)
        information.setProperty("loadingHost", "192.0.2.10")
        information.setProperty("lastLoadStartedAt", 0)
        QMetaObject.invokeMethod(
            information,
            "reloadData",
            Q_ARG("QVariant", "activation"),
            Q_ARG("QVariant", False),
        )
        self.assertEqual(information.property("lastLoadStartedAt"), 0)
        self.assertFalse(information.property("reloadQueued"))

        information.setProperty("currentHostIp", "192.0.2.11")
        self.app.processEvents()
        self.assertTrue(information.property("reloadQueued"))
        information.setProperty("isLoadingLive", False)
        information.setProperty("loadingHost", "")
        self.assertEqual(self.warnings, [])

    def test_activity_bar_console_is_reserved_and_sftp_is_active(self) -> None:
        activity_bar = self._create("UI/qml/layout/ActivityBar.qml")
        activity_bar.setProperty("width", 48)
        activity_bar.setProperty("height", 480)
        self.app.processEvents()

        console_item = activity_bar.findChild(QObject, "consoleSerialActivityItem")
        self.assertIsNotNone(console_item)
        self.assertTrue(console_item.property("visible"))
        self.assertFalse(console_item.property("enabled"))
        self.assertFalse(console_item.property("isActive"))
        self.assertAlmostEqual(console_item.property("opacity"), 0.35)
        self.assertEqual(console_item.parent().objectName(), "activityTopGroup")

        sftp_item = activity_bar.findChild(QObject, "sftpActivityItem")
        self.assertIsNotNone(sftp_item)
        self.assertTrue(sftp_item.property("visible"))
        self.assertTrue(sftp_item.property("enabled"))
        self.assertAlmostEqual(sftp_item.property("opacity"), 1.0)
        self.assertEqual(sftp_item.parent().objectName(), "activityTopGroup")

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

    def test_sftp_workspace_loads_with_serialized_backend(self) -> None:
        controller = SftpController()
        self.engine.rootContext().setContextProperty("sftpController", controller)
        try:
            workspace = self._create("UI/qml/sftp/SftpView.qml")
            workspace.setProperty("width", 1100)
            workspace.setProperty("height", 760)
            self.assertTrue(
                self._wait_until(lambda: not controller.busy, timeout_ms=5000)
            )
            self.assertIsNotNone(workspace.findChild(QObject, "sftpLocalPanel"))
            self.assertIsNotNone(workspace.findChild(QObject, "sftpRemotePanel"))
            self.assertEqual(controller._pool.maxThreadCount(), 1)
            self.assertEqual(self.warnings, [])
        finally:
            controller.shutdown()

    def test_external_tool_catalog_loads_as_a_read_only_vendor_catalog(self) -> None:
        catalog = self._create(
            "UI/qml/content/ExternalToolCatalogSettings.qml"
        )
        catalog.setProperty("width", 1100)
        catalog.setProperty("height", 760)
        self.app.processEvents()

        self.assertEqual(catalog.property("objectName"), "externalToolCatalogSettings")
        self.assertGreater(len(catalog.property("catalog")), 0)
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

    def test_command_registry_dispatches_only_available_context(self) -> None:
        harness = self._create("tests/qml/CommandRegistryHarness.qml")

        for key, counter in (
            (Qt.Key.Key_R, "reloadCount"),
            (Qt.Key.Key_1, "devicesCount"),
            (Qt.Key.Key_2, "databaseCount"),
            (Qt.Key.Key_3, "settingsCount"),
        ):
            QTest.keyClick(harness, key, Qt.KeyboardModifier.ControlModifier)
            self.app.processEvents()
            self.assertEqual(harness.property(counter), 1)

        harness.setProperty("inputFocusActive", True)
        QTest.keyClick(harness, Qt.Key.Key_R, Qt.KeyboardModifier.ControlModifier)
        QTest.keyClick(harness, Qt.Key.Key_1, Qt.KeyboardModifier.ControlModifier)
        self.app.processEvents()
        self.assertEqual(harness.property("reloadCount"), 1)
        self.assertEqual(harness.property("devicesCount"), 1)

        harness.setProperty("inputFocusActive", False)
        harness.setProperty("reloadAvailable", False)
        harness.setProperty("databaseAvailable", False)
        QTest.keyClick(harness, Qt.Key.Key_R, Qt.KeyboardModifier.ControlModifier)
        QTest.keyClick(harness, Qt.Key.Key_2, Qt.KeyboardModifier.ControlModifier)
        self.app.processEvents()
        self.assertEqual(harness.property("reloadCount"), 1)
        self.assertEqual(harness.property("databaseCount"), 1)
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

        for feature_index, object_name in (
            (0, "loadedRoutingView"),
            (2, "loadedDhcpView"),
            (3, "loadedAclView"),
            (5, "loadedNatView"),
        ):
            content.setProperty("activeTextFeature", feature_index)
            self.assertTrue(content.property("activeViewLoading"))
            self.assertTrue(self._wait_until(lambda name=object_name: content.findChild(QObject, name) is not None))
            self.assertTrue(self._wait_until(lambda: not content.property("activeViewLoading")))

        self.assertIsNotNone(content.findChild(QObject, "dhcpLoader"))
        self.assertIsNotNone(content.findChild(QObject, "loadedDhcpView"))

        content.setProperty("activeTextFeature", -1)
        content.setProperty("currentHostIp", "192.0.2.10")
        for feature_index, object_name in ((2, "loadedInterfaceView"), (0, "loadedInformationView")):
            content.setProperty("activeMainFeature", feature_index)
            self.assertTrue(content.property("activeViewLoading"))
            self.assertTrue(self._wait_until(lambda name=object_name: content.findChild(QObject, name) is not None))

        self.assertIsNotNone(content.findChild(QObject, "informationLoader"))
        loaded_information = content.findChild(QObject, "loadedInformationView")
        self.assertIsNotNone(loaded_information)
        self.assertTrue(self._wait_until(lambda: content.property("effectiveHostIp") == "192.0.2.10"))
        self.assertEqual(content.property("informationHostIp"), "192.0.2.10")
        for inactive_host_property in (
            "routingHostIp",
            "dhcpHostIp",
            "aclHostIp",
            "natHostIp",
        ):
            with self.subTest(inactive_host=inactive_host_property):
                self.assertEqual(content.property(inactive_host_property), "")
        self.assertTrue(self._wait_until(lambda: content.property("reloadCommandEnabled")))
        self.assertTrue(content.property("reloadCommandEnabled"))
        QMetaObject.invokeMethod(content, "triggerReloadCommand")
        self.app.processEvents()
        self.assertEqual(loaded_information.property("lastReloadReason"), "shortcut")

        content.setProperty("deviceRole", "sw2")
        content.setProperty("activeMainFeature", -1)
        content.setProperty("activeTextFeature", 17)
        self.assertTrue(
            self._wait_until(
                lambda: content.findChild(QObject, "loadedSwitchWorkspace") is not None
            )
        )
        switch_sub_bar = content.findChild(QObject, "switchSubFeatureBar")
        self.assertIsNotNone(switch_sub_bar)
        self.assertEqual(switch_sub_bar.property("activeTab"), "Port Security")
        self.assertEqual(
            switch_sub_bar.property("tabs").toVariant(),
            ["Port Security", "Storm Control"],
        )

        content.setProperty("activeTextFeature", 15)
        self.assertTrue(
            self._wait_until(
                lambda: switch_sub_bar.property("activeTab") == "VLAN"
            )
        )
        self.assertFalse(switch_sub_bar.property("visible"))

        content.setProperty("appMode", "settings")
        self.assertTrue(self._wait_until(lambda: content.findChild(QObject, "loadedSettingsView") is not None))
        content.setProperty("appMode", "database")
        self.assertTrue(self._wait_until(lambda: content.findChild(QObject, "loadedDatabaseView") is not None))
        content.setProperty("appMode", "devices")
        self.app.processEvents()

        flags = (
            "routingViewLoaded",
            "dhcpViewLoaded",
            "aclViewLoaded",
            "natViewLoaded",
            "interfaceViewLoaded",
            "informationViewLoaded",
            "switchWorkspaceLoaded",
            "settingsViewLoaded",
            "databaseViewLoaded",
        )
        self.assertTrue(all(content.property(flag) for flag in flags))
        self.assertEqual(self.warnings, [])

    def test_every_switch_table_page_loads_without_qml_warnings(self) -> None:
        pages = (
            ("UI/qml/switch/interfaces/SwitchPortsPage.qml", {"host": "192.0.2.250"}),
            ("UI/qml/switch/interfaces/SviPage.qml", {"host": "192.0.2.250"}),
            ("UI/qml/switch/switching/VlanPage.qml", {"host": "192.0.2.250"}),
            (
                "UI/qml/switch/monitoring/SwitchMonitoringPage.qml",
                {"host": "192.0.2.250", "viewName": "portCounters"},
            ),
            (
                "UI/qml/switch/monitoring/SwitchMonitoringPage.qml",
                {"host": "192.0.2.250", "viewName": "macTable"},
            ),
        )
        instances = []
        for relative_path, properties in pages:
            with self.subTest(qml=relative_path, view=properties.get("viewName", "")):
                instances.append(self._create_with_properties(relative_path, properties))
        self.app.processEvents()
        self.assertEqual(self.warnings, [])

    def test_switch_configuration_pages_adapt_at_workspace_breakpoint(self) -> None:
        pages = (
            "UI/qml/switch/interfaces/SwitchPortsPage.qml",
            "UI/qml/switch/interfaces/SviPage.qml",
            "UI/qml/switch/switching/VlanPage.qml",
        )
        instances = []
        for relative_path in pages:
            with self.subTest(qml=relative_path):
                page = self._create_with_properties(
                    relative_path,
                    {"host": "192.0.2.251", "width": 1200, "height": 720},
                )
                instances.append(page)
                self.assertFalse(page.property("compactLayout"))
                page.setProperty("width", 760)
                self.app.processEvents()
                self.assertTrue(page.property("compactLayout"))
        self.assertEqual(self.warnings, [])

    def test_switch_workspace_caches_each_feature_after_first_visit(self) -> None:
        workspace = self._create_with_properties(
            "UI/qml/switch/SwitchWorkspace.qml",
            {
                "host": "192.0.2.252",
                "deviceRole": "sw2",
                "feature": "interfaces",
                "width": 1200,
                "height": 720,
            },
        )
        self.assertTrue(self._wait_until(lambda: workspace.property("switchPortsLoaded")))

        for feature, flag in (
            ("switching", "vlanLoaded"),
            ("security", "portSecurityLoaded"),
            ("monitoring", "portCountersLoaded"),
        ):
            workspace.setProperty("feature", feature)
            self.assertTrue(self._wait_until(lambda name=flag: workspace.property(name)))
            self.assertTrue(workspace.property("switchPortsLoaded"))

        self.assertTrue(self._wait_until(lambda: not workspace.property("isViewLoading")))
        self.assertEqual(self.warnings, [])

    def test_every_saved_table_form_loads_without_qml_warnings(self) -> None:
        table_forms = (
            "UI/qml/dhcp/DhcpPoolList.qml",
            "UI/qml/dhcp/DhcpExcludedForm.qml",
            "UI/qml/dhcp/DhcpHelperForm.qml",
            "UI/qml/nat/NatInterfaceForm.qml",
            "UI/qml/nat/NatStaticForm.qml",
            "UI/qml/nat/NatDynamicForm.qml",
            "UI/qml/nat/NatPatForm.qml",
            "UI/qml/nat/NatAclForm.qml",
            "UI/qml/nat/NatRouteMapForm.qml",
        )
        instances = []
        for relative_path in table_forms:
            with self.subTest(qml=relative_path):
                instances.append(self._create(relative_path))
        self.app.processEvents()
        self.assertEqual(self.warnings, [])

    def test_device_tab_spinner_replaces_icon_only_while_loading(self) -> None:
        harness = self._create("tests/qml/DeviceTabsLoadingHarness.qml")
        self.assertTrue(self._wait_until(lambda: harness.property("tabCount") == 1))
        self.assertTrue(
            self._wait_until(
                lambda: harness.findChild(QObject, "deviceTabLoadingSpinner") is not None
            )
        )

        spinner = harness.findChild(QObject, "deviceTabLoadingSpinner")
        device_icon = harness.findChild(QObject, "deviceTabDeviceIcon")
        self.assertIsNotNone(spinner)
        self.assertIsNotNone(device_icon)
        self.assertFalse(spinner.property("running"))
        self.assertTrue(device_icon.property("visible"))
        self.assertIs(spinner.parent(), device_icon.parent())
        self.assertEqual(spinner.property("width"), device_icon.property("width"))
        self.assertEqual(spinner.property("height"), device_icon.property("height"))
        self.assertAlmostEqual(
            spinner.property("x") + spinner.property("width") / 2,
            device_icon.property("x") + device_icon.property("width") / 2,
        )
        self.assertAlmostEqual(
            spinner.property("y") + spinner.property("height") / 2,
            device_icon.property("y") + device_icon.property("height") / 2,
        )

        harness.setProperty("activeContentLoading", True)
        self.assertTrue(self._wait_until(lambda: spinner.property("running")))
        self.assertTrue(spinner.property("visible"))
        self.assertFalse(device_icon.property("visible"))

        harness.setProperty("activeContentLoading", False)
        self.assertTrue(self._wait_until(lambda: not spinner.property("running")))
        self.assertFalse(spinner.property("visible"))
        self.assertTrue(device_icon.property("visible"))
        self.assertEqual(self.warnings, [])

    def test_external_tools_master_detail_loads_and_enters_new_tool_mode(self) -> None:
        settings = self._create("UI/qml/content/ExternalToolsSettings.qml")
        settings.setProperty("width", 1200)
        settings.setProperty("height", 760)
        self.assertTrue(self._wait_until(lambda: not settings.property("discoveryPending")))

        for object_name in (
            "externalToolsScanButton",
            "externalToolsNewButton",
            "externalToolsSearchField",
            "externalToolsMasterList",
            "externalToolsMainSplit",
            "externalToolAppName",
            "externalToolExecutable",
            "externalToolArguments",
            "externalToolSaveButton",
        ):
            with self.subTest(object_name=object_name):
                self.assertIsNotNone(settings.findChild(QObject, object_name))

        self.assertFalse(settings.property("compactLayout"))
        settings.setProperty("width", 800)
        self.app.processEvents()
        self.assertTrue(settings.property("compactLayout"))

        QMetaObject.invokeMethod(settings, "clearForm")
        self.app.processEvents()
        self.assertEqual(settings.property("editorMode"), "new")
        self.assertFalse(settings.property("formValid"))
        self.assertFalse(settings.findChild(QObject, "externalToolSaveButton").property("enabled"))

        tool_type = settings.findChild(QObject, "externalToolType")
        self.assertIsNotNone(tool_type)
        QMetaObject.invokeMethod(tool_type, "activated", Q_ARG(int, 0))
        self.app.processEvents()
        self.assertEqual(self.warnings, [])

    def test_rapid_feature_switch_only_incubates_final_view(self) -> None:
        content = self._create("UI/qml/content/ContentArea.qml")
        content.setProperty("tabCount", 1)

        # These changes happen in one event-loop turn. The dispatch timer must
        # coalesce them so an obsolete heavy screen does not consume CPU.
        content.setProperty("activeTextFeature", 0)  # Routing
        content.setProperty("activeTextFeature", 3)  # ACL
        content.setProperty("activeTextFeature", 2)  # DHCP

        self.assertTrue(content.property("activeViewLoading"))
        self.assertTrue(
            self._wait_until(
                lambda: content.findChild(QObject, "loadedDhcpView") is not None
            )
        )
        self.assertTrue(self._wait_until(lambda: not content.property("activeViewLoading")))
        self.assertTrue(content.property("dhcpViewLoaded"))
        self.assertFalse(content.property("routingViewLoaded"))
        self.assertFalse(content.property("aclViewLoaded"))
        self.assertIsNone(content.findChild(QObject, "loadedRoutingView"))
        self.assertIsNone(content.findChild(QObject, "loadedAclView"))
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
