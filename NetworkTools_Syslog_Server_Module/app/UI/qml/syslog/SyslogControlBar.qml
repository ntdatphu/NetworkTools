import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

Rectangle {
    id: root
    property string state: "stopped"
    property string statusText: "Syslog server is stopped."
    property int receivedCount: 0
    property int droppedCount: 0
    signal startRequested()
    signal stopRequested()
    signal pauseChanged(bool paused)
    signal clearRequested()

    height: Theme.featureBarHeight
    color: Theme.featureBarBackground

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 8

        StandardButton {
            text: root.state === "listening" ? "Stop" : "Start"
            enabled: root.state !== "starting" && root.state !== "stopping"
            onClicked: root.state === "listening" ? root.stopRequested() : root.startRequested()
        }
        Text {
            Layout.fillWidth: true
            text: root.statusText
            color: root.state === "error" ? Theme.statusError : Theme.textSecondary
            elide: Text.ElideRight
            font.family: Theme.fontFamily
        }
        Text {
            text: "Received: %1  Dropped: %2".arg(root.receivedCount).arg(root.droppedCount)
            color: root.droppedCount > 0 ? Theme.statusWarning : Theme.textSecondary
            font.family: Theme.fontFamily
        }
        StandardToggleButton {
            text: checked ? "Resume UI" : "Pause UI"
            onToggled: root.pauseChanged(checked)
        }
        StandardButton { text: "Clear View"; onClicked: root.clearRequested() }
    }

    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: Theme.borderWidth; color: Theme.borderColor }
}

