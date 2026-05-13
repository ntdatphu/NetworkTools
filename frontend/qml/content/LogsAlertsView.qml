pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import NetworkTools

Rectangle {
    id: logsAlertsView
    color: Theme.contentBackground

    property int activeTab: 0  // 0=Logs, 1=Alerts

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Tab Bar
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            color: Theme.tabBarBackground

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                spacing: 24

                // Logs Tab
                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    width: 80
                    height: 32
                    color: logsAlertsView.activeTab === 0 ? Theme.tabActive : (logsTabHover.hovered ? Theme.tabHover : "transparent")
                    radius: Theme.borderRadius

                    Text {
                        anchors.centerIn: parent
                        text: "Logs"
                        color: logsAlertsView.activeTab === 0 ? Theme.textPrimary : Theme.textSecondary
                        font.pixelSize: Theme.fontSizeNormal
                        font.family: Theme.fontFamily
                        font.weight: Font.Medium
                    }

                    HoverHandler { id: logsTabHover }
                    TapHandler {
                        onTapped: logsAlertsView.activeTab = 0
                    }
                }

                // Alerts Tab
                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    width: 80
                    height: 32
                    color: logsAlertsView.activeTab === 1 ? Theme.tabActive : (alertsTabHover.hovered ? Theme.tabHover : "transparent")
                    radius: Theme.borderRadius

                    Text {
                        anchors.centerIn: parent
                        text: "Alerts"
                        color: logsAlertsView.activeTab === 1 ? Theme.textPrimary : Theme.textSecondary
                        font.pixelSize: Theme.fontSizeNormal
                        font.family: Theme.fontFamily
                        font.weight: Font.Medium
                    }

                    HoverHandler { id: alertsTabHover }
                    TapHandler {
                        onTapped: logsAlertsView.activeTab = 1
                    }
                }

                Item { Layout.fillWidth: true }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: Theme.borderWidth
                color: Theme.borderColor
            }
        }

        // Content
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Logs Placeholder
            Text {
                visible: logsAlertsView.activeTab === 0
                anchors.centerIn: parent
                text: "📋 Logs (Coming soon)"
                color: Theme.textSecondary
                font.pixelSize: Theme.fontSizeNormal
                font.family: Theme.fontFamily
            }

            // Alerts Placeholder
            Text {
                visible: logsAlertsView.activeTab === 1
                anchors.centerIn: parent
                text: "⚠️ Alerts (Coming soon)"
                color: Theme.textSecondary
                font.pixelSize: Theme.fontSizeNormal
                font.family: Theme.fontFamily
            }
        }
    }
}
