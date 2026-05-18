pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import NetworkTools

Rectangle {
    id: root

    implicitWidth: Theme.splitHandleHitWidth + 1
    implicitHeight: Theme.splitHandleHitWidth + 1
    color: SplitHandle.hovered || SplitHandle.pressed
           ? Theme.accentColor
           : Theme.borderColor

    Column {
        anchors.centerIn: parent
        spacing: 3

        Repeater {
            model: 3

            Rectangle {
                width: 2
                height: 2
                radius: 1
                color: SplitHandle.hovered || SplitHandle.pressed
                       ? Theme.buttonTextSolid
                       : Theme.textDisabled
            }
        }
    }
}
