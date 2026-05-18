pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import NetworkTools

Item {
    id: root

    property string iconSource: ""
    property string glyph: ""
    property string tooltip: ""
    property bool selected: false
    property bool danger: false
    property int buttonSize: Theme.sideBarFeatureIcon
    property int iconSize: Theme.iconSizeNormal
    property int radius: Theme.radiusSmall
    property color idleColor: Theme.textSecondary
    property color activeColor: danger ? Theme.alertError : Theme.textPrimary
    property color selectedBackground: danger ? Theme.alertErrorSubtle : Theme.sideBarItemHover
    property color hoverBackground: danger ? Theme.alertErrorSubtle : Theme.sideBarItemHover

    readonly property bool hovered: hoverHandler.hovered

    signal clicked()

    implicitWidth: buttonSize
    implicitHeight: buttonSize

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.selected ? root.selectedBackground
                              : (root.hovered ? root.hoverBackground : "transparent")
        border.color: root.danger && root.hovered ? Theme.alertError : "transparent"
        border.width: root.danger && root.hovered ? Theme.borderWidth : 0
    }

    Button {
        visible: root.iconSource !== ""
        anchors.centerIn: parent
        width: root.iconSize
        height: root.iconSize
        padding: 0
        enabled: false
        background: Item {}

        icon.source: root.iconSource
        icon.width: root.iconSize
        icon.height: root.iconSize
        icon.color: root.selected || root.hovered ? root.activeColor : root.idleColor
    }

    Text {
        visible: root.iconSource === "" && root.glyph !== ""
        anchors.centerIn: parent
        text: root.glyph
        color: root.selected || root.hovered ? root.activeColor : root.idleColor
        font.pixelSize: root.iconSize
        font.family: Theme.fontFamily
        font.bold: root.selected
    }

    HoverHandler {
        id: hoverHandler
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        enabled: root.enabled
        onTapped: root.clicked()
    }

    ToolTip {
        visible: root.tooltip !== "" && root.hovered
        text: root.tooltip
        delay: 400
    }
}
