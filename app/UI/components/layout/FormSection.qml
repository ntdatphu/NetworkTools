pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import UI

Rectangle {
    id: root

    property string title: ""
    default property alias content: body.data

    implicitHeight: layout.implicitHeight + Theme.spacing16 * 2
    color: Theme.contentPanelSurface
    border.color: Theme.contentPanelBorder
    border.width: Theme.borderWidth
    radius: Theme.radiusMedium

    ColumnLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: Theme.spacing16
        spacing: Theme.spacing12

        Text {
            text: root.title
            color: Theme.textPrimary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeNormal
            font.bold: true
        }

        ColumnLayout {
            id: body
            Layout.fillWidth: true
            spacing: Theme.spacing8
        }
    }
}
