pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import NetworkTools

Rectangle {
    id: root

    property string title: ""
    property int count: 0
    property string emptyText: ""
    property color countColor: Theme.accentColor
    property Component headerComponent: null
    default property alias content: contentHost.data

    color: Theme.contentBackground

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacing24
        anchors.topMargin: Theme.spacing16
        spacing: Theme.spacing12

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: root.title
                color: Theme.textPrimary
                font.pixelSize: Theme.fontSizeLarge
                font.family: Theme.fontFamily
                font.bold: true
            }

            StandardBadge {
                text: String(root.count)
                badgeColor: root.countColor
                textColor: Theme.buttonTextSolid
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: Theme.spacing8
            }

            Item { Layout.fillWidth: true }
        }

        Rectangle {
            Layout.fillWidth: true
            height: Theme.borderWidth
            color: Theme.splitHandleColor
        }

        Loader {
            Layout.fillWidth: true
            Layout.topMargin: Theme.spacing2
            active: root.headerComponent !== null
            sourceComponent: root.headerComponent
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Text {
                anchors.centerIn: parent
                visible: root.count === 0
                text: root.emptyText
                color: Theme.textDisabled
                font.pixelSize: Theme.fontSizeNormal
                font.family: Theme.fontFamily
                horizontalAlignment: Text.AlignHCenter
                lineHeight: 1.6
            }

            Item {
                id: contentHost
                anchors.fill: parent
            }
        }
    }
}
