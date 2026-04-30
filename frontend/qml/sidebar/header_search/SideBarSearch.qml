pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import NetworkUI

Rectangle {
    id: root
    height: Theme.searchBarHeight
    radius: 4
    color: Theme.searchBackground
    border.color: searchField.activeFocus ? Theme.accentColor : Theme.borderColor
    border.width: 1

    property alias text: searchField.text

    Row {
        anchors.fill: parent
        anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 6

        Button {
            anchors.verticalCenter: parent.verticalCenter
            width: 14; height: 14; padding: 0
            icon.source: "qrc:/qt/qml/NetworkUI/resources/sidebar/search.svg"
            icon.width: 14; icon.height: 14; icon.color: Theme.textSecondary
            opacity: searchField.activeFocus ? 1.0 : 0.5
            background: Item {}
            enabled: false
        }

        TextInput {
            id: searchField
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 20
            color: Theme.textPrimary
            font.pixelSize: Theme.fontSizeNormal
            font.family: Theme.fontFamily
            clip: true

            Text {
                anchors.fill: parent
                text: "Search devices..."
                color: Theme.textDisabled
                font.pixelSize: Theme.fontSizeNormal
                visible: !searchField.activeFocus && searchField.text === ""
            }
        }
    }
}