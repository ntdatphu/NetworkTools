from __future__ import annotations

import inspect
import re
import tempfile
import unittest
from pathlib import Path
from unittest.mock import ANY, patch

from PyQt6.QtCore import QCoreApplication, QSettings

from core.acl_slots import AclSlotsMixin
from core.nat_slots import NatSlotsMixin
from core.settings import WindowSettings


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
        nat_dir = Path(__file__).resolve().parents[1] / "UI" / "qml" / "features" / "nat"
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
        dhcp_dir = Path(__file__).resolve().parents[1] / "UI" / "qml" / "features" / "dhcp"
        for form_name in ("DhcpPoolForm.qml", "DhcpExcludedForm.qml", "DhcpHelperForm.qml"):
            source = (dhcp_dir / form_name).read_text(encoding="utf-8")
            with self.subTest(form=form_name):
                self.assertIn("property bool hasPendingLocalChanges", source)
                self.assertIn("function saveChanges()", source)
                self.assertIn("function cancelChanges()", source)
                self.assertIn('text: "Cancel Changes"', source)
                self.assertIn('text: "Save"', source)

    def test_acl_edit_change_cancel_and_module_size_contract(self) -> None:
        acl_dir = Path(__file__).resolve().parents[1] / "UI" / "qml" / "features" / "acl"
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
        feature_files += list((Path(__file__).resolve().parents[1] / "UI" / "qml" / "features" / "dhcp").glob("*.qml"))
        feature_files += list((Path(__file__).resolve().parents[1] / "features" / "acl").glob("*.py"))
        feature_files += list((Path(__file__).resolve().parents[1] / "features" / "dhcp").glob("*.py"))
        for path in feature_files:
            with self.subTest(path=path.name):
                self.assertLessEqual(len(path.read_text(encoding="utf-8").splitlines()), 400)

    def test_every_nat_form_exposes_save_cancel_and_reload_actions(self) -> None:
        nat_dir = Path(__file__).resolve().parents[1] / "UI" / "qml" / "features" / "nat"
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

    def test_nat_add_slots_match_qml_positional_arity(self) -> None:
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
                method = getattr(NatSlotsMixin, method_name)
                self.assertEqual(len(inspect.signature(method).parameters), expected_count)


class SvgResourceContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.ui_root = Path(__file__).resolve().parents[1] / "UI"
        cls.resources = cls.ui_root / "resources"
        cls.app_assets = cls.ui_root / "qml" / "shared" / "AppAssets.qml"

    def test_active_svg_paths_are_centralized_and_resolve(self) -> None:
        source = self.app_assets.read_text(encoding="utf-8")
        paths = re.findall(
            r'readonly property url \w+: resource\("([^"]+\.svg)"\)',
            source,
        )

        self.assertEqual(len(paths), 110)
        self.assertEqual(len(paths), len(set(paths)))
        for path in paths:
            with self.subTest(asset=path):
                self.assertTrue((self.ui_root / path).is_file())

        mapped = {path.removeprefix("resources/") for path in paths}
        active = {
            path.relative_to(self.resources).as_posix()
            for path in self.resources.rglob("*.svg")
        }
        self.assertEqual(active, mapped)

    def test_qml_consumers_use_semantic_app_assets_only(self) -> None:
        for path in self.ui_root.rglob("*.qml"):
            if path == self.app_assets:
                continue
            source = path.read_text(encoding="utf-8")
            with self.subTest(qml=path.relative_to(self.ui_root).as_posix()):
                self.assertNotRegex(source, r"resources/[A-Za-z0-9_./-]+\.svg")
                self.assertNotIn("AppAssets.resource(", source)

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
        asset_dir = self.ui_root / "resources" / "actions"
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

        self.assertEqual(len(reload_blocks), 18)
        self.assertTrue(
            all(
                "AppAssets.actionDatabaseReload" in block
                or "AppAssets.actionBackup" in block
                for block in reload_blocks
            )
        )
        self.assertGreaterEqual(len(save_blocks), 17)
        self.assertTrue(all("AppAssets.actionSave" in block for block in save_blocks))

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

        self.assertIn("AppAssets.actionPush", view_push)
        self.assertIn("AppAssets.actionDatabaseReload", dialog)
        self.assertIn("AppAssets.actionPush", dialog)
        self.assertIn("AppAssets.actionBackup", device_menu)

    def test_documented_standard_button_icon_coverage(self) -> None:
        buttons_with_icons = [
            block for _, block in self.button_blocks if re.search(r"\bicon\.source\s*:", block)
        ]
        # System Logs contributes five actions, all backed by semantic assets.
        self.assertEqual(len(self.button_blocks), 175)
        self.assertEqual(len(buttons_with_icons), 67)
        self.assertEqual(len(self.button_blocks) - len(buttons_with_icons), 108)

    def test_sftp_assets_are_deduplicated_and_use_semantic_bindings(self) -> None:
        resources = self.ui_root / "resources"
        self.assertFalse((resources / "sftp_icons").exists())
        self.assertFalse((resources / "_unused").exists())
        self.assertIn(
            "Lucide Icons",
            (resources / "licenses" / "LUCIDE.txt").read_text(encoding="utf-8"),
        )
        self.assertIn(
            "vscode-icons",
            (resources / "licenses" / "VSCODE-ICONS.txt").read_text(encoding="utf-8"),
        )
        self.assertIn(
            "Material Extensions",
            (resources / "licenses" / "MATERIAL-ICON-THEME.txt").read_text(
                encoding="utf-8"
            ),
        )

        connection = (self.ui_root / "qml" / "sftp" / "SftpConnectionBar.qml").read_text(
            encoding="utf-8"
        )
        panel = (self.ui_root / "qml" / "sftp" / "SftpFilePanel.qml").read_text(
            encoding="utf-8"
        )
        queue = (self.ui_root / "qml" / "sftp" / "SftpTransferQueue.qml").read_text(
            encoding="utf-8"
        )
        log_panel = (self.ui_root / "qml" / "sftp" / "SftpLogPanel.qml").read_text(
            encoding="utf-8"
        )
        view = (self.ui_root / "qml" / "sftp" / "SftpView.qml").read_text(
            encoding="utf-8"
        )
        for relative_path in (
            "actions/connect.svg",
            "actions/disconnect.svg",
            "actions/upload.svg",
            "actions/download.svg",
            "actions/edit.svg",
            "actions/delete.svg",
            "actions/refresh.svg",
            "files/folder.svg",
            "files/file.svg",
            "files/types/docker.svg",
            "files/types/hex.svg",
            "files/types/python.svg",
            "files/types/yang.svg",
        ):
            with self.subTest(asset=relative_path):
                self.assertTrue((resources / relative_path).is_file())
        self.assertIn("AppAssets.actionConnect", connection)
        self.assertIn("AppAssets.fileTypeIcon(name)", panel)
        self.assertIn("source: row.isDirectory", panel)
        self.assertNotIn("iconColor: root.selectedIndex === row.index", panel)
        self.assertNotIn("Theme.selectionForeground", panel)
        self.assertRegex(panel, r"text: row\.name\s+elide: Text\.ElideRight\s+color: Theme\.textPrimary")
        self.assertRegex(panel, r"text: row\.sizeText\s+color: Theme\.textSecondary")
        self.assertRegex(
            panel,
            r"text: row\.modified\s+elide: Text\.ElideRight\s+color: Theme\.textSecondary",
        )
        self.assertIn("AppAssets.actionUpload", panel)
        self.assertIn("AppAssets.actionDelete", queue)
        self.assertNotIn("AppAssets.resource", connection + panel + queue)
        self.assertIn("maximumEntries: 500", log_panel)
        self.assertIn("while (logModel.count >= root.maximumEntries)", log_panel)
        self.assertIn("SftpLogPanel {", view)

    def test_ospf_network_remove_action_uses_existing_standard_icon(self) -> None:
        source = (
            self.ui_root / "qml" / "features" / "routing" / "ospf" / "OspfNetworksSection.qml"
        ).read_text(encoding="utf-8")

        self.assertIn("RemoveIconButton {", source)
        self.assertNotIn("AppAssets.resource", source)
        self.assertTrue((self.ui_root / "resources" / "actions" / "close.svg").is_file())

    def test_syslog_uses_current_workspace_table_and_resource_contracts(self) -> None:
        workspace = (self.ui_root / "qml" / "features" / "syslog" / "SyslogWorkspace.qml").read_text(
            encoding="utf-8"
        )
        table = (self.ui_root / "qml" / "features" / "syslog" / "SyslogLogTable.qml").read_text(
            encoding="utf-8"
        )
        row = (self.ui_root / "qml" / "features" / "syslog" / "SyslogLogRow.qml").read_text(
            encoding="utf-8"
        )
        settings = (
            self.ui_root / "qml" / "features" / "syslog" / "SyslogServerSettings.qml"
        ).read_text(encoding="utf-8")
        context_menu = (
            self.ui_root / "qml" / "sidebar" / "syslog" / "SyslogDeviceContextMenu.qml"
        ).read_text(encoding="utf-8")
        activity_bar = (self.ui_root / "qml" / "layout" / "ActivityBar.qml").read_text(
            encoding="utf-8"
        )
        main = (self.ui_root / "qml" / "app" / "Main.qml").read_text(encoding="utf-8")

        self.assertIn("WorkspaceHeader {", workspace)
        self.assertIn("maximumEntries: 2000", workspace)
        self.assertIn("function matchesFilters(row)", workspace)
        self.assertIn("DataTable {", table)
        self.assertIn("DataTableHeader {", table)
        self.assertIn("DataTableRow {", row)
        self.assertGreaterEqual(row.count("DataTableCell {"), 6)
        self.assertGreaterEqual(settings.count("FormSection {"), 3)
        self.assertIn("ContextMenuItem {", context_menu)
        self.assertIn("AppAssets.navigationSyslog", activity_bar)
        self.assertIn("id: syslogWorkspaceLoader", main)
        self.assertIn("asynchronous: true", main)

    def test_add_and_new_buttons_do_not_use_add_icons(self) -> None:
        for path, block in self.button_blocks:
            with self.subTest(qml=path.name):
                self.assertNotIn("AppAssets.actionAdd", block)
                self.assertNotIn("AppAssets.actionListAdd", block)

    def test_cancel_changes_is_leftmost_text_action(self) -> None:
        cancel_consumers = []
        for path in self.qml_files:
            source = path.read_text(encoding="utf-8")
            if 'text: "Cancel Changes"' in source:
                cancel_consumers.append((path, source))

        self.assertEqual(len(cancel_consumers), 13)
        for path, source in cancel_consumers:
            cancel_blocks = [
                block
                for block in _qml_component_blocks(source, "StandardButton")
                if 'text: "Cancel Changes"' in block
            ]
            with self.subTest(qml=path.name):
                self.assertEqual(len(cancel_blocks), 1)
                self.assertIn('type: "Text"', cancel_blocks[0])
                if path.name == "ExternalToolsSettings.qml":
                    self.assertLess(
                        source.index('text: "Cancel Changes"'),
                        source.index('text: enabledToggle.checked ? "Use application" : "Save"'),
                    )
                elif path.name != "AclBindingsTab.qml":
                    self.assertLess(
                        source.index('text: "Cancel Changes"'),
                        source.index('text: "Reload"'),
                    )

    def test_every_cancel_action_uses_text_style(self) -> None:
        cancel_blocks = [
            (path, block)
            for path, block in self.button_blocks
            if re.search(r"\btext\s*:.*\"Cancel", block)
        ]

        # System Logs adds the source-interface configuration dialog.
        self.assertEqual(len(cancel_blocks), 32)
        for path, block in cancel_blocks:
            with self.subTest(qml=path.name):
                self.assertIn('type: "Text"', block)

        edit_form_paths = (
            "qml/features/dhcp/DhcpPoolForm.qml",
            "qml/features/nat/NatStaticForm.qml",
            "qml/features/nat/NatDynamicForm.qml",
            "qml/features/nat/NatPatForm.qml",
            "qml/features/nat/NatInterfaceForm.qml",
            "qml/features/nat/NatAclForm.qml",
            "qml/features/nat/NatRouteMapForm.qml",
        )
        for relative_path in edit_form_paths:
            source = (self.ui_root / relative_path).read_text(encoding="utf-8")
            with self.subTest(order=relative_path):
                self.assertLess(
                    source.index('text: "Cancel"'),
                    source.index('? "Apply Edit" : "Add Locally"'),
                )

    def test_standard_button_has_keyboard_focus_ring_and_text_style(self) -> None:
        source = (
            self.ui_root / "components" / "standard" / "StandardButton.qml"
        ).read_text(encoding="utf-8")

        self.assertIn("focusPolicy: Qt.StrongFocus", source)
        self.assertIn("if (root.visualFocus) return Theme.accentColor", source)
        self.assertIn('root.type === "Text" || root.type === "TextIcon"', source)
        self.assertIn('if (root.type === "TextIcon")', source)
        self.assertIn('font.bold: root.type === "Primary" || root.type === "Danger"', source)
        self.assertNotIn('root.type === "Danger" || root.type === "Text"', source)
        self.assertIn('root.type === "Text" && (hoverHandler.hovered || root.visualFocus)', source)


