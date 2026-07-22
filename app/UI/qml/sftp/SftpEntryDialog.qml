pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

Dialog {
    id: root
    parent: Overlay.overlay
    x: Math.round((parent.width - width) / 2)
    y: Math.round((parent.height - height) / 2)
    width: Math.min(460, parent.width - Theme.spacing16 * 2)
    implicitHeight: 238
    modal: true
    dim: true
    padding: Theme.spacing16
    closePolicy: Popup.CloseOnEscape
    onClosed: UiState.windowLock = false

    property string titleText: "Create folder"
    property string fieldLabel: "Name"
    property string acceptText: "Create"
    property alias value: nameField.text

    background: Rectangle {
        color: Theme.contentPanelSurface
        border.color: Theme.contentPanelBorder
        border.width: Theme.borderWidth
        radius: Theme.radiusMedium
    }

    header: Rectangle {
        implicitHeight: 52
        color: Theme.sideBarBackground
        radius: Theme.radiusMedium
        Text {
            anchors.left: parent.left
            anchors.leftMargin: Theme.spacing16
            anchors.verticalCenter: parent.verticalCenter
            text: root.titleText
            color: Theme.textPrimary
            font.bold: true
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeLarge
        }
    }

    contentItem: ColumnLayout {
        spacing: Theme.spacing8
        StandardTextField {
            id: nameField
            Layout.fillWidth: true
            labelText: root.fieldLabel
            onAccepted: {
                if (text.trim() !== "")
                    root.accept()
            }
        }
    }

    footer: Rectangle {
        implicitHeight: 58
        color: "transparent"
        RowLayout {
            anchors.right: parent.right
            anchors.rightMargin: Theme.spacing16
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacing8
            StandardButton {
                text: "Cancel"
                type: "Text"
                onClicked: root.reject()
            }
            StandardButton {
                text: root.acceptText
                type: "Primary"
                enabled: nameField.text.trim() !== ""
                onClicked: root.accept()
            }
        }
    }

    onOpened: {
        UiState.windowLock = true
        nameField.selectAll()
        nameField.forceActiveFocus()
    }
}
