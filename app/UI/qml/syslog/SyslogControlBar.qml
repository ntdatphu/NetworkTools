import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

Rectangle {
    id: root
    property string listenerState: "stopped"
    property string statusText: "Syslog server is stopped."
    property int receivedCount: 0
    property int droppedCount: 0
    signal startRequested()
    signal stopRequested()
    signal pauseChanged(bool paused)
    signal clearRequested()

    implicitHeight: Theme.featureBarHeight + 8
    color: Theme.featureBarBackground

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 8

        StandardButton {
            text: root.listenerState === "listening" ? "Stop" : "Start"
            enabled: root.listenerState !== "starting" && root.listenerState !== "stopping"
            onClicked: root.listenerState === "listening" ? root.stopRequested() : root.startRequested()
        }
        Text {
            Layout.fillWidth: true
            text: root.statusText
            color: root.listenerState === "error" ? Theme.alertError : Theme.textSecondary
            elide: Text.ElideRight
            font.family: Theme.fontFamily
        }
        Text {
            text: "Received: %1  Dropped: %2".arg(root.receivedCount).arg(root.droppedCount)
            color: root.droppedCount > 0 ? Theme.alertWarning : Theme.textSecondary
            font.family: Theme.fontFamily
        }
        StandardToggleButton {
            Layout.preferredWidth: 115
            text: checked ? "Resume UI" : "Pause UI"
            onToggled: root.pauseChanged(checked)
        }
        StandardButton { text: "Clear View"; onClicked: root.clearRequested() }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: Theme.borderWidth
        color: Theme.borderColor
    }
}
