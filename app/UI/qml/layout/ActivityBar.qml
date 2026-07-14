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

    // ── Icons Khối Trên (Điều hướng chính) ───────────────────────────────────
    Column {
        id: topGroup
        objectName: "activityTopGroup"
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter

        ActivityBarItem {
            iconSource:  AppAssets.resource("resources/activitybar/dashboard.svg")
            tooltipText: "Dashboard"
            isActive:    activityBar.activeIndex === 0

            onClicked: activityBar.handleItemClick(0, "devices")
        }

        ActivityBarItem {
            iconSource:  AppAssets.resource("resources/activitybar/topology.svg")
            tooltipText: "Topology (Coming soon)"
            isActive:    false
            enabled:     false
            opacity:     0.35
        }

        // Reserved operation entries. Keep these out of layout/navigation until
        // their UI contracts are implemented; SVG assets alone are not features.
        ActivityBarItem {
            objectName:  "consoleSerialActivityItem"
            iconSource:  AppAssets.resource("resources/activitybar/console_serial.svg")
            tooltipText: "Console Serial (Coming soon)"
            enabled:     false
            isActive:    false
            opacity:     0.35
        }

        ActivityBarItem {
            objectName:  "logsActivityItem"
            iconSource:  AppAssets.resource("resources/activitybar/logs.svg")
            tooltipText: "Device Logs (Coming soon)"
            enabled:     false
            isActive:    false
            opacity:     0.35
        }

        ActivityBarItem {
            objectName:  "sftpActivityItem"
            iconSource:  AppAssets.resource("resources/activitybar/sftp.svg")
            tooltipText: "SFTP (Coming soon)"
            enabled:     false
            isActive:    false
            opacity:     0.35
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
            iconSource:  AppAssets.resource("resources/activitybar/database.svg")
            tooltipText: "Database"
            isActive:    activityBar.activeIndex === 1
            enabled:     activityBar.toolsBackend !== null
            opacity:     enabled ? 1.0 : 0.35

            onClicked: {
                if (activityBar.toolsBackend === null)
                    return
                const result = activityBar.toolsBackend.openDeviceDatabase()
                activityBar.databaseOpenMessage(result.message || "", result.ok ? "info" : "warning")
                if (result.mode === "default")
                    activityBar.handleItemClick(1, "database")
            }
        }

        ActivityBarItem {
            objectName:  "settingsActivityItem"
            iconSource:  AppAssets.resource("resources/activitybar/settings.svg")
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
