pragma ComponentBehavior: Bound

import QtQuick
import NetworkTools

Rectangle {
    id: root

    default property alias content: contentHost.data

    width: parent ? parent.width : implicitWidth
    height: 32
    radius: Theme.radiusSmall
    color: Theme.contentSurface
    border.color: Theme.contentPanelBorder
    border.width: Theme.borderWidth

    Item {
        id: contentHost
        anchors.fill: parent
        anchors.topMargin: 7
        anchors.bottomMargin: 7
    }
}
