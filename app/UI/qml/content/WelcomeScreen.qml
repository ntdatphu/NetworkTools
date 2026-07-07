pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

Rectangle {
    id: root
    color: Theme.contentBackground

    Column {
        anchors.centerIn: parent
        spacing: 24

        // Logo nhạt màu
        Button {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 120; height: 120; padding: 0
            icon.source: AppAssets.resource("resources/icons/logo.svg")
            icon.width: 120; icon.height: 120
            icon.color: Theme.textDisabled
            opacity: 0.3
            background: Item {}
            enabled: false
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "NetworkTools"
            color: Theme.textDisabled
            font.pixelSize: 32
            font.family: Theme.fontFamily
            font.bold: true
            opacity: 0.4
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Ctrl+N to add New Device\nOr select a device on the side bar to start"
            color: Theme.textDisabled
            font.pixelSize: 15
            font.family: Theme.fontFamily
            horizontalAlignment: Text.AlignHCenter
            opacity: 0.6
            lineHeight: 1.5
        }
    }
}