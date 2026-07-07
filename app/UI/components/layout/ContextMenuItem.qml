pragma ComponentBehavior: Bound

import QtQuick
import UI

Rectangle {
    id: root

    property string text: ""
    property string iconSource: ""
    property bool reserveIconSpace: iconSource !== ""
    property bool danger: false
    property int itemHeight: 32
    property int iconSize: 14
    property int leftMargin: 12

    readonly property bool hovered: itemHover.hovered && root.enabled
    readonly property color activeTextColor: root.danger ? Theme.alertError : Theme.panelSideBarTextPrimary
    readonly property color idleTextColor: Theme.panelSideBarTextSecondary

    signal triggered()

    width: parent ? parent.width : implicitWidth
    height: itemHeight
    radius: Theme.radiusSmall
    opacity: root.enabled ? 1.0 : 0.45
    color: root.hovered
           ? (root.danger ? Theme.alertErrorSubtle : Theme.panelSideBarItemHover)
           : "transparent"

    Row {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: root.leftMargin
        spacing: 10

        ThemedIcon {
            visible: root.iconSource !== ""
            anchors.verticalCenter: parent.verticalCenter
            iconSource: root.iconSource
            iconSize: root.iconSize
            iconColor: root.hovered ? root.activeTextColor : root.idleTextColor
        }

        Item {
            visible: root.iconSource === "" && root.reserveIconSpace
            width: root.iconSize
            height: root.iconSize
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            font.pixelSize: Theme.fontSizeNormal
            font.family: Theme.fontFamily
            color: root.hovered ? root.activeTextColor : root.idleTextColor
        }
    }

    HoverHandler {
        id: itemHover
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        enabled: root.enabled
        onTapped: root.triggered()
    }
}
