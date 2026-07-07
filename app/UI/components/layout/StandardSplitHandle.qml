pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import UI

Rectangle {
    id: root

    implicitWidth: Theme.splitHandleWidth
    implicitHeight: Theme.splitHandleWidth
    enabled: false
    color: "transparent"

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: Theme.splitHandleWidth
        color: Theme.splitHandleColor
    }
}
