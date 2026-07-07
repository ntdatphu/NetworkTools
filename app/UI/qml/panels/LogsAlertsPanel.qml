pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import UI

Item {
    id: logsAlertsPanel

    property int selectedIndex: 0
    property string selectedKey: selectedIndex >= 0 && selectedIndex < items.length
                                 ? items[selectedIndex].key
                                 : "logs"
    property var items: [
        { "key": "logs", "title": "Logs", "desc": "Runtime and device operation history" },
        { "key": "alerts", "title": "Alerts", "desc": "Warnings, failures, and attention items" }
    ]

    signal logsAlertsSelected(string key)

    Rectangle {
        anchors.fill: parent
        color: Theme.panelSideBarBackground
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            color: Theme.panelSideBarBackground

            Text {
                anchors.fill: parent
                anchors.leftMargin: 16
                verticalAlignment: Text.AlignVCenter
                text: "LOGS & ALERTS"
                color: Theme.panelSideBarTextSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                font.capitalization: Font.AllUppercase
                font.weight: Font.Medium
            }

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: Theme.borderWidth
                color: Theme.panelSideBarBorderColor
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.margins: 8
            spacing: 8

            Repeater {
                model: logsAlertsPanel.items

                delegate: Rectangle {
                    required property int index
                    required property var modelData

                    Layout.fillWidth: true
                    implicitHeight: 72
                    radius: Theme.borderRadius
                    color: logsAlertsPanel.selectedIndex === index
                           ? Theme.panelSideBarItemSelected
                           : (itemHover.hovered ? Theme.panelSideBarItemHover : Theme.panelSideBarSearchBackground2)
                    border.width: Theme.borderWidth
                    border.color: Theme.panelSideBarBorderColor

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 4

                        Text {
                            text: modelData.title
                            color: Theme.panelSideBarTextPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeNormal
                            font.weight: Font.Medium
                        }

                        Text {
                            Layout.fillWidth: true
                            text: modelData.desc
                            color: Theme.panelSideBarTextSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            wrapMode: Text.WordWrap
                        }
                    }

                    HoverHandler { id: itemHover }
                    TapHandler {
                        onTapped: logsAlertsPanel.selectedIndex = index
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }
    }

    onSelectedKeyChanged: logsAlertsPanel.logsAlertsSelected(selectedKey)
    Component.onCompleted: logsAlertsPanel.logsAlertsSelected(selectedKey)
}
