pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import UI

Rectangle {
    id: root
    height: Theme.searchBarHeight
    radius: 4
    color: Theme.panelSideBarSearchBackground
    border.color: searchField.activeFocus ? Theme.panelSideBarAccentColor : Theme.panelSideBarInputBorderColor
    border.width: 1

    property alias text: searchField.text
    property alias placeholderText: searchField.placeholderText

    Row {
        anchors.fill: parent
        anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 6

        Button {
            anchors.verticalCenter: parent.verticalCenter
            width: 14; height: 14; padding: 0
            icon.source: AppAssets.resource("resources/sidebar/search.svg")
            icon.width: 14; icon.height: 14; icon.color: Theme.panelSideBarTextSecondary
            opacity: searchField.activeFocus ? 1.0 : 0.5
            background: Item {}
            enabled: false
        }

        StandardTextField {
            id: searchField
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 20
            placeholderText: "Search devices..."
            textColor: Theme.panelSideBarTextPrimary
            placeholderColor: Theme.panelSideBarPlaceholderTextColor
            focusBorderColor: Theme.panelSideBarAccentColor
            borderColor: Theme.panelSideBarInputBorderColor

            background: Item {}
            leftPadding: 0
            rightPadding: 0
            topPadding: 0
            bottomPadding: 0
        }
    }
}
