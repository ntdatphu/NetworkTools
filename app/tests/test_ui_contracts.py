from __future__ import annotations

import inspect
import re
import tempfile
import unittest
from pathlib import Path

from PyQt6.QtCore import QCoreApplication, QSettings

from core.database_stubs import StubSlotsMixin
from core.runtime import WindowSettings


def _qml_component_blocks(source: str, component_name: str) -> list[str]:
    """Return balanced QML component blocks for small source-contract checks."""
    blocks: list[str] = []
    for match in re.finditer(rf"\b{re.escape(component_name)}\s*\{{", source):
        depth = 1
        cursor = match.end()
        while cursor < len(source) and depth:
            if source[cursor] == "{":
                depth += 1
            elif source[cursor] == "}":
                depth -= 1
            cursor += 1
        blocks.append(source[match.start() : cursor])
    return blocks


class WindowSettingsTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls._settings_dir = tempfile.TemporaryDirectory()
        QCoreApplication.setOrganizationName("NetworkToolsTests")
        QCoreApplication.setApplicationName("UiContractTests")
        QSettings.setDefaultFormat(QSettings.Format.IniFormat)
        QSettings.setPath(
            QSettings.Format.IniFormat,
            QSettings.Scope.UserScope,
            cls._settings_dir.name,
        )
        QSettings().clear()

    @classmethod
    def tearDownClass(cls) -> None:
        QSettings().clear()
        cls._settings_dir.cleanup()

    def test_window_state_survives_a_new_backend_instance(self) -> None:
        first = WindowSettings()
        first.saveState(120, 80, 1440, 900, False)

        restored = WindowSettings()
        self.assertEqual(restored.savedX, 120)
        self.assertEqual(restored.savedY, 80)
        self.assertEqual(restored.savedWidth, 1440)
        self.assertEqual(restored.savedHeight, 900)
        self.assertFalse(restored.isMaximized)
        self.assertFalse(restored.isFirstLaunch)


class NatQmlBridgeContractTests(unittest.TestCase):
    def test_dhcp_forms_use_staged_save_and_cancel_contract(self) -> None:
        dhcp_dir = Path(__file__).resolve().parents[1] / "UI" / "qml" / "dhcp"
        for form_name in ("DhcpPoolForm.qml", "DhcpExcludedForm.qml", "DhcpHelperForm.qml"):
            source = (dhcp_dir / form_name).read_text(encoding="utf-8")
            with self.subTest(form=form_name):
                self.assertIn("property bool hasPendingLocalChanges", source)
                self.assertIn("function saveChanges()", source)
                self.assertIn("function cancelChanges()", source)
                self.assertIn('text: "Cancel Changes"', source)
                self.assertIn('text: "Save"', source)

    def test_every_nat_form_exposes_save_cancel_and_reload_actions(self) -> None:
        nat_dir = Path(__file__).resolve().parents[1] / "UI" / "qml" / "nat"
        form_names = (
            "NatStaticForm.qml",
            "NatDynamicForm.qml",
            "NatPatForm.qml",
            "NatInterfaceForm.qml",
            "NatAclForm.qml",
            "NatRouteMapForm.qml",
        )
        for form_name in form_names:
            source = (nat_dir / form_name).read_text(encoding="utf-8")
            with self.subTest(form=form_name):
                self.assertIn('text: "Save"', source)
                self.assertIn('text: "Cancel Changes"', source)
                self.assertIn('text: "Reload"', source)
                self.assertIn("property bool hasPendingLocalChanges", source)
                self.assertIn("function saveChanges()", source)

    def test_nat_add_stubs_match_qml_positional_arity(self) -> None:
        # Expected counts include `self` and mirror the current QML form calls.
        expected_parameter_counts = {
            "addNatStaticEntry": 7,
            "addNatDynamicPool": 7,
            "addNatPatRule": 6,
            "addNatAcl": 6,
            "addNatRouteMapEntry": 7,
        }

        for method_name, expected_count in expected_parameter_counts.items():
            with self.subTest(method=method_name):
                method = getattr(StubSlotsMixin, method_name)
                self.assertEqual(len(inspect.signature(method).parameters), expected_count)


class ButtonIconContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.ui_root = Path(__file__).resolve().parents[1] / "UI"
        cls.qml_files = tuple(cls.ui_root.rglob("*.qml"))
        cls.button_blocks = [
            (path, block)
            for path in cls.qml_files
            for block in _qml_component_blocks(path.read_text(encoding="utf-8"), "StandardButton")
        ]

    def test_button_action_assets_exist(self) -> None:
        asset_dir = self.ui_root / "resources" / "general"
        for asset_name in (
            "backup.svg",
            "database-reload.svg",
            "push.svg",
            "save.svg",
        ):
            with self.subTest(asset=asset_name):
                self.assertTrue((asset_dir / asset_name).is_file())

    def test_reload_and_save_buttons_have_semantic_icons(self) -> None:
        reload_blocks = [
            block for _, block in self.button_blocks if re.search(r'text:\s*"Reload"', block)
        ]
        save_blocks = [
            block
            for _, block in self.button_blocks
            if re.search(r"^\s*text:.*\bSave(?:\s|\"|$)", block, flags=re.MULTILINE)
        ]

        self.assertEqual(len(reload_blocks), 15)
        self.assertTrue(
            all(
                "resources/general/database-reload.svg" in block
                or "resources/general/backup.svg" in block
                for block in reload_blocks
            )
        )
        self.assertGreaterEqual(len(save_blocks), 17)
        self.assertTrue(
            all("resources/general/save.svg" in block for block in save_blocks)
        )

    def test_view_push_and_running_config_backup_use_distinct_icons(self) -> None:
        view_push = (self.ui_root / "qml" / "shared" / "ViewPushButton.qml").read_text(
            encoding="utf-8"
        )
        dialog = (self.ui_root / "qml" / "shared" / "ViewPushDialog.qml").read_text(
            encoding="utf-8"
        )
        device_menu = (
            self.ui_root / "qml" / "sidebar" / "devices" / "DeviceContextMenu.qml"
        ).read_text(encoding="utf-8")

        self.assertIn("resources/general/push.svg", view_push)
        self.assertNotIn("resources/general/database-push.svg", view_push)
        self.assertIn("resources/general/database-reload.svg", dialog)
        self.assertIn("resources/general/push.svg", dialog)
        self.assertIn("resources/general/backup.svg", device_menu)

    def test_documented_standard_button_icon_coverage(self) -> None:
        buttons_with_icons = [
            block for _, block in self.button_blocks if re.search(r"\bicon\.source\s*:", block)
        ]
        self.assertEqual(len(self.button_blocks), 111)
        self.assertEqual(len(buttons_with_icons), 40)
        self.assertEqual(len(self.button_blocks) - len(buttons_with_icons), 71)

    def test_ospf_network_remove_action_uses_existing_standard_icon(self) -> None:
        source = (
            self.ui_root / "qml" / "routing" / "ospf" / "OspfNetworksSection.qml"
        ).read_text(encoding="utf-8")

        self.assertIn("RemoveIconButton {", source)
        self.assertNotIn("resources/devicetabs/close.svg", source)
        self.assertTrue((self.ui_root / "resources" / "general" / "close.svg").is_file())

    def test_add_and_new_buttons_do_not_use_add_icons(self) -> None:
        for path, block in self.button_blocks:
            with self.subTest(qml=path.name):
                self.assertNotIn("resources/sidebar/add.svg", block)
                self.assertNotIn("resources/sidebar/list-plus.svg", block)


class PasswordFieldContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.ui_root = Path(__file__).resolve().parents[1] / "UI"

    def test_shared_password_field_is_masked_and_uses_existing_eye_assets(self) -> None:
        source = (
            self.ui_root / "components" / "standard" / "StandardPasswordField.qml"
        ).read_text(encoding="utf-8")
        qmldir = (self.ui_root / "qmldir").read_text(encoding="utf-8")

        self.assertIn("StandardPasswordField 1.0", qmldir)
        self.assertIn("property bool passwordVisible: false", source)
        self.assertIn("TextInput.Password", source)
        self.assertIn("resources/general/eye.svg", source)
        self.assertIn("resources/general/eye-closed.svg", source)
        self.assertIn("function togglePasswordVisibility()", source)
        self.assertIn("inputField.forceActiveFocus()", source)

    def test_every_current_password_input_uses_shared_component(self) -> None:
        expected_consumers = {
            "qml/sidebar/new_device/NewDevice.qml": 1,
            "qml/sidebar/new_device/AddYangcfg.qml": 1,
            "qml/sidebar/new_device/BatchNewDevice.qml": 1,
            "qml/interface/InterfaceView.qml": 1,
        }
        for relative_path, expected_count in expected_consumers.items():
            source = (self.ui_root / relative_path).read_text(encoding="utf-8")
            with self.subTest(qml=relative_path):
                self.assertEqual(source.count("StandardPasswordField {"), expected_count)
                self.assertNotIn("echoMode: TextInput.Password", source)


class SelectionTokenContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.ui_root = Path(__file__).resolve().parents[1] / "UI"

    def test_theme_exports_contrast_aware_selection_tokens(self) -> None:
        colors = (self.ui_root / "theme" / "tokens" / "ColorTokens.qml").read_text(
            encoding="utf-8"
        )
        theme = (self.ui_root / "theme" / "Theme.qml").read_text(encoding="utf-8")

        self.assertIn("selectionBackground", colors)
        self.assertIn("selectionForeground", colors)
        self.assertIn("selectionForegroundFor", colors)
        self.assertIn("contrastRatio", colors)
        self.assertIn("ColorTokens.selectionBackground", theme)
        self.assertIn("ColorTokens.selectionForeground", theme)

    def test_text_input_consumers_use_shared_selection_tokens(self) -> None:
        consumers = (
            "components/standard/StandardTextField.qml",
            "components/standard/StandardPasswordField.qml",
            "components/standard/StandardSpinBox.qml",
            "qml/content/InformationView.qml",
            "qml/content/DatabaseBrowserView.qml",
            "qml/shared/ViewPushDialog.qml",
            "qml/routing/info_routing.qml",
        )
        for relative_path in consumers:
            source = (self.ui_root / relative_path).read_text(encoding="utf-8")
            with self.subTest(qml=relative_path):
                self.assertRegex(source, r"selectionColor:\s+Theme\.selectionBackground")
                self.assertRegex(source, r"selectedTextColor:\s+Theme\.selectionForeground")


class NotificationUxContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.ui_root = Path(__file__).resolve().parents[1] / "UI"

    def test_toasts_do_not_offer_copy_and_use_fixed_severity_tokens(self) -> None:
        toast = (self.ui_root / "qml" / "shared" / "ToastManager.qml").read_text(
            encoding="utf-8"
        )
        status_icon = (
            self.ui_root / "components" / "standard" / "StatusIcon.qml"
        ).read_text(encoding="utf-8")
        colors = (self.ui_root / "theme" / "tokens" / "ColorTokens.qml").read_text(
            encoding="utf-8"
        )

        self.assertNotIn("CopyButton {", toast)
        self.assertNotIn('objectName: "toastCopyButton"', toast)
        for token in (
            "notificationInfoAccent",
            "notificationSuccessAccent",
            "notificationWarningAccent",
            "notificationErrorAccent",
            "notificationInfoBackground",
            "notificationSuccessBackground",
            "notificationWarningBackground",
            "notificationErrorBackground",
        ):
            with self.subTest(token=token):
                self.assertIn(f"Theme.{token}", status_icon)
                self.assertIn(token, colors)
        self.assertIn('notificationInfoAccent: pick("#0969DA", "#58A6FF"', colors)

    def test_notification_center_has_dynamic_height_and_icon_only_toolbar(self) -> None:
        panel = (self.ui_root / "qml" / "shared" / "NotificationPanel.qml").read_text(
            encoding="utf-8"
        )
        standard_button = (
            self.ui_root / "components" / "standard" / "StandardButton.qml"
        ).read_text(encoding="utf-8")

        self.assertIn("property int panelMaximumHeight: 400", panel)
        self.assertIn("height: Math.min(panelMaximumHeight", panel)
        self.assertIn("readonly property bool hasScrollableOverflow", panel)
        self.assertIn('objectName: "notificationHeaderText"', panel)
        self.assertIn('"No New Notifications"', panel)
        self.assertNotIn('"No New Notification"', panel)
        self.assertNotIn('objectName: "emptyNotificationText"', panel)
        self.assertIn("visible: root.notificationCount > 0", panel)
        self.assertIn("resources/general/chevron-down.svg", panel)
        self.assertIn("resources/statusbar/clear.svg", panel)
        self.assertIn("resources/statusbar/dnd.svg", panel)
        self.assertIn("resources/statusbar/bell.svg", panel)
        self.assertIn("signal toggleDndRequested()", panel)
        self.assertIn('objectName: "historyCopyButton"', panel)
        self.assertIn("CopyButton {", panel)
        self.assertNotIn("checkable: true", panel)
        self.assertNotIn("checked: root.doNotDisturb", panel)
        self.assertNotIn('text: "Clear All"', panel)
        self.assertNotIn("CloseButton {", panel)
        self.assertIn("id: iconOnlyContent", standard_button)
        self.assertIn("anchors.centerIn: parent", standard_button)

    def test_main_and_status_bar_enforce_dnd_for_every_notification_path(self) -> None:
        main = (self.ui_root / "qml" / "app" / "Main.qml").read_text(encoding="utf-8")
        status_bar = (self.ui_root / "qml" / "layout" / "StatusBar.qml").read_text(
            encoding="utf-8"
        )
        devices = (self.ui_root / "qml" / "panels" / "DevicesPanel.qml").read_text(
            encoding="utf-8"
        )

        self.assertIn("property bool isDoNotDisturb: false", main)
        self.assertIn("function setDoNotDisturb(enabled)", main)
        self.assertIn("notificationHistoryModel.insert", main)
        self.assertIn("toastManager.clearToasts()", main)
        self.assertIn("doNotDisturb: root.isDoNotDisturb", main)
        self.assertIn("onToggleDndRequested: root.setDoNotDisturb", main)
        self.assertIn("showToast !== false && !root.isDoNotDisturb", main)
        self.assertNotIn("toastManager.showToast", devices)

        self.assertIn("resources/statusbar/dnd.svg", status_bar)
        self.assertNotIn("resources/statusbar/bell-slash.svg", status_bar)
        self.assertIn("readonly property bool notificationShouldBlink", status_bar)
        self.assertIn("root.isDND", status_bar)
        self.assertIn("root.unreadCount > 0", status_bar)


if __name__ == "__main__":
    unittest.main()
