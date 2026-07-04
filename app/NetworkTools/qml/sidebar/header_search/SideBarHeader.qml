pragma ComponentBehavior: Bound

import QtQuick
import NetworkTools

Item {
    id: root
    width: parent.width
    height: 36

    signal filterClicked()
    signal refreshClicked()
    signal addClicked()

    property bool isFilterActive: false

    Text {
        anchors.left: parent.left; anchors.leftMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        text: "DEVICES"
        color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSmall
        font.family: Theme.fontFamily; font.capitalization: Font.AllUppercase; font.weight: Font.Medium
    }

    Row {
        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: 8; spacing: 2

        IconButton {
            buttonSize: Theme.sideBarFeatureIcon
            iconSource: AppPaths.resource("resources/sidebar/filter.svg")
            selected: root.isFilterActive
            tooltip: "Filter Devices"
            onClicked: root.filterClicked()
        }

        IconButton {
            buttonSize: Theme.sideBarFeatureIcon
            iconSource: AppPaths.resource("resources/sidebar/refresh.svg")
            tooltip: "Refresh List"
            onClicked: root.refreshClicked()
        }

        IconButton {
            buttonSize: Theme.sideBarFeatureIcon
            iconSource: AppPaths.resource("resources/sidebar/add.svg")
            tooltip: "Add New Device (Ctrl+N) | Add Multiple (Ctrl+Shift+N)"
            onClicked: root.addClicked()
        }
    }
}
