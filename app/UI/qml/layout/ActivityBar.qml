pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import UI

Rectangle {
    id: activityBar
    color: Theme.activityBarBackground

    property int activeIndex: 0
    property string appMode: "devices"

    // ── Signals ───────────────────────────────────────────────────────────────

    // Signal toggle sidebar — phát khi click vào item đang active
    // Main.qml lắng nghe để show/hide PanelSideBar
    signal toggleSidebarRequested()
    signal showSidebarRequested()

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
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter

        ActivityBarItem {
            iconSource:  AppAssets.resource("resources/activitybar/dashboard.svg")
            tooltipText: "Dashboard"
            isActive:    activityBar.activeIndex === 0

            onClicked: activityBar.handleItemClick(0, "devices")
        }

        ActivityBarItem {
            iconSource:  AppAssets.resource("resources/activitybar/devices.svg")
            tooltipText: "Devices (Coming soon)"
            isActive:    false
            enabled:     false
            opacity:     0.35
        }

        ActivityBarItem {
            iconSource:  AppAssets.resource("resources/activitybar/topology.svg")
            tooltipText: "Topology (Coming soon)"
            isActive:    false
            enabled:     false
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
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter

        ActivityBarItem {
            iconSource:  AppAssets.resource("resources/activitybar/logs-alerts.svg")
            tooltipText: "Logs & Alerts"
            isActive:    activityBar.activeIndex === 3

            onClicked: activityBar.handleItemClick(3, "logs")
        }

        ActivityBarItem {
            iconSource:  AppAssets.resource("resources/activitybar/settings.svg")
            tooltipText: "Settings"
            isActive:    activityBar.activeIndex === 4

            onClicked: activityBar.handleItemClick(4, "settings")
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
