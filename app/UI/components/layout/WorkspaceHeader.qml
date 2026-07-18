pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import UI

Item {
    id: root

    property string title: ""
    property string subtitle: ""
    default property alias actions: actionLayout.data

    implicitHeight: Math.max(titleLayout.implicitHeight, actionLayout.implicitHeight)

    RowLayout {
        anchors.fill: parent
        spacing: Theme.spacing12

        ColumnLayout {
            id: titleLayout
            Layout.fillWidth: true
            spacing: Theme.spacing2

            Text {
                Layout.fillWidth: true
                text: root.title
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLarge
                font.bold: true
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                visible: root.subtitle !== ""
                text: root.subtitle
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideRight
            }
        }

        RowLayout {
            id: actionLayout
            spacing: Theme.spacing8
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
        }
    }
}
