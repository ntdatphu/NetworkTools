pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import NetworkUI

// ── AclSubBar ────────────────────────────────────────────────────────────────
// Thanh tab con để chuyển đổi giữa các loại ACL.
// Cấu trúc và hành vi nhất quán với RoutingSubBar và DhcpSubBar.
// ─────────────────────────────────────────────────────────────────────────────
Rectangle {
    id: aclSubBar

    property string activeTab: "Standard"
    readonly property var tabs: ["Standard", "Extended", "Dynamic", "Reflexive", "MAC"]

    signal tabClicked(string tabName)

    width:  parent.width
    height: Theme.subBarHeight
    color:  Theme.sideBarBackground

    Row {
        anchors.left:           parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin:     0
        spacing:                0

        Repeater {
            model: aclSubBar.tabs

            delegate: Rectangle {
                required property var modelData

                id: tabItem

                readonly property bool isActive: modelData === aclSubBar.activeTab

                width:  tabLabel.implicitWidth + 28
                height: aclSubBar.height

                color: isActive          ? Theme.sideBarItemSelected :
                       tabHover.hovered  ? Theme.sideBarItemHover    : "transparent"

                // ── Vạch dọc bên trái khi active — nhất quán với RoutingSubBar ──
                Rectangle {
                    width:   3
                    height:  parent.height
                    anchors.left: parent.left
                    color:   Theme.accentColor
                    opacity: tabItem.isActive ? 1.0 : 0.0

                    Behavior on opacity {
                        NumberAnimation { duration: Theme.animationDurationMedium }
                    }
                }

                Text {
                    id:               tabLabel
                    anchors.centerIn: parent
                    // ── Dịch phải nhẹ để bù vạch dọc bên trái khi active ──
                    anchors.horizontalCenterOffset: tabItem.isActive ? 1.5 : 0
                    text:             modelData
                    font.pixelSize:   Theme.fontSizeNormal
                    font.family:      Theme.fontFamily
                    font.bold:        tabItem.isActive
                    color:            tabItem.isActive
                                          ? Theme.textPrimary
                                          : Theme.textSecondary

                    Behavior on color {
                        ColorAnimation { duration: Theme.animationDurationMedium }
                    }
                    Behavior on anchors.horizontalCenterOffset {
                        NumberAnimation { duration: Theme.animationDurationMedium }
                    }
                }

                HoverHandler { id: tabHover }
                TapHandler   { onTapped: aclSubBar.tabClicked(modelData) }
            }
        }
    }

    // ── Đường viền dưới nhất quán với các SubBar khác ──
    Rectangle {
        anchors.bottom: parent.bottom
        width:          parent.width
        height:         Theme.borderWidth
        color:          Theme.borderColor
    }
}