class QmlModuleContractTests(unittest.TestCase):
    def test_qmldir_exports_only_existing_qml_files(self) -> None:
        ui_root = Path(__file__).resolve().parents[1] / "UI"
        qmldir = (ui_root / "qmldir").read_text(encoding="utf-8")
        exports = 0
        for raw_line in qmldir.splitlines():
            line = raw_line.strip()
            if not line or line.startswith(("#", "module", "prefer")):
                continue
            candidate = line.split()[-1]
            if not candidate.endswith(".qml"):
                continue
            exports += 1
            with self.subTest(export=line.split()[0]):
                self.assertTrue((ui_root / candidate).is_file(), candidate)
        self.assertGreater(exports, 50)

    @classmethod
    def setUpClass(cls) -> None:
        cls.ui_root = Path(__file__).resolve().parents[1] / "UI"

    def test_deprecated_base_components_are_removed_from_module(self) -> None:
        qmldir = (self.ui_root / "qmldir").read_text(encoding="utf-8")
        qml_source = "\n".join(
            path.read_text(encoding="utf-8")
            for path in self.ui_root.rglob("*.qml")
        )

        self.assertNotIn("BaseButton 1.0", qmldir)
        self.assertNotIn("BaseCard 1.0", qmldir)
        self.assertFalse((self.ui_root / "components" / "base" / "BaseButton.qml").exists())
        self.assertFalse((self.ui_root / "components" / "base" / "BaseCard.qml").exists())
        self.assertNotRegex(qml_source, r"\bBaseButton\s*\{")
        self.assertNotRegex(qml_source, r"\bBaseCard\s*\{")
        self.assertIn("ProcessCard 1.0 components/base/ProcessCard.qml", qmldir)

    def test_command_registry_owns_contextual_global_shortcuts(self) -> None:
        qmldir = (self.ui_root / "qmldir").read_text(encoding="utf-8")
        registry = (
            self.ui_root / "qml" / "shared" / "CommandRegistry.qml"
        ).read_text(encoding="utf-8")
        main = (self.ui_root / "qml" / "app" / "Main.qml").read_text(encoding="utf-8")
        content = (
            self.ui_root / "qml" / "content" / "ContentArea.qml"
        ).read_text(encoding="utf-8")
        activity = (
            self.ui_root / "qml" / "layout" / "ActivityBar.qml"
        ).read_text(encoding="utf-8")

        self.assertIn("CommandRegistry 1.0 qml/shared/CommandRegistry.qml", qmldir)
        for contract in (
            'reloadShortcut: "Ctrl+R"',
            'devicesShortcut: "Ctrl+1"',
            'databaseShortcut: "Ctrl+2"',
            'settingsShortcut: "Ctrl+3"',
            "contextualCommandsEnabled: commandsEnabled && !inputFocusActive",
            "function triggerReload()",
            "function triggerDevices()",
            "function triggerDatabase()",
            "function triggerSettings()",
            "context: Qt.ApplicationShortcut",
        ):
            with self.subTest(registry_contract=contract):
                self.assertIn(contract, registry)

        for contract in (
            'objectName: "appCommandRegistry"',
            "commandsEnabled: !UiState.windowLock",
            "inputFocusActive: root.textInputHasFocus",
            "reloadAvailable: contentArea.reloadCommandEnabled",
            "databaseAvailable: activityBar.canActivateDatabase",
        ):
            with self.subTest(main_contract=contract):
                self.assertIn(contract, main)

        self.assertIn("readonly property bool reloadCommandEnabled", content)
        self.assertIn("function triggerReloadCommand()", content)
        self.assertIn('reloadData("shortcut", true)', content)
        self.assertIn("function activateDevices()", activity)
        self.assertIn("function activateDatabase(toggleSidebarWhenActive)", activity)
        self.assertIn("function activateSettings()", activity)

        self.assertNotIn('saveShortcut: "Ctrl+S"', registry)
        self.assertNotIn('viewPushShortcut: "Ctrl+Shift+P"', registry)

    def test_device_tab_loader_uses_async_cached_view_lifecycle(self) -> None:
        qmldir = (self.ui_root / "qmldir").read_text(encoding="utf-8")
        spinner = (
            self.ui_root / "components" / "base" / "LoadingSpinner.qml"
        ).read_text(encoding="utf-8")
        tab_item = (
            self.ui_root / "qml" / "devices" / "DeviceTabItem.qml"
        ).read_text(encoding="utf-8")
        tabs = (
            self.ui_root / "qml" / "devices" / "DeviceTabs.qml"
        ).read_text(encoding="utf-8")
        main = (self.ui_root / "qml" / "app" / "Main.qml").read_text(encoding="utf-8")
        content = (
            self.ui_root / "qml" / "content" / "ContentArea.qml"
        ).read_text(encoding="utf-8")

        self.assertIn("LoadingSpinner 1.0 components/base/LoadingSpinner.qml", qmldir)
        self.assertIn("RotationAnimator on rotation", spinner)
        self.assertIn("duration: Theme.loaderRotationDuration", spinner)
        self.assertIn('objectName: "deviceTabLoadingSpinner"', tab_item)
        self.assertIn("model.contentLoading === true", tab_item)
        self.assertIn("delegateRoot.hasDeviceIcon && !delegateRoot.isLoading", tab_item)
        self.assertIn("property bool activeContentLoading: false", tabs)
        self.assertIn("function syncActiveContentLoading()", tabs)
        self.assertIn("contentLoading: false", tabs)
        self.assertIn("activeContentLoading: contentArea.activeViewLoading", main)

        for contract in (
            "readonly property bool activeViewLoading",
            "function loaderIsBusy(loader)",
            "function cancelInactivePendingLoads()",
            "function scheduleActiveViewLoad()",
            "function syncHostToActiveView()",
            "property bool activeViewLoadPending: false",
            "property bool hostApplyPending: false",
            "id: hostApplyTimer",
            "interval: Theme.viewLoadDispatchDelay",
            "contentArea.effectiveHostIp = contentArea.pendingHostIp",
        ):
            with self.subTest(content_contract=contract):
                self.assertIn(contract, content)
        self.assertEqual(content.count("asynchronous: true"), 9)

        nested_loader_counts = {
            "qml/features/routing/RoutingView.qml": 4,
            "qml/features/dhcp/DhcpView.qml": 4,
            "qml/features/nat/NatView.qml": 7,
            "qml/features/acl/AclView.qml": 2,
        }
        for relative_path, expected_count in nested_loader_counts.items():
            source = (self.ui_root / relative_path).read_text(encoding="utf-8")
            with self.subTest(async_view=relative_path):
                self.assertEqual(source.count("asynchronous: true"), expected_count)
                self.assertIn("isViewLoading", source)
                self.assertIn("function syncHostToCurrentTab()", source)

    def test_config_text_viewer_is_shared_by_both_config_surfaces(self) -> None:
        qmldir = (self.ui_root / "qmldir").read_text(encoding="utf-8")
        viewer = (
            self.ui_root / "components" / "standard" / "ConfigTextViewer.qml"
        ).read_text(encoding="utf-8")
        context_menu = (
            self.ui_root / "components" / "standard" / "ConfigTextContextMenu.qml"
        ).read_text(encoding="utf-8")
        information = (
            self.ui_root / "qml" / "content" / "InformationView.qml"
        ).read_text(encoding="utf-8")
        routing = (
            self.ui_root / "qml" / "features" / "routing" / "info_routing.qml"
        ).read_text(encoding="utf-8")

        self.assertIn("ConfigTextViewer 1.0 components/standard/ConfigTextViewer.qml", qmldir)
        self.assertIn("ConfigTextContextMenu 1.0 components/standard/ConfigTextContextMenu.qml", qmldir)
        self.assertEqual(information.count("ConfigTextViewer {"), 1)
        self.assertEqual(routing.count("ConfigTextViewer {"), 1)
        self.assertNotIn("TextArea {", information)
        self.assertEqual(routing.count("TextArea {"), 0)
        for contract in (
            'sequence: "Ctrl+F"',
            "function focusSearch()",
            "onAccepted: root.findNext()",
            "onReverseAccepted: root.findPrevious()",
            "function runSearchNow()",
            "function findNext()",
            "function findPrevious()",
            "function selectLine(lineIndex)",
            "function selectLineRange(firstLineIndex, lastLineIndex)",
            "function selectLineAtSelectionMarginY(viewportY, extendSelection)",
            "function zoomIn()",
            "function zoomOut()",
            "function setZoomPercent(percent)",
            "function resetZoom()",
            "function copySelection()",
            "function findSelectedText()",
            "function normalizeLineBreaks(value)",
            "function rebuildSelectionOccurrences()",
            "CopyButton {",
            "maximumSearchMatches: 10000",
            "function highlightLine(line)",
            "function processHighlightChunk()",
            "highlightingChunkLineCount: 250",
            "syntaxHighlightCharacterLimit: 1000000",
            "highlightingSkippedForLargeText",
            "TextEdit.RichText",
            'objectName: "configViewerBottomToolbar"',
            'objectName: "configViewerZoomOutButton"',
            'objectName: "configViewerZoomInButton"',
            'objectName: "configViewerResetZoomButton"',
            'objectName: "configViewerZoomSpinBox"',
            'objectName: "configViewerLineSelectionMargin"',
            'objectName: "configViewerOccurrenceRepeater"',
            'objectName: "configViewerOccurrenceMarker"',
            'objectName: "configViewerContextMenu"',
            'objectName: "configViewerZoomWheelHandler"',
            'objectName: "configViewerLineScrollWheelHandler"',
            "function lineAlignedContentY(value)",
            "function snapVerticalScroll()",
            "function scrollByLines(lineCount)",
            "acceptedModifiers: Qt.NoModifier",
            "defaultFontPixelSize: Theme.fontSizeNormal",
            "minimumZoomPercent: 25",
            "maximumZoomPercent: 500",
            "defaultZoomPercent: 100",
            "25, 33, 50, 67, 75, 80, 90, 100, 110",
            "Layout.maximumWidth: 64",
            "anchors.leftMargin: -18",
            "bottomPadding: root.codeLineHeight",
            'const trailingLineKeeper = /\\n$/.test(root.pendingHighlightSource)',
            '";font-weight:600"',
            "function copyAll()",
            'sequence: "Ctrl+="',
            'sequence: "Ctrl+-"',
        ):
            with self.subTest(contract=contract):
                self.assertIn(contract, viewer)

        self.assertNotIn("ListView {", viewer)
        self.assertNotIn('objectName: "configViewerLineNumbers"', viewer)
        self.assertNotIn("lineNumberText", viewer)
        self.assertNotIn("minimumFontPixelSize", viewer)
        self.assertNotIn("maximumFontPixelSize", viewer)
        for contract in (
            "ContextMenuItem {",
            'text: "Copy"',
            'shortcutText: "Ctrl+C"',
            "AppAssets.actionCopy",
            'text: "Find"',
            'shortcutText: "Ctrl+F"',
            "AppAssets.actionSearch",
        ):
            with self.subTest(context_menu_contract=contract):
                self.assertIn(contract, context_menu)

        self.assertNotIn('sequence: "F3"', viewer)
        self.assertNotIn('sequence: "Shift+F3"', viewer)
        self.assertIn("function ensureSearchCurrent()", viewer)
        self.assertIn("root.ensureSearchCurrent()", viewer)
        self.assertIn("interval: 1", viewer)
        select_match = viewer[
            viewer.index("function selectMatch(index)") : viewer.index("function findNext()")
        ]
        self.assertNotIn("forceActiveFocus", select_match)
        self.assertLess(
            viewer.index('objectName: "configViewerContent"'),
            viewer.index('objectName: "configViewerBottomToolbar"'),
        )

        for source, button_name in (
            (information, "informationCopyAllButton"),
            (routing, "routingConfigCopyAllButton"),
        ):
            with self.subTest(copy_button=button_name):
                self.assertIn(f'objectName: "{button_name}"', source)
                viewer_id = "informationConfigViewer" if button_name.startswith("information") else "routingConfigViewer"
                self.assertIn(
                    f'text: {viewer_id}.copyFeedbackVisible ? "Copied" : "Copy All"',
                    source,
                )
                self.assertIn("AppAssets.actionCopy", source)

    def test_config_syntax_palette_exports_distinct_semantic_tokens(self) -> None:
        colors = (self.ui_root / "theme" / "tokens" / "ColorTokens.qml").read_text(
            encoding="utf-8"
        )
        theme = (self.ui_root / "theme" / "Theme.qml").read_text(encoding="utf-8")
        viewer = (
            self.ui_root / "components" / "standard" / "ConfigTextViewer.qml"
        ).read_text(encoding="utf-8")
        token_names = (
            "syntaxIpAddress",
            "syntaxPrefix",
            "syntaxMask",
            "syntaxWildcard",
            "syntaxInterface",
            "syntaxNumber",
            "syntaxBoolean",
            "syntaxDateTime",
            "syntaxPermit",
            "syntaxDeny",
            "syntaxInside",
            "syntaxOutside",
            "syntaxComment",
        )
        for token_name in token_names:
            with self.subTest(token=token_name):
                self.assertIn(f"property color {token_name}", colors)
                self.assertIn(f"ColorTokens.{token_name}", theme)
                self.assertIn(f"Theme.{token_name}", viewer)

    def test_information_activation_loads_versioned_backup_history(self) -> None:
        information = (
            self.ui_root / "qml" / "content" / "InformationView.qml"
        ).read_text(encoding="utf-8")
        content_area = (
            self.ui_root / "qml" / "content" / "ContentArea.qml"
        ).read_text(encoding="utf-8")

        for contract in (
            "function reloadData(reason)",
            "function loadCommit(commitId)",
            "dbManager.getRunningConfigHistory(host)",
            "dbManager.getRunningConfigAtCommit(host, requestedCommit)",
            'objectName: "informationCommitHistoryComboBox"',
            "property var commitHistory: []",
            "function onRunningConfigFinished(host, ok, message)",
            "onCurrentHostIpChanged: reloadData()",
            "onClicked: root.reloadData()",
        ):
            with self.subTest(information_contract=contract):
                self.assertIn(contract, information)

        for contract in (
            "function scheduleInformationActivationReload()",
            "informationActivationTimer.restart()",
            'informationLoader.item.reloadData("activation")',
            'objectName: "informationLoader"',
            'objectName: "dhcpLoader"',
            'objectName: "loadedInformationView"',
            'objectName: "loadedDhcpView"',
        ):
            with self.subTest(content_contract=contract):
                self.assertIn(contract, content_area)

        dhcp_loader = content_area[
            content_area.index("id: dhcpLoader") : content_area.index("// ── ACL")
        ]
        information_loader = content_area[
            content_area.index("id: informationLoader") : content_area.index("// ── Các feature")
        ]
        self.assertIn("DhcpView {", dhcp_loader)
        self.assertNotIn("InformationView {", dhcp_loader)
        self.assertIn("InformationView {", information_loader)
        self.assertNotIn("DhcpView {", information_loader)


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
        self.assertIn("AppAssets.actionVisibilityOn", source)
        self.assertIn("AppAssets.actionVisibilityOff", source)
        self.assertIn("function togglePasswordVisibility()", source)
        self.assertIn("inputField.forceActiveFocus()", source)

    def test_every_current_password_input_uses_shared_component(self) -> None:
        expected_consumers = {
            "qml/sidebar/new_device/NewDevice.qml": 1,
            "qml/sidebar/new_device/AddYangcfg.qml": 1,
            "qml/sidebar/new_device/BatchNewDevice.qml": 1,
            "qml/features/interfaces/InterfaceView.qml": 1,
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
            "components/standard/ConfigTextViewer.qml",
            "qml/content/DatabaseBrowserView.qml",
            "qml/shared/ViewPushDialog.qml",
        )
        for relative_path in consumers:
            source = (self.ui_root / relative_path).read_text(encoding="utf-8")
            with self.subTest(qml=relative_path):
                self.assertRegex(source, r"selectionColor:\s+Theme\.selectionBackground")
                self.assertRegex(source, r"selectedTextColor:\s+Theme\.selectionForeground")

    def test_standard_spin_box_uses_one_content_inset(self) -> None:
        spin_box = (
            self.ui_root / "components" / "standard" / "StandardSpinBox.qml"
        ).read_text(encoding="utf-8")

        self.assertIn('objectName: "standardSpinBoxControl"', spin_box)
        self.assertIn('objectName: "standardSpinBoxInput"', spin_box)
        self.assertIn("leftPadding: 0", spin_box)
        self.assertIn("rightPadding: 0", spin_box)
        self.assertIn("leftPadding: Theme.spacing12", spin_box)
        self.assertIn("property bool showIndicators: true", spin_box)


class DataTableUiContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.ui_root = Path(__file__).resolve().parents[1] / "UI"

    def source(self, relative_path: str) -> str:
        return (self.ui_root / relative_path).read_text(encoding="utf-8")

    def test_shared_table_family_is_exported_and_tokenized(self) -> None:
        qmldir = self.source("qmldir")
        sizes = self.source("theme/tokens/SizeTokens.qml")
        for component in (
            "DataTable",
            "DataTableCell",
            "DataTableFrame",
            "DataTableHeader",
            "DataTableRow",
        ):
            with self.subTest(component=component):
                self.assertIn(f"{component} 1.0 components/table/{component}.qml", qmldir)
        self.assertIn("readonly property int tableHeaderHeight: 36", sizes)
        self.assertIn("readonly property int tableRowHeight: 40", sizes)
        self.assertIn("readonly property int dataWorkspaceBreakpoint: 920", sizes)

    def test_saved_list_family_cannot_overlap_header_and_content(self) -> None:
        panel = self.source("components/layout/SavedListPanel.qml")
        header = self.source("components/layout/SavedListHeader.qml")
        row = self.source("components/layout/SavedListRow.qml")
        acl_saved = self.source("qml/features/acl/AclSavedPanel.qml")
        acl_rules = self.source("qml/features/acl/AclRulesPanel.qml")

        self.assertIn("Layout.preferredHeight: active ? Theme.tableHeaderHeight : 0", panel)
        self.assertIn("visible: root.count > 0", panel)
        self.assertIn("DataTableHeader {", header)
        self.assertIn("DataTableRow {", row)
        self.assertIn("DataTableCell {", acl_saved)
        self.assertIn("DataTableCell {", acl_rules)
        self.assertNotIn("spacing: 2", acl_saved)
        self.assertNotIn("spacing: 2", acl_rules)

    def test_saved_table_consumers_share_responsive_columns_and_neutral_selection(self) -> None:
        row = self.source("components/table/DataTableRow.qml")
        colors = self.source("theme/tokens/ColorTokens.qml")
        saved_consumers = (
            "qml/features/dhcp/DhcpPoolList.qml",
            "qml/features/dhcp/DhcpExcludedForm.qml",
            "qml/features/dhcp/DhcpHelperForm.qml",
            "qml/features/nat/NatInterfaceForm.qml",
            "qml/features/nat/NatStaticForm.qml",
            "qml/features/nat/NatDynamicForm.qml",
            "qml/features/nat/NatPatForm.qml",
            "qml/features/nat/NatAclForm.qml",
            "qml/features/nat/NatRouteMapForm.qml",
            "qml/features/acl/AclSavedPanel.qml",
            "qml/features/acl/AclRulesPanel.qml",
        )

        self.assertIn("property color selectedColor: Theme.tableRowSelected", row)
        self.assertIn("visible: root.selected", row)
        self.assertIn("Theme.tableRowSelectionIndicator", row)
        self.assertNotIn("selectedColor: Theme.sideBarItemSelected", row)
        for token in (
            "tableRowAlternate",
            "tableRowHover",
            "tableRowSelected",
            "tableRowSelectionIndicator",
        ):
            self.assertIn(token, colors)

        for relative_path in saved_consumers:
            source = self.source(relative_path)
            with self.subTest(qml=relative_path):
                self.assertIn("RowLayout {", source)
                self.assertIn("DataTableCell {", source)
                self.assertNotRegex(source, r"ListView\s*\{.{0,220}?spacing:\s*2")

    def test_routing_network_tables_use_the_same_table_primitives(self) -> None:
        for relative_path in (
            "qml/features/routing/ospf/OspfNetworksSection.qml",
            "qml/features/routing/eigrp/EigrpNetworksSection.qml",
        ):
            source = self.source(relative_path)
            with self.subTest(qml=relative_path):
                self.assertIn("DataTableFrame {", source)
                self.assertIn("DataTableHeader {", source)
                self.assertIn("delegate: DataTableRow {", source)
                self.assertIn("DataTableCell {", source)

    def test_switch_workspace_uses_one_responsive_table_and_inspector_family(self) -> None:
        workspace = self.source("qml/features/switching/SwitchWorkspace.qml")
        switch_pages = {
            "qml/features/switching/interfaces/SwitchPortsPage.qml": "SwitchPortTable {",
            "qml/features/switching/interfaces/SviPage.qml": "DataTable {",
            "qml/features/switching/switching/VlanPage.qml": "DataTable {",
            "qml/features/switching/monitoring/SwitchMonitoringPage.qml": "DataTable {",
        }

        self.assertIn("visible: root.currentSubFeatureTabs.length >= 2", workspace)
        self.assertIn("Layout.preferredHeight: visible ? Theme.subBarHeight : 0", workspace)
        for relative_path, table_token in switch_pages.items():
            source = self.source(relative_path)
            with self.subTest(qml=relative_path):
                self.assertIn("WorkspaceHeader {", source)
                self.assertIn(table_token, source)
        for relative_path in tuple(switch_pages)[:3]:
            with self.subTest(responsive=relative_path):
                source = self.source(relative_path)
                self.assertIn("SplitView {", source)
                self.assertIn("StandardSplitHandle", source)

        port_table = self.source("qml/features/switching/interfaces/SwitchPortTable.qml")
        self.assertIn("DataTable {", port_table)
        self.assertIn("delegate: DataTableRow {", port_table)

    def test_switch_features_use_contextual_progressive_disclosure(self) -> None:
        qmldir = self.source("qmldir")
        workspace = self.source("qml/features/switching/SwitchWorkspace.qml")
        ports_page = self.source("qml/features/switching/interfaces/SwitchPortsPage.qml")
        port_table = self.source("qml/features/switching/interfaces/SwitchPortTable.qml")
        inspector = self.source("qml/features/switching/interfaces/InterfaceInspector.qml")
        svi = self.source("qml/features/switching/interfaces/SviPage.qml")
        vlan = self.source("qml/features/switching/switching/VlanPage.qml")
        monitoring = self.source("qml/features/switching/monitoring/SwitchMonitoringPage.qml")

        for component in (
            "SwitchInspectorPane",
            "SwitchInspectorSection",
            "SwitchPropertyRow",
            "SwitchSummaryBar",
            "SwitchTableToolbar",
        ):
            self.assertIn(f"{component} 1.0 qml/features/switching/components/{component}.qml", qmldir)

        for token in (
            "switchPortsLoaded",
            "vlanLoaded",
            "portSecurityLoaded",
            "stormControlLoaded",
            "portCountersLoaded",
            "macTableLoaded",
            "asynchronous: true",
            "readonly property bool isViewLoading",
        ):
            self.assertIn(token, workspace)

        self.assertIn("allowCreate: !root.policyView", ports_page)
        for heading in ("Max MAC", "Violation", "Sticky", "Broadcast", "Multicast", "Unicast"):
            self.assertIn(heading, port_table)
        for field in (
            "pruning_vlans",
            "bpdufilter",
            "loop_guard",
            "aging_type",
            "aging_time",
            "storm_action",
        ):
            self.assertIn(field, inspector)
        self.assertIn("SwitchPropertyRow {", inspector)
        self.assertNotIn("FormSection {", inspector)

        for source in (ports_page, svi, vlan, monitoring):
            self.assertIn("SwitchSummaryBar {", source)
        for source in (port_table, svi, vlan, monitoring):
            self.assertIn("SwitchTableToolbar {", source)
        self.assertIn("function formatBytes(value)", monitoring)
        self.assertIn('text: "Discards"', monitoring)
        self.assertIn('text: "Errors"', monitoring)

    def test_direct_table_consumers_use_shared_primitives(self) -> None:
        consumers = {
            "qml/sidebar/new_device/BatchNewDevice.qml": (
                "DataTableFrame {", "DataTableHeader {", "delegate: DataTableRow {"
            ),
            "qml/sftp/SftpFilePanel.qml": (
                "DataTableHeader {", "delegate: DataTableRow {", "EmptyState {"
            ),
            "qml/content/DatabaseBrowserView.qml": (
                "DataTableFrame {", "DataTableHeader {", "delegate: DataTableRow {"
            ),
        }
        for relative_path, tokens in consumers.items():
            source = self.source(relative_path)
            for token in tokens:
                with self.subTest(qml=relative_path, token=token):
                    self.assertIn(token, source)


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
        self.assertIn("closePolicy: Popup.CloseOnEscape", panel)
        self.assertIn("AppAssets.navigationChevronDown", panel)
        self.assertIn("AppAssets.actionClear", panel)
        self.assertIn("AppAssets.statusDoNotDisturb", panel)
        self.assertIn("AppAssets.statusNotification", panel)
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
        self.assertIn("function dismissVisibleToasts()", main)
        self.assertIn("function canShowToast()", main)
        self.assertIn("!notificationPanel.visible", main)
        self.assertIn("doNotDisturb: root.isDoNotDisturb", main)
        self.assertIn("onToggleDndRequested: root.setDoNotDisturb", main)
        self.assertIn("showToast !== false && root.canShowToast()", main)
        self.assertIn("if (notificationPanel.visible)", main)
        self.assertIn("notificationPanel.close()", main)
        self.assertNotIn("toastManager.showToast", devices)

        self.assertIn("AppAssets.statusDoNotDisturb", status_bar)
        self.assertNotIn("bell-slash.svg", status_bar)
        self.assertIn("readonly property bool notificationShouldBlink", status_bar)
        self.assertIn("root.isDND", status_bar)
        self.assertIn("root.unreadCount > 0", status_bar)

    def test_toast_manager_suppresses_recent_visible_duplicates(self) -> None:
        toast = (self.ui_root / "qml" / "shared" / "ToastManager.qml").read_text(
            encoding="utf-8"
        )

        self.assertIn("property int duplicateSuppressionWindowMs: 3000", toast)
        self.assertIn("function hasVisibleToast(message)", toast)
        self.assertIn("function isDuplicateToast(message, now)", toast)
        self.assertIn("if (!allowDuplicate && root.isDuplicateToast", toast)
        self.assertIn('return showToast(message, "loading", true)', toast)


class ExternalToolsQmlContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.ui_source = (
            Path(__file__).resolve().parents[1]
            / "UI"
            / "qml"
            / "content"
            / "ExternalToolsSettings.qml"
        ).read_text(encoding="utf-8")
        cls.runtime_source = (
            Path(__file__).resolve().parents[1] / "core" / "external_tools.py"
        ).read_text(encoding="utf-8")
        cls.main_source = (
            Path(__file__).resolve().parents[1]
            / "UI"
            / "qml"
            / "app"
            / "Main.qml"
        ).read_text(encoding="utf-8")
        cls.feature_bar_source = (
            Path(__file__).resolve().parents[1]
            / "UI"
            / "qml"
            / "feature"
            / "FeatureBar.qml"
        ).read_text(encoding="utf-8")
        cls.device_context_menu_source = (
            Path(__file__).resolve().parents[1]
            / "UI"
            / "qml"
            / "sidebar"
            / "devices"
            / "DeviceContextMenu.qml"
        ).read_text(encoding="utf-8")

    def test_external_tools_uses_responsive_category_application_workflow(self) -> None:
        self.assertIn("SplitView {", self.ui_source)
        self.assertIn('objectName: "externalToolsMainSplit"', self.ui_source)
        self.assertIn("orientation: root.compactLayout ? Qt.Vertical : Qt.Horizontal", self.ui_source)
        self.assertIn('objectName: "externalToolCategoryList"', self.ui_source)
        self.assertIn('objectName: "externalToolsApplicationList"', self.ui_source)
        self.assertIn('objectName: "externalToolsFeatureBar"', self.ui_source)
        self.assertIn('tabs: ["Applications", "Suggestion"]', self.ui_source)
        self.assertIn('? "Current selection"', self.ui_source)
        self.assertIn('"Other configured apps" : "Suggested apps"', self.ui_source)
        self.assertIn("activeFocusOnTab: visible", self.ui_source)
        self.assertIn("Keys.onReturnPressed", self.ui_source)
        self.assertIn("Accessible.role: Accessible.ListItem", self.ui_source)
        self.assertIn("function safeText(value)", self.ui_source)
        self.assertNotIn('objectName: "externalToolType"', self.ui_source)
        self.assertIn("safeText(appName.text).trim(),\n            selectedCategory,", self.ui_source)
        self.assertIn("function activeApplicationForType(appType)", self.ui_source)
        self.assertIn('categoryRow.activeApplication + " in use"', self.ui_source)
        self.assertIn('"type": "SFTP Client"', self.ui_source)
        self.assertIn('"Built into NetworkTools"', self.ui_source)

    def test_external_tool_text_icon_actions_use_shared_button_variant(self) -> None:
        root = Path(__file__).resolve().parents[1]
        catalog = (root / "UI" / "qml" / "content" / "ExternalToolCatalogSettings.qml").read_text(encoding="utf-8")
        button = (root / "UI" / "components" / "standard" / "StandardButton.qml").read_text(encoding="utf-8")
        self.assertIn('type: "TextIcon"', self.ui_source)
        self.assertIn("AppAssets.navigationChevronRight", self.ui_source)
        self.assertIn("AppAssets.navigationChevronDown", self.ui_source)
        self.assertIn('type: "TextIcon"', catalog)
        self.assertIn("AppAssets.statusInfo", catalog)
        self.assertIn('root.type === "TextIcon"', button)

    def test_catalog_matches_category_application_and_install_state_layout(self) -> None:
        catalog = (
            Path(__file__).resolve().parents[1]
            / "UI" / "qml" / "content" / "ExternalToolCatalogSettings.qml"
        ).read_text(encoding="utf-8")
        self.assertIn('objectName: "externalToolCatalogSplit"', catalog)
        self.assertIn('objectName: "externalToolCatalogCategoryList"', catalog)
        self.assertIn('objectName: "externalToolCatalogApplicationList"', catalog)
        self.assertIn('? "In use"', catalog)
        self.assertIn('"Installed apps" : "Not installed"', catalog)
        self.assertIn("function activeApplicationForCategory(category)", catalog)
        self.assertIn('categoryRow.activeApplication + " in use"', catalog)
        self.assertIn('text: "Suggestion"', catalog)
        self.assertIn('"Built into NetworkTools"', catalog)
        self.assertIn("id: toolStatus", catalog)

    def test_detected_apps_require_review_and_are_never_auto_saved(self) -> None:
        self.assertIn("discoverExternalTools()", self.ui_source)
        self.assertIn('editorMode = row.configured ? "configured" : "detected"', self.ui_source)
        self.assertIn('editorMode === "detected"', self.ui_source)
        self.assertIn('dirty || editorMode === "detected" || editorMode === "custom"', self.ui_source)
        self.assertIn("root.saveCurrentTool()", self.ui_source)
        self.assertIn("toolsBackend.saveTool(", self.ui_source)
        self.assertNotIn("onTapped: root.saveCurrentTool()", self.ui_source)
        self.assertIn('text: enabledToggle.checked ? "Use application" : "Save"', self.ui_source)

    def test_native_browse_validation_preview_and_delete_confirmation_are_present(self) -> None:
        self.assertIn("FileDialog {", self.ui_source)
        self.assertIn("validateExecutable", self.ui_source)
        self.assertIn('nameFilters: ["Applications (*.exe *.com *.bat *.cmd)"', self.ui_source)
        self.assertIn('text: "Remove external tool?"', self.ui_source)
        self.assertIn("previewCommand()", self.ui_source)
        self.assertIn('previewArgs.replace(/\\{password\\}/gi, "[BLOCKED]")', self.ui_source)
        self.assertIn("argumentsUnsafe", self.ui_source)

    def test_windows_discovery_is_bounded_and_reports_source_confidence(self) -> None:
        self.assertIn("WINDOWS_TOOL_SPECS", self.runtime_source)
        self.assertIn("Windows App Paths", self.runtime_source)
        self.assertIn("PATH / App Execution Alias", self.runtime_source)
        self.assertIn("Windows default association", self.runtime_source)
        self.assertIn("Known install location", self.runtime_source)
        self.assertIn("Windows installed applications", self.runtime_source)
        self.assertIn("Linux default application", self.runtime_source)
        self.assertIn('("telnet", "SSH Client", True)', self.runtime_source)
        self.assertIn('("sftp", "SFTP Client", True)', self.runtime_source)
        self.assertIn('"app": "Xshell"', self.runtime_source)
        self.assertIn('"app": "MobaXterm"', self.runtime_source)
        self.assertIn('"app": "Tera Term"', self.runtime_source)
        self.assertIn('"app": "WinSCP"', self.runtime_source)
        self.assertIn('"app": "Letos"', self.runtime_source)
        self.assertIn('"confidence": confidence', self.runtime_source)
        self.assertNotIn("os.walk", self.runtime_source)
        self.assertNotIn("rglob(\"*.exe\")", self.runtime_source)

    def test_windows_default_apps_settings_remains_user_controlled(self) -> None:
        self.assertIn('Qt.openUrlExternally("ms-settings:defaultapps")', self.ui_source)
        self.assertIn("NetworkTools never changes the system default.", self.ui_source)

    def test_external_tools_and_catalog_share_one_settings_sidebar_entry(self) -> None:
        root = Path(__file__).resolve().parents[1]
        panel = (root / "UI" / "qml" / "panels" / "SettingsPanel.qml").read_text(encoding="utf-8")
        settings = (root / "UI" / "qml" / "content" / "SettingsView.qml").read_text(encoding="utf-8")
        self.assertIn('"key": "external_tools"', panel)
        self.assertNotIn('"key": "tool_catalog"', panel)
        self.assertIn("ExternalToolCatalogSettings {", self.ui_source)
        self.assertNotIn("ExternalToolCatalogSettings {", settings)

    def test_tool_catalog_is_subdued_when_missing_and_never_auto_installs(self) -> None:
        catalog_source = (
            Path(__file__).resolve().parents[1]
            / "UI"
            / "qml"
            / "content"
            / "ExternalToolCatalogSettings.qml"
        ).read_text(encoding="utf-8")
        catalog_backend = (
            Path(__file__).resolve().parents[1] / "core" / "tool_catalog.py"
        ).read_text(encoding="utf-8")

        self.assertIn("getExternalToolCatalog()", catalog_source)
        self.assertIn("Qt.openUrlExternally(", catalog_source)
        self.assertIn("Theme.textDisabled", catalog_source)
        self.assertIn("? 1.0 : 0.68", catalog_source)
        self.assertIn("does not install packages", catalog_source)
        self.assertNotIn("winget", catalog_source.casefold())
        self.assertNotIn("subprocess", catalog_backend)

    def test_feature_bar_cli_opens_the_active_device_with_external_tools(self) -> None:
        self.assertIn("function openDeviceCli(host)", self.main_source)
        self.assertIn("externalTools.openDeviceCli(targetHost)", self.main_source)
        self.assertIn(
            "onCliOpenRequested: root.openDeviceCli(deviceTabs.activeUid)",
            self.main_source,
        )
        self.assertIn(
            "onActivated: root.openDeviceCli(deviceTabs.activeUid)",
            self.main_source,
        )
        self.assertNotIn("onActivated: cli.openTerminal()", self.main_source)
        self.assertNotIn('statusBar.showMessage("Opened new Terminal"', self.main_source)
        self.assertIn('tooltip: "Open CLI with SSH Client"', self.feature_bar_source)
        self.assertIn('text: "CLI / SSH Client"', self.device_context_menu_source)


if __name__ == "__main__":
    unittest.main()
