from __future__ import annotations

import inspect
import tempfile
import unittest
from pathlib import Path
from unittest.mock import ANY, patch

from PyQt6.QtCore import QCoreApplication, QSettings

from core.database_stubs import StubSlotsMixin
from core.acl_slots import AclSlotsMixin
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
    def test_acl_slot_converts_qjsvalue_payload(self) -> None:
        expected = {"host": "10.0.0.1", "acl_name": "EDGE_IN"}

        class FakeQjsValue:
            def toVariant(self):
                return expected

        class Bridge(AclSlotsMixin):
            @staticmethod
            def _as_dict(value):
                if hasattr(value, "toVariant"):
                    value = value.toVariant()
                return value if isinstance(value, dict) else {}

        with patch("core.acl_slots.save_acl", return_value=True) as save:
            self.assertTrue(Bridge().saveAcl(FakeQjsValue()))
            save.assert_called_once_with(ANY, expected)

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

    def test_acl_edit_change_cancel_and_module_size_contract(self) -> None:
        acl_dir = Path(__file__).resolve().parents[1] / "UI" / "qml" / "acl"
        editor = (acl_dir / "AclEditorPane.qml").read_text(encoding="utf-8")
        saved = (acl_dir / "AclSavedPanel.qml").read_text(encoding="utf-8")
        form = (acl_dir / "AclForm.qml").read_text(encoding="utf-8")
        self.assertIn('text: "View"', saved)
        self.assertIn('text: "Edit"', saved)
        self.assertIn('pane.viewing ? "Close View" : "Cancel"', editor)
        self.assertIn('text: pane.editing ? "Change ACL" : "Create ACL"', editor)
        self.assertIn("AclScrollablePane", editor)
        scroll_pane = (acl_dir / "AclScrollablePane.qml").read_text(encoding="utf-8")
        self.assertIn("ScrollBar.vertical", scroll_pane)
        self.assertIn("function viewAcl(index)", form)
        self.assertIn("function stageDeleteAcl(aclId)", form)
        self.assertIn("function savePendingDeletes()", form)
        self.assertIn("dbManager.deleteAcls(pendingDeleteIds)", form)
        self.assertIn('text: "Save"', form)
        self.assertIn('text: "Cancel Deletes"', form)
        bindings = (acl_dir / "AclBindingsEditor.qml").read_text(encoding="utf-8")
        binding_tab = (acl_dir / "AclBindingsTab.qml").read_text(encoding="utf-8")
        subbar = (acl_dir / "AclSubBar.qml").read_text(encoding="utf-8")
        self.assertIn("function addBinding()", bindings)
        self.assertIn('"Bindings"', subbar)
        self.assertIn("dbManager.saveAclBindings", binding_tab)
        self.assertNotIn("AclBindingsEditor", editor)

        feature_files = list(acl_dir.glob("*.qml"))
        feature_files += list((Path(__file__).resolve().parents[1] / "UI" / "qml" / "dhcp").glob("*.qml"))
        feature_files += list((Path(__file__).resolve().parents[1] / "backend" / "acl").glob("*.py"))
        feature_files += list((Path(__file__).resolve().parents[1] / "backend" / "dhcp").glob("*.py"))
        for path in feature_files:
            with self.subTest(path=path.name):
                self.assertLessEqual(len(path.read_text(encoding="utf-8").splitlines()), 400)

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
