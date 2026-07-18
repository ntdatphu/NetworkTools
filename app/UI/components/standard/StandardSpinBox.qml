pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

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
        implicitHeight: Theme.itemHeight
        editable: true // Mặc định cho phép gõ phím

        background: Rectangle {
            color: Theme.inputBackground
            border.color: spinBox.activeFocus ? Theme.inputBorderFocusColor : Theme.inputBorderColor
            border.width: Theme.borderWidth
            radius: Theme.radiusSmall
        }

        contentItem: TextInput {
            text: spinBox.textFromValue(spinBox.value, spinBox.locale)
            font.pixelSize: Theme.fontSizeNormal
            font.family: Theme.fontFamily
            color: Theme.textPrimary
            selectionColor: Theme.selectionBackground
            selectedTextColor: Theme.selectionForeground
            horizontalAlignment: Qt.AlignLeft
            verticalAlignment: Qt.AlignVCenter
            leftPadding: Theme.spacing12
            rightPadding: 36
            readOnly: !spinBox.editable
            validator: spinBox.validator
            inputMethodHints: Qt.ImhFormattedNumbersOnly
            opacity: spinBox.enabled ? 1.0 : 0.5
        }

        up.indicator: Rectangle {
            x: spinBox.mirrored ? 1 : parent.width - width - 1
            y: 1
            width: 28
            height: (parent.height - 2) / 2
            color: spinBox.up.pressed ? Theme.sideBarItemSelected : (spinBox.up.hovered ? Theme.sideBarItemHover : "transparent")
            radius: Theme.radiusSmall

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: Theme.borderWidth
                color: Theme.inputBorderColor
            }

            ThemedIcon {
                anchors.centerIn: parent
                iconSource: AppAssets.navigationChevronUp
                iconSize: Theme.iconSizeSmall
                iconColor: Theme.textSecondary
                opacity: 0.7
            }
        }

        down.indicator: Rectangle {
            x: spinBox.mirrored ? 1 : parent.width - width - 1
            y: parent.height / 2
            width: 28
            height: (parent.height - 2) / 2
            color: spinBox.down.pressed ? Theme.sideBarItemSelected : (spinBox.down.hovered ? Theme.sideBarItemHover : "transparent")
            radius: Theme.radiusSmall

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: Theme.borderWidth
                color: Theme.inputBorderColor
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: Theme.borderWidth
                color: Theme.inputBorderColor
            }

            ThemedIcon {
                anchors.centerIn: parent
                iconSource: AppAssets.navigationChevronDown
                iconSize: Theme.iconSizeSmall
                iconColor: Theme.textSecondary
                opacity: 0.7
            }
        }
    }
}
