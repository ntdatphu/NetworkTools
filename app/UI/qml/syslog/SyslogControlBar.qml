pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import UI

Rectangle {
    id: root
    objectName: "syslogControlBar"

    property string listenerState: "stopped"
    property string statusText: "System Logs listener is stopped."
    property int receivedCount: 0
    property int droppedCount: 0
    property bool paused: false
    readonly property bool listening: listenerState === "listening"
    readonly property bool transitioning: listenerState === "starting"
                                          || listenerState === "stopping"

    signal startRequested()
    signal stopRequested()
    signal pauseChanged(bool paused)
    signal clearRequested()

    implicitHeight: 78
    color: Theme.contentPanelSurface
    border.color: Theme.contentPanelBorder
    border.width: Theme.borderWidth
    radius: Theme.radiusSmall

    RowLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacing12
        spacing: Theme.spacing12

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing4

            RowLayout {
                spacing: Theme.spacing8

                Rectangle {
                    Layout.preferredWidth: Theme.spacing8
                    Layout.preferredHeight: Theme.spacing8
                    radius: width / 2
                    color: root.listenerState === "error" ? Theme.alertError
                         : root.listening ? Theme.alertSuccess
                         : root.transitioning ? Theme.alertWarning
                         : Theme.textDisabled
                }

                Text {
                    text: root.listening ? "Listener active"
                          : root.transitioning ? "Listener changing state"
                          : root.listenerState === "error" ? "Listener error"
                          : root.listenerState === "unavailable" ? "Backend unavailable"
                          : "Listener stopped"
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeNormal
                    font.weight: Font.DemiBold
                }

                StandardBadge {
                    text: "%1 received".arg(root.receivedCount)
                    badgeColor: Theme.alertInfoSubtle
                    textColor: Theme.textSecondary
                }

                StandardBadge {
                    visible: root.droppedCount > 0
                    text: "%1 dropped".arg(root.droppedCount)
                    badgeColor: Theme.alertWarningSubtle
                    textColor: Theme.alertWarning
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.statusText
                color: root.listenerState === "error" ? Theme.alertError : Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideRight
            }
        }

        StandardToggleButton {
            Layout.preferredWidth: 160
            text: root.paused ? "View paused" : "Live updates"
            description: root.paused ? "Resume to reload missed messages" : "Pause rendering only"
            enabled: root.listenerState !== "unavailable"
            checked: root.paused
            onToggled: root.pauseChanged(checked)
        }

        StandardButton {
            text: "Clear View"
            icon.source: AppAssets.actionClear
            type: "Secondary"
            onClicked: root.clearRequested()
        }

        StandardButton {
            text: root.transitioning
                  ? (root.listenerState === "starting" ? "Starting..." : "Stopping...")
                  : root.listening ? "Stop Listener" : "Start Listener"
            icon.source: root.listening
                         ? AppAssets.actionDisconnect
                         : AppAssets.actionConnect
            type: root.listening ? "Danger" : "Primary"
            enabled: !root.transitioning && root.listenerState !== "unavailable"
            onClicked: root.listening ? root.stopRequested() : root.startRequested()
        }
    }
}
