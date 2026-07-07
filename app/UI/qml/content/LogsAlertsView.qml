pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import UI

Rectangle {
    id: logsAlertsView
    color: Theme.contentBackground

    property string activeSectionKey: "logs"

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 16

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            Text {
                text: logsAlertsView.activeSectionKey === "alerts" ? "Alerts" : "Logs"
                color: Theme.textPrimary
                font.pixelSize: Theme.fontSizeLarge
                font.family: Theme.fontFamily
                font.weight: Font.Bold
            }

            Text {
                Layout.fillWidth: true
                text: logsAlertsView.activeSectionKey === "alerts"
                      ? "Review important network and system alerts."
                      : "Review application and device operation logs."
                color: Theme.textSecondary
                font.pixelSize: Theme.fontSizeSmall
                font.family: Theme.fontFamily
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Theme.contentPanelSurface
            radius: Theme.borderRadius
            border.width: Theme.borderWidth
            border.color: Theme.contentPanelBorder

            ColumnLayout {
                anchors.centerIn: parent
                width: Math.min(parent.width - 48, 560)
                spacing: 6

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: logsAlertsView.activeSectionKey === "alerts" ? "Alerts are coming soon" : "Logs are coming soon"
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSizeNormal
                    font.family: Theme.fontFamily
                    font.weight: Font.Medium
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: logsAlertsView.activeSectionKey === "alerts"
                          ? "This area will show severity, source, and time when alerts are wired."
                          : "This area will show timestamped runtime and device events when logs are wired."
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontSizeSmall
                    font.family: Theme.fontFamily
                }
            }
        }
    }
}
