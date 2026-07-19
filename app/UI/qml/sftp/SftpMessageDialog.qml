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
    width: Math.min(520, parent.width - Theme.spacing16 * 2)
    implicitHeight: 230
    modal: true
    dim: true
    padding: Theme.spacing16
    closePolicy: Popup.CloseOnEscape

    property string titleText: "SFTP"
    property string messageText: ""
    property bool confirmation: false

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
    contentItem: Text {
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.Wrap
        text: root.messageText
        color: Theme.textPrimary
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeNormal
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
                visible: root.confirmation
                text: "Reject"
                type: "Text"
                onClicked: root.reject()
            }
            StandardButton {
                text: root.confirmation ? "Trust and Connect" : "Close"
                type: "Primary"
                onClicked: root.accept()
            }
        }
    }
}
