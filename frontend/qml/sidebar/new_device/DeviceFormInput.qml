pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import NetworkUI

RowLayout {
    id: root

    // ── CÁC THUỘC TÍNH MỞ RỘNG ĐỂ BÊN NGOÀI TRUYỀN VÀO ──
    property string labelText: ""
    property alias text: inputField.text
    property alias placeholder: inputField.placeholderText
    property alias echoMode: inputField.echoMode
    property alias readOnly: inputField.readOnly
    property alias validator: inputField.validator
    property alias inputItem: inputField
    property double inputOpacity: inputField.readOnly ? 0.6 : 1.0

    Layout.fillWidth: true

    // ── Label ──────────────────────────────────────────────────────────────
    Text {
        text: root.labelText
        color: Theme.textSecondary
        font.pixelSize: Theme.fontSizeNormal
        font.family: Theme.fontFamily
        Layout.preferredWidth: 100
    }

    // ── TextField ──────────────────────────────────────────────────────────
    TextField {
        id: inputField
        Layout.fillWidth: true
        color: Theme.textPrimary
        font.pixelSize: Theme.fontSizeNormal
        font.family: Theme.fontFamily
        opacity: root.inputOpacity
        placeholderTextColor: Theme.placeholderTextColor

        background: Rectangle {
            color: Theme.searchBackground2
            border.color: inputField.activeFocus ? Theme.accentColor : Theme.borderColor
            border.width: 1
            radius: 4
        }
    }
}