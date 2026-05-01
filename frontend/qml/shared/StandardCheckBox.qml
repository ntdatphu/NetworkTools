pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import NetworkUI

Item {
    id: root

    property bool checked: false
    property string text: ""
    property bool enabled: true

    signal toggled()
    signal clicked()

    implicitWidth: text !== "" ? box.width + spacing + labelItem.implicitWidth : box.width
    implicitHeight: 16

    readonly property int spacing: 8

    Rectangle {
        id: box
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 16
        height: 16
        radius: 3

        // Sử dụng các biến màu CHẮC CHẮN TỒN TẠI trong Theme của bạn
        color: {
            if (!root.enabled) return "transparent"
            if (root.checked) return Theme.accentColor
            if (hoverHandler.hovered) return Theme.sideBarItemHover
            return Theme.searchBackground2
        }

        border.color: {
            if (!root.enabled) return Theme.borderColor
            if (root.checked) return Theme.accentColor
            return Theme.borderColor
        }
        border.width: 1

        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }

        Text {
            anchors.centerIn: parent
            text: "✓"
            font.pixelSize: 10
            font.bold: true
            font.family: Theme.fontFamily
            color: Theme.buttonTextSolid
            visible: root.checked
        }
    }

    Text {
        id: labelItem
        visible: root.text !== ""
        anchors.left: box.right
        anchors.leftMargin: root.spacing
        anchors.verticalCenter: parent.verticalCenter

        text: root.text
        color: root.enabled ? Theme.textPrimary : Theme.textSecondary
        font.pixelSize: Theme.fontSizeNormal
        font.family: Theme.fontFamily

        opacity: root.enabled ? 1.0 : 0.5
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    HoverHandler {
        id: hoverHandler
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        enabled: root.enabled
        onTapped: {
            root.checked = !root.checked
            root.clicked()
            root.toggled()
        }
    }
}