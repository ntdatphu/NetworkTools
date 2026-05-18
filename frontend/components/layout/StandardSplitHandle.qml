pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import NetworkTools

Rectangle {
    id: root

    implicitWidth: Theme.splitHandleHitWidth
    implicitHeight: Theme.splitHandleHitWidth
    color: "transparent"

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: Theme.splitHandleWidth
        color: SplitHandle.hovered || SplitHandle.pressed
               ? Theme.splitHandleHoverColor
               : Theme.splitHandleColor
    }

    Column {
        anchors.centerIn: parent
        spacing: 3
        visible: SplitHandle.hovered || SplitHandle.pressed

        Repeater {
            model: 3

            Rectangle {
                width: 2
                height: 2
                radius: 1
                color: Theme.accentColor
            }
        }
    }
}
