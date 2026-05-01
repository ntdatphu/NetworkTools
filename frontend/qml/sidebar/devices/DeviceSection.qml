pragma ComponentBehavior: Bound

import QtQuick
import NetworkUI

Column {
    id: deviceSection

    property string sectionTitle: ""
    property bool expanded: false
    property var devices: []
    property int selectedIndex: -1
    property string displayFormat: "name"

    signal deviceClicked(int index)
    signal deviceRightClicked(string ip, string status, int mouseX, int mouseY)

    width: parent.width

    // ── Header section ──
    Rectangle {
        width: parent.width
        height: Theme.listItemHeight
        color: headerHover.hovered ? Theme.sideBarItemHover : "transparent"

        Row {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 8
            spacing: 4

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: deviceSection.expanded ? "▾" : "▸"
                font.pixelSize: 10
                color: Theme.textSecondary
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: deviceSection.sectionTitle + " (" + deviceSection.devices.length + ")"
                font.pixelSize: Theme.fontSizeSmall
                font.family: Theme.fontFamily
                font.capitalization: Font.AllUppercase
                font.weight: Font.Medium
                color: Theme.textSecondary
            }
        }

        HoverHandler { id: headerHover }
        TapHandler {
            onTapped: deviceSection.expanded = !deviceSection.expanded
        }
    }

    // ── Danh sách thiết bị ──
    Column {
        width: parent.width
        visible: deviceSection.expanded

        Repeater {
            model: deviceSection.devices
            delegate: DeviceItem {
                width: deviceSection.width
                deviceName: modelData.name
                deviceIp:   modelData.ip

                deviceType: modelData.type !== undefined ? modelData.type : ""

                status:     modelData.status
                isSelected: deviceSection.selectedIndex === index

                displayFormat: deviceSection.displayFormat

                onClicked:      deviceSection.deviceClicked(index)
                onRightClicked: (ip, mx, my) => deviceSection.deviceRightClicked(ip, modelData.status, mx, my)
            }
        }
    }
}