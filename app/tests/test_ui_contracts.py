from __future__ import annotations

import inspect
import tempfile
import unittest
from pathlib import Path

from PyQt6.QtCore import QCoreApplication, QSettings

from core.database_stubs import StubSlotsMixin
from core.runtime import WindowSettings


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
    def test_dynamic_nat_uses_acl_combo_and_nat_tabs_auto_reload(self) -> None:
        nat_dir = Path(__file__).resolve().parents[1] / "UI" / "qml" / "nat"
        dynamic_source = (nat_dir / "NatDynamicForm.qml").read_text(encoding="utf-8")
        route_map_source = (nat_dir / "NatRouteMapForm.qml").read_text(encoding="utf-8")
        view_source = (nat_dir / "NatView.qml").read_text(encoding="utf-8")

        self.assertIn("id: dynamicAclCombo", dynamic_source)
        self.assertIn("model: natDynamicForm.aclNames", dynamic_source)
        self.assertIn("dbManager.getNatAclNames(currentHostIp)", dynamic_source)
        self.assertNotIn("id:               aclNameField", dynamic_source)
        self.assertIn("id: routeMapAclCombo", route_map_source)
        self.assertIn("model: [\"No ACL\"].concat(routeMapForm.aclNames)", route_map_source)
        self.assertIn("dbManager.getNatAclNames(currentHostIp)", route_map_source)
        self.assertNotIn("id: aclNameField", route_map_source)
        self.assertIn("function reloadSelectedNatTab()", view_source)
        self.assertIn("dynamicLoader.item.reloadAclNames()", view_source)
        self.assertIn("dynamicLoader.item.reloadPools()", view_source)
        self.assertIn("patLoader.item.reloadAclNames()", view_source)
        self.assertIn("patLoader.item.reloadRules()", view_source)
        self.assertIn("routeMapLoader.item.reloadAclNames()", view_source)
        self.assertIn("routeMapLoader.item.reloadEntries()", view_source)

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


if __name__ == "__main__":
    unittest.main()
