pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import NetworkUI

SpinBox {
    id: control

    implicitWidth: 120
    implicitHeight: Theme.itemHeight

    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSizeNormal

    // ── CONTENT ITEM (TEXT INPUT) ───────────────────────────────────────────
    contentItem: TextInput {
        z: 2
        text: control.textFromValue(control.value, control.locale)
        font: control.font
        color: control.enabled ? Theme.textPrimary : Theme.textDisabled
        selectionColor: Theme.accentColor
        selectedTextColor: "#ffffff"
        horizontalAlignment: Qt.AlignHCenter
        verticalAlignment: Qt.AlignVCenter

        readOnly: !control.editable
        validator: control.validator
        inputMethodHints: Qt.ImhFormattedNumbersOnly
    }

    // ── DOWN INDICATOR (-) ──────────────────────────────────────────────────
    down.indicator: Rectangle {
        x: control.mirrored ? parent.width - width : 0
        height: parent.height
        implicitWidth: 32
        implicitHeight: control.implicitHeight
        color: control.down.pressed ? Theme.sideBarItemHover : "transparent"
        border.color: Theme.borderColor
        border.width: Theme.borderWidth

        // Bo góc trái
        radius: Theme.borderRadius
        Rectangle {
            x: parent.width - radius
            y: 0
            width: radius
            height: parent.height
            color: parent.color
            border.width: 0
        }

        Text {
            text: "-"
            font.pixelSize: control.font.pixelSize * 1.5
            color: control.enabled ? Theme.textPrimary : Theme.textDisabled
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -1
        }
    }

    // ── UP INDICATOR (+) ────────────────────────────────────────────────────
    up.indicator: Rectangle {
        x: control.mirrored ? 0 : parent.width - width
        height: parent.height
        implicitWidth: 32
        implicitHeight: control.implicitHeight
        color: control.up.pressed ? Theme.sideBarItemHover : "transparent"
        border.color: Theme.borderColor
        border.width: Theme.borderWidth

        // Bo góc phải
        radius: Theme.borderRadius
        Rectangle {
            x: 0
            y: 0
            width: radius
            height: parent.height
            color: parent.color
            border.width: 0
        }

        Text {
            text: "+"
            font.pixelSize: control.font.pixelSize * 1.2
            color: control.enabled ? Theme.textPrimary : Theme.textDisabled
            anchors.centerIn: parent
        }
    }

    // ── BACKGROUND ──────────────────────────────────────────────────────────
    background: Rectangle {
        implicitWidth: control.implicitWidth
        implicitHeight: control.implicitHeight
        color: control.enabled ? Theme.searchBackground : Theme.tabInactive
        border.color: control.activeFocus ? Theme.accentColor : Theme.borderColor
        border.width: control.activeFocus ? 2 : Theme.borderWidth
        radius: Theme.borderRadius
    }
}