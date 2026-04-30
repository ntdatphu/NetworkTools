pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import NetworkUI

Rectangle {
    id: routingSubBar

    property string activeTab: "Info"
    readonly property var tabs: ["Info", "Static", "OSPF", "EIGRP", "BGP"]

    signal tabClicked(string tabName)

    width:  parent.width
    height: 36
    color:  Theme.sideBarBackground

    Row {
        anchors.left:           parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin:     0
        spacing:                0

        Repeater {
            model: routingSubBar.tabs

            delegate: Rectangle {
                required property var modelData

                id: tabItem

                readonly property bool isActive: modelData === routingSubBar.activeTab

                width:  tabLabel.implicitWidth + 28
                height: routingSubBar.height

                // Màu nền y chang DeviceItem
                color: isActive        ? Theme.sideBarItemSelected :
                       tabHover.hovered ? Theme.sideBarItemHover    : "transparent"

                // Vạch dọc bên trái khi active — y chang DeviceItem
                Rectangle {
                    width:  3
                    height: parent.height
                    anchors.left: parent.left
                    color:   Theme.accentColor
                    opacity: tabItem.isActive ? 1.0 : 0.0

                    Behavior on opacity {
                        NumberAnimation { duration: Theme.animationDurationMedium }
                    }
                }

                // Nhãn tab
                Text {
                    id:               tabLabel
                    anchors.centerIn: parent
                    // Dịch sang phải 1.5px để bù vạch dọc bên trái
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
                TapHandler   { onTapped: routingSubBar.tabClicked(modelData) }
            }
        }
    }

    // Đường viền dưới
    Rectangle {
        anchors.bottom: parent.bottom
        width:          parent.width
        height:         Theme.borderWidth
        color:          Theme.borderColor
    }
}