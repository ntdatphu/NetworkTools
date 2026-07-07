pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import UI

Item {
    id: root

    property string iconSource: ""
    property int iconSize: Theme.iconSizeNormal
    property color iconColor: Theme.textPrimary

    implicitWidth: iconSize
    implicitHeight: iconSize
    width: iconSize
    height: iconSize

    Button {
        visible: root.iconSource !== ""
        anchors.centerIn: parent
        width: root.iconSize
        height: root.iconSize
        padding: 0
        enabled: false
        background: Item {}

        icon.source: root.iconSource
        icon.width: root.iconSize
        icon.height: root.iconSize
        icon.color: root.iconColor
    }
}
