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

    // Gạch chân khi active
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: labelText.implicitWidth
        height: 2
        color: Theme.accentColor
        visible: isActive
    }

    Text {
        id: labelText
        anchors.centerIn: parent
        text: textFeatureItem.label
        font.pixelSize: Theme.fontSizeNormal
        font.family: Theme.fontFamily
        font.bold: isActive
        color: isActive ? Theme.textPrimary : Theme.textDisabled
    }

    HoverHandler { id: itemHover }
    TapHandler { onTapped: textFeatureItem.clicked() }
}
