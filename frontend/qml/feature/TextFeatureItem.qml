pragma ComponentBehavior: Bound

import QtQuick
import NetworkTools

Item {
    id: textFeatureItem

    property string label: ""
    property bool isActive: false

    signal clicked()

    width: labelText.implicitWidth + 24
    height: parent.height

    // Chỉ báo active ở mép trên, đồng bộ phong cách với SubBar
    Rectangle {
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width
        height: 2
        color: Theme.accentColor
        visible: isActive
    }

    Rectangle {
        anchors.fill: parent
        color: itemHover.hovered && !isActive ? Theme.sideBarItemHover : "transparent"
    }

    Text {
        id: labelText
        anchors.centerIn: parent
        text: textFeatureItem.label
        font.pixelSize: Theme.fontSizeNormal
        font.family: Theme.fontFamily
        font.bold: isActive
        color: isActive ? Theme.textPrimary : Theme.textSecondary
    }

    HoverHandler { id: itemHover }
    TapHandler { onTapped: textFeatureItem.clicked() }
}
