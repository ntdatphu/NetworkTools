pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import NetworkTools

Rectangle {
    id: panelSideBar
    color: Theme.sideBarBackground
    implicitWidth: 0

    // ── 1. KẾT NỐI VỚI ACTIVITY BAR ───────────────────────────────────────────
    property string appMode: "devices"

    // ── 2. CẦU NỐI (PROXY) BẢO VỆ MAIN.QML KHÔNG BỊ LỖI ───────────────────────
    // Chuyển hướng mọi yêu cầu từ Main.qml thẳng vào DevicesPanel
    property alias allDevices: devicesPanel.allDevices
    property alias pythonDepsChecking: devicesPanel.pythonDepsChecking
    property alias pythonDepsStatus: devicesPanel.pythonDepsStatus
    property alias pythonDepsStatusText: devicesPanel.pythonDepsStatusText
    property alias pythonDepsStatusDetail: devicesPanel.pythonDepsStatusDetail
    property alias backendConnectRunning: devicesPanel.isConnectRunning
    property alias selectedSection: devicesPanel.selectedSection
    property alias selectedIndex: devicesPanel.selectedIndex
    property bool hasActiveTabs: false // Main.qml đang truyền biến này vào

    signal deviceSelected(string ip, string name)
    signal deviceDeleted(string ip)
    signal devicesLoaded(var validIps)
    signal settingSelected(string key)

    function selectDeviceByIp(ip) { devicesPanel.selectDeviceByIp(ip) }
    function triggerPythonCheck() { devicesPanel.triggerPythonCheck() }
    function openNewDeviceWindow() { devicesPanel.openNewDeviceWindow() }
    function openBatchDeviceWindow() { devicesPanel.openBatchDeviceWindow() }
    function reloadDevices() { devicesPanel.reloadDevices() }

    // ── 3. CONTAINER CHUYỂN TAB ───────────────────────────────────────────────
        StackLayout {
            anchors.fill: parent

        currentIndex: {
            if (panelSideBar.appMode === "devices") return 0
            if (panelSideBar.appMode === "logs") return 1
            if (panelSideBar.appMode === "settings") return 2
            return 0
        }

        // [0] GIAO DIỆN DEVICES (Đã tách file)
        DevicesPanel {
            id: devicesPanel
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Lắng nghe tín hiệu từ DevicesPanel và phát ngược lên Main.qml
            onDeviceSelected: (ip, name) => panelSideBar.deviceSelected(ip, name)
            onDeviceDeleted: (ip) => panelSideBar.deviceDeleted(ip)
            onDevicesLoaded: (validIps) => panelSideBar.devicesLoaded(validIps)
        }

        // [1] GIAO DIỆN LOGS & ALERTS
        LogsAlertsPanel {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        // [2] GIAO DIỆN SETTINGS
        SettingsPanel {
            id: settingsPanel
            Layout.fillWidth: true
            Layout.fillHeight: true
            onSettingSelected: function(key) {
                panelSideBar.settingSelected(key)
            }
        }
    }
}
