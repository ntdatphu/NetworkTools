pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import NetworkTools

ColumnLayout {
    id: root
    spacing: 4

    // ── Public API ──
    property string labelText: ""

    // ── Alias xuống SpinBox bên trong ──
    property alias from: spinBox.from
    property alias to: spinBox.to
    property alias value: spinBox.value
    property alias stepSize: spinBox.stepSize
    property alias editable: spinBox.editable
    property alias enabled: spinBox.enabled

    // ── Label hiển thị tên trường (nếu có) ──
    Text {
        visible: root.labelText !== ""
        text: root.labelText
        color: Theme.textSecondary
        font.pixelSize: Theme.fontSizeSmall
        font.family: Theme.fontFamily
    }

    // ── SpinBox chính ──
    SpinBox {
        id: spinBox
        Layout.fillWidth: true
        editable: true // Mặc định cho phép gõ phím
        background: Rectangle {
            color: Theme.searchBackground2
            border.color: spinBox.activeFocus ? Theme.accentColor : Theme.borderColor
            border.width: Theme.borderWidth
            radius: Theme.borderRadius

            Behavior on border.color { ColorAnimation { duration: Theme.animationDurationFast } }
        }

        contentItem: TextInput {
            text: spinBox.textFromValue(spinBox.value, spinBox.locale)
            font.pixelSize: Theme.fontSizeNormal
            font.family: Theme.fontFamily
            color: Theme.textPrimary
            selectionColor: Theme.accentColor
            selectedTextColor: Theme.buttonTextSolid
            horizontalAlignment: Qt.AlignHCenter
            verticalAlignment: Qt.AlignVCenter
            readOnly: !spinBox.editable
            validator: spinBox.validator
            inputMethodHints: Qt.ImhFormattedNumbersOnly
            opacity: spinBox.enabled ? 1.0 : 0.5
        }

        up.indicator: Rectangle {
            x: spinBox.mirrored ? 0 : parent.width - width
            height: parent.height
            implicitWidth: 28
            color: spinBox.up.pressed ? Theme.sideBarItemSelected : (spinBox.up.hovered ? Theme.sideBarItemHover : "transparent")
            border.color: Theme.borderColor
            border.width: Theme.borderWidth
            radius: Theme.borderRadius

            Behavior on color { ColorAnimation { duration: Theme.animationDurationFast } }

            Text {
                anchors.centerIn: parent
                text: "▲"
                font.pixelSize: 8
                color: Theme.textSecondary
            }
        }

        down.indicator: Rectangle {
            x: spinBox.mirrored ? parent.width - width : 0
            height: parent.height
            implicitWidth: 28
            color: spinBox.down.pressed ? Theme.sideBarItemSelected : (spinBox.down.hovered ? Theme.sideBarItemHover : "transparent")
            border.color: Theme.borderColor
            border.width: Theme.borderWidth
            radius: Theme.borderRadius

            Behavior on color { ColorAnimation { duration: Theme.animationDurationFast } }

            Text {
                anchors.centerIn: parent
                text: "▼"
                font.pixelSize: 8
                color: Theme.textSecondary
            }
        }
    }
}