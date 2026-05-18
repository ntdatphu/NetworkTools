pragma ComponentBehavior: Bound

import QtQuick
import NetworkTools

Rectangle {
    id: root

    property int rowIndex: 0
    property bool zebra: true
    property color alternateColor: Theme.searchBackground2
    property color baseColor: zebra && rowIndex % 2 !== 0 ? alternateColor : "transparent"
    default property alias content: contentHost.data

    readonly property bool hovered: rowHover.hovered

    width: parent ? parent.width : implicitWidth
    height: 36
    radius: Theme.radiusSmall
    color: hovered ? Theme.sideBarItemHover : baseColor

    Item {
        id: contentHost
        anchors.fill: parent
    }

    HoverHandler { id: rowHover }
}
