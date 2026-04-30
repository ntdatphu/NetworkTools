pragma ComponentBehavior: Bound

import QtQuick
import NetworkUI

Rectangle {
    id: filterDropdown

    property var activeStatusFilters: []
    property var activeTypeFilters: []

    signal filtersChanged()

    visible: false
    width: 200
    color: Theme.contentBackground
    border.color: Theme.borderColor
    border.width: Theme.borderWidth
    radius: 4

    // Tính height tự động theo nội dung
    height: filterColumn.implicitHeight + 16

    function toggle() { visible = !visible }

    Column {
        id: filterColumn
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 8
        spacing: 4

        // ── Lọc theo trạng thái ──
        Text {
            text: "STATUS"
            font.pixelSize: Theme.fontSizeSmall
            font.family: Theme.fontFamily
            font.weight: Font.Medium
            color: Theme.textSecondary
            topPadding: 4
        }

        Repeater {
            model: [
                { label: "Connected",    value: "connected",    color: Theme.statusConnected    },
                { label: "Waiting",      value: "waiting",      color: Theme.statusWaiting      },
                { label: "Disconnected", value: "disconnected", color: Theme.statusDisconnected }
            ]

            delegate: Rectangle {
                required property var modelData

                width: parent.width
                height: 30
                radius: 4
                color: filterItemHover.containsMouse ? Theme.sideBarItemHover : "transparent"

                property bool isChecked: filterDropdown.activeStatusFilters.indexOf(modelData.value) !== -1

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    spacing: 8

                    // Checkbox
                    Rectangle {
                        width: 14
                        height: 14
                        radius: 3
                        border.color: Theme.borderColor
                        color: isChecked ? Theme.accentColor : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "✓"
                            font.pixelSize: 10
                            color: Theme.buttonTextSolid
                            visible: isChecked
                        }
                    }

                    // Status dot
                    Rectangle {
                        width: 8
                        height: 8
                        radius: 4
                        anchors.verticalCenter: parent.verticalCenter
                        color: modelData.color
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        font.pixelSize: Theme.fontSizeNormal
                        font.family: Theme.fontFamily
                        color: Theme.textPrimary
                    }
                }

                HoverHandler { id: filterItemHover }
                TapHandler {
                    onTapped: {
                        const filters = filterDropdown.activeStatusFilters.slice()
                        const idx = filters.indexOf(modelData.value)
                        if (idx === -1) filters.push(modelData.value)
                        else filters.splice(idx, 1)
                        filterDropdown.activeStatusFilters = filters
                        filterDropdown.filtersChanged()
                    }
                }
            }
        }

        // Divider
        Rectangle {
            width: parent.width
            height: Theme.borderWidth
            color: Theme.borderColor
        }

        // ── Lọc theo loại thiết bị ──
        Text {
            text: "DEVICE TYPE"
            font.pixelSize: Theme.fontSizeSmall
            font.family: Theme.fontFamily
            font.weight: Font.Medium
            color: Theme.textSecondary
            topPadding: 4
        }

        Repeater {
            model: ["Router", "Switch", "Access Point", "Firewall", "Server"]

            delegate: Rectangle {
                required property var modelData

                width: parent.width
                height: 30
                radius: 4
                color: typeItemHover.containsMouse ? Theme.sideBarItemHover : "transparent"

                property bool isChecked: filterDropdown.activeTypeFilters.indexOf(modelData) !== -1

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    spacing: 8

                    Rectangle {
                        width: 14
                        height: 14
                        radius: 3
                        border.color: Theme.borderColor
                        color: isChecked ? Theme.accentColor : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "✓"
                            font.pixelSize: 10
                            color: Theme.buttonTextSolid
                            visible: isChecked
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData
                        font.pixelSize: Theme.fontSizeNormal
                        font.family: Theme.fontFamily
                        color: Theme.textPrimary
                    }
                }

                HoverHandler { id: typeItemHover }
                TapHandler {
                    onTapped: {
                        var filters = filterDropdown.activeTypeFilters.slice()
                        var idx = filters.indexOf(modelData)
                        if (idx === -1) filters.push(modelData)
                        else filters.splice(idx, 1)
                        filterDropdown.activeTypeFilters = filters
                        filterDropdown.filtersChanged()
                    }
                }
            }
        }
    }
}
