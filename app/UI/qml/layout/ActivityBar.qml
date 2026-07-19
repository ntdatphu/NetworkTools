pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import UI

Rectangle {
    id: activityBar
    color: Theme.activityBarBackground

    property int activeIndex: 0
    property string appMode: "devices"
    readonly property var toolsBackend: typeof externalTools !== "undefined" && externalTools !== null
                                        ? externalTools
                                        : null
    readonly property bool canActivateDatabase: toolsBackend !== null

    // ── Signals ───────────────────────────────────────────────────────────────

    // Signal toggle sidebar — phát khi click vào item đang active
    // Main.qml lắng nghe để show/hide PanelSideBar
    signal toggleSidebarRequested()
    signal showSidebarRequested()
    signal databaseOpenMessage(string message, string type)

    // ── Hàm xử lý click item ─────────────────────────────────────────────────
    // Trả về true nếu đã toggle sidebar (item đang active được click lại)
    // Trả về false nếu chuyển sang tab mới
    function handleItemClick(index, mode) {
        if (activityBar.activeIndex === index && activityBar.appMode === mode) {
            // Click vào item đang active → toggle sidebar
            activityBar.toggleSidebarRequested()
        } else {
            // Click vào item khác → chuyển tab bình thường
            activityBar.activeIndex = index
            activityBar.appMode = mode
            activityBar.showSidebarRequested()
        }
    }

    function selectItem(index, mode) {
        activityBar.activeIndex = index
        activityBar.appMode = mode
        activityBar.showSidebarRequested()
        return true
    }

    function activateDevices() {
        return activityBar.selectItem(0, "devices")
    }

    function activateSettings() {
        return activityBar.selectItem(2, "settings")
    }

    function activateDatabase(toggleSidebarWhenActive) {
        if (!activityBar.canActivateDatabase)
            return false
        const result = activityBar.toolsBackend.openDeviceDatabase()
        activityBar.databaseOpenMessage(result.message || "", result.ok ? "info" : "warning")
        if (result.mode === "default") {
            if (toggleSidebarWhenActive === true)
                activityBar.handleItemClick(1, "database")
            else
                activityBar.selectItem(1, "database")
        }
        return result.ok !== false
    }

    // ── Icons Khối Trên (Điều hướng chính) ───────────────────────────────────
    Column {
        id: topGroup
        objectName: "activityTopGroup"
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter

        ActivityBarItem {
            iconSource:  AppAssets.navigationDashboard
            tooltipText: "Dashboard"
            isActive:    activityBar.activeIndex === 0

            onClicked: activityBar.handleItemClick(0, "devices")
        }

        ActivityBarItem {
            iconSource:  AppAssets.navigationTopology
            tooltipText: "Topology (Coming soon)"
            isActive:    false
            enabled:     false
            opacity:     0.35
        }

        // Console Serial remains reserved until its UI contract is implemented.
        ActivityBarItem {
            objectName:  "consoleSerialActivityItem"
            iconSource:  AppAssets.navigationConsoleSerial
            tooltipText: "Console Serial (Coming soon)"
            enabled:     false
            isActive:    false
            opacity:     0.35
        }

        ActivityBarItem {
            objectName:  "sftpActivityItem"
            iconSource:  AppAssets.navigationSftp
            tooltipText: "SFTP"
            enabled:     true
            isActive:    activityBar.activeIndex === 3
            opacity:     1.0

            onClicked: activityBar.handleItemClick(3, "sftp")
        }

        ActivityBarItem {
            objectName: "syslogActivityItem"
            iconSource: AppAssets.navigationSyslog
            tooltipText: "System Logs"
            enabled: true
            isActive: activityBar.appMode === "syslog"
            opacity: 1.0

            onClicked: activityBar.handleItemClick(4, "syslog")
        }

    }

    // ── Separator giữa top và bottom group ───────────────────────────────────
    Rectangle {
        anchors.bottom: bottomGroup.top
        anchors.bottomMargin: 4
        anchors.horizontalCenter: parent.horizontalCenter
        width:  Theme.activityBarWidth - 16
        height: Theme.borderWidth
        color:  Theme.activityBarBorderColor
        opacity: 0.6
    }

    // ── Icons Khối Dưới (Hệ thống & Cài đặt) ─────────────────────────────────
    Column {
        id: bottomGroup
        objectName: "activityBottomGroup"
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter

        ActivityBarItem {
            objectName:  "databaseActivityItem"
            iconSource:  AppAssets.navigationDatabase
            tooltipText: "Database"
            isActive:    activityBar.activeIndex === 1
            enabled:     activityBar.canActivateDatabase
            opacity:     enabled ? 1.0 : 0.35

            onClicked: {
                activityBar.activateDatabase(true)
            }
        }

        ActivityBarItem {
            objectName:  "settingsActivityItem"
            iconSource:  AppAssets.navigationSettings
            tooltipText: "Settings"
            isActive:    activityBar.activeIndex === 2

            onClicked: activityBar.handleItemClick(2, "settings")
        }
    }

    // ── Đường viền phải ───────────────────────────────────────────────────────
    Rectangle {
        anchors.right:  parent.right
        width:          Theme.borderWidth
        height:         parent.height
        color:          Theme.activityBarBorderColor
    }
}
