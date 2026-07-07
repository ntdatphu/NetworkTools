pragma ComponentBehavior: Bound

import QtQuick
import UI

Rectangle {
    id: root

    property int rowIndex: 0
    property bool zebra: true
    property color alternateColor: Theme.sideBarBackground
    property color baseColor: zebra && rowIndex % 2 !== 0 ? alternateColor : Theme.contentSurface
    default property alias content: contentHost.data

    readonly property bool hovered: rowHover.hovered

    width: parent ? parent.width : implicitWidth
    height: 36
    radius: Theme.radiusSmall
    color: hovered ? Theme.sideBarItemHover : baseColor
    border.color: hovered ? Theme.inputBorderColor : Theme.borderColor
    border.width: Theme.borderWidth

    Item {
        id: contentHost
        anchors.fill: parent
    }

    HoverHandler { id: rowHover }
}
