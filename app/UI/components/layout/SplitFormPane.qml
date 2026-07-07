pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import UI

Rectangle {
    id: root

    default property alias content: paneLayout.data
    property alias spacing: paneLayout.spacing
    property int paneMargins: Theme.spacing24
    property int paneTopMargin: Theme.spacing16

    color: Theme.contentBackground

    ColumnLayout {
        id: paneLayout
        anchors.fill: parent
        anchors.margins: root.paneMargins
        anchors.topMargin: root.paneTopMargin
        spacing: 14
    }
}
