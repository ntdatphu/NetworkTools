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
    readonly property bool wideLayout: width >= 900
    readonly property bool twoColumnLayout: !wideLayout && width >= 480

    signal startRequested()
    signal stopRequested()
    signal pauseChanged(bool paused)
    signal clearRequested()

    implicitHeight: controlLayout.implicitHeight + Theme.spacing24
    color: Theme.contentPanelSurface
    border.color: Theme.contentPanelBorder
    border.width: Theme.borderWidth
    radius: Theme.radiusSmall

    GridLayout {
        id: controlLayout
        objectName: "syslogControlLayout"
        anchors.fill: parent
        anchors.margins: Theme.spacing12
        columns: root.wideLayout ? 4 : (root.twoColumnLayout ? 2 : 1)
        columnSpacing: Theme.spacing12
        rowSpacing: Theme.spacing12

        ColumnLayout {
            Layout.row: 0
            Layout.column: 0
            Layout.columnSpan: root.wideLayout ? 1 : controlLayout.columns
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            spacing: Theme.spacing4

            RowLayout {
                Layout.fillWidth: true
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
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: root.listening ? "Listener active"
                          : root.transitioning ? "Listener changing state"
                          : root.listenerState === "error" ? "Listener error"
                          : root.listenerState === "unavailable" ? "Backend unavailable"
                          : "Listener stopped"
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeNormal
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
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
            objectName: "syslogLiveUpdatesToggle"
            Layout.row: root.wideLayout ? 0 : 1
            Layout.column: root.wideLayout ? 1 : 0
            Layout.fillWidth: !root.wideLayout
            Layout.preferredWidth: root.wideLayout ? 160 : 180
            text: root.paused ? "View paused" : "Live updates"
            description: root.paused ? "Resume to reload missed messages" : "Pause rendering only"
            enabled: root.listenerState !== "unavailable"
            checked: root.paused
            onToggled: root.pauseChanged(checked)
        }

        StandardButton {
            objectName: "syslogClearViewButton"
            Layout.row: root.wideLayout ? 0 : (root.twoColumnLayout ? 1 : 2)
            Layout.column: root.wideLayout ? 2 : (root.twoColumnLayout ? 1 : 0)
            Layout.fillWidth: !root.wideLayout
            text: "Clear View"
            icon.source: AppAssets.actionClear
            type: "Secondary"
            tooltip: "Clear displayed System Log messages"
            onClicked: root.clearRequested()
        }

        StandardButton {
            objectName: "syslogListenerButton"
            Layout.row: root.wideLayout ? 0 : (root.twoColumnLayout ? 2 : 3)
            Layout.column: root.wideLayout ? 3 : 0
            Layout.columnSpan: root.twoColumnLayout ? 2 : 1
            Layout.fillWidth: !root.wideLayout
            text: root.transitioning
                  ? (root.listenerState === "starting" ? "Starting..." : "Stopping...")
                  : root.listening ? "Stop Listener" : "Start Listener"
            icon.source: root.listening
                         ? AppAssets.actionDisconnect
                         : AppAssets.actionConnect
            tooltip: root.listening ? "Stop System Log listener"
                                    : "Start System Log listener"
            type: root.listening ? "Danger" : "Primary"
            enabled: !root.transitioning && root.listenerState !== "unavailable"
            onClicked: root.listening ? root.stopRequested() : root.startRequested()
        }
    }
}
