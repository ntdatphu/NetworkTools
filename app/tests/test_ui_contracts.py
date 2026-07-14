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
        self.assertEqual(len(self.button_blocks), 110)
        self.assertEqual(len(buttons_with_icons), 38)
        self.assertEqual(len(self.button_blocks) - len(buttons_with_icons), 72)

    def test_add_and_new_buttons_do_not_use_add_icons(self) -> None:
        for path, block in self.button_blocks:
            with self.subTest(qml=path.name):
                self.assertNotIn("resources/sidebar/add.svg", block)
                self.assertNotIn("resources/sidebar/list-plus.svg", block)


if __name__ == "__main__":
    unittest.main()
