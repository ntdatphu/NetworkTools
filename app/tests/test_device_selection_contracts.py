from __future__ import annotations

from pathlib import Path
import unittest


class DeviceSelectionContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        root = Path(__file__).resolve().parents[1]
        cls.panel = (root / "UI/qml/panels/DevicesPanel.qml").read_text(encoding="utf-8")
        cls.section = (root / "UI/qml/sidebar/devices/DeviceSection.qml").read_text(encoding="utf-8")
        cls.item = (root / "UI/qml/sidebar/devices/DeviceItem.qml").read_text(encoding="utf-8")
        cls.menu = (root / "UI/qml/sidebar/devices/DeviceContextMenu.qml").read_text(encoding="utf-8")
        cls.tabs = (root / "UI/qml/devices/DeviceTabs.qml").read_text(encoding="utf-8")

    def test_business_selection_is_host_based(self) -> None:
        self.assertIn('property string activeHost: ""', self.panel)
        self.assertIn("property var selectedHosts: ({})", self.panel)
        self.assertNotIn("property int selectedSection", self.panel)
        self.assertNotIn("property int selectedIndex", self.panel)
        self.assertIn("signal deviceActivated(string host)", self.section)
        self.assertIn("modelData.ip", self.section)
        self.assertNotIn("CheckBox {", self.panel + self.section)
        self.assertNotIn("DeviceBatchActionBar", self.panel)
        self.assertIn('property bool multiSelectMode: false', self.panel)
        self.assertIn("function startMultipleSelection(host)", self.panel)
        self.assertIn('text: "Select multiple"', self.menu)
        self.assertIn("if (multiSelectMode)", self.panel)
        self.assertIn(
            "activeBatchExitsMultipleSelection = multiSelectMode",
            self.panel,
        )
        self.assertIn(
            "if (exitMultipleSelection)",
            self.panel,
        )
        self.assertIn(
            "enabled: deviceItem.selectionMode || !deviceItem.blockedByStatus",
            self.item,
        )
        self.assertNotIn("modifiers & Qt.ShiftModifier", self.panel)

    def test_context_target_is_snapshotted_and_tabs_do_not_close_sessions(self) -> None:
        self.assertIn("function openForHost(host, status, selectedHosts, x, y)", self.menu)
        self.assertIn("targetHost = String(host || \"\")", self.menu)
        self.assertNotIn("closeSessionForTab", self.tabs)
        self.assertNotIn("cli.closeDeviceSession", self.tabs)

    def test_unfinished_scp_running_config_is_hidden_from_device_menu(self) -> None:
        self.assertIn('text: "Get running-config via SCP"', self.menu)
        marker = self.menu.index('text: "Get running-config via SCP"')
        item_start = self.menu.rfind("ContextMenuItem {", 0, marker)
        item_end = self.menu.index("ContextMenuItem {", marker)
        item = self.menu[item_start:item_end]
        self.assertIn("visible: false", item)
        self.assertIn(
            "chuc nang chua phat trien xong, khong tam quan tam nieu viet bao cao",
            item,
        )


if __name__ == "__main__":
    unittest.main()
