pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Dialogs
import QtQuick.Layouts
import UI

Dialog {
    id: root
    parent: Overlay.overlay
    x: Math.round((parent.width - width) / 2)
    y: Math.round((parent.height - height) / 2)
    width: Math.min(640, parent.width - Theme.spacing16 * 2)
    height: Math.min(590, parent.height - Theme.spacing16 * 2)
    modal: true
    dim: true
    padding: Theme.spacing16
    closePolicy: Popup.CloseOnEscape
    onOpened: UiState.windowLock = true
    onClosed: UiState.windowLock = false

    required property var backend
    property string profileId: ""

    function openFor(profile) {
        const value = profile || ({})
        profileId = String(value.id || "")
        nameField.text = String(value.name || "")
        hostField.text = String(value.host || "")
        portField.value = Number(value.port || 22)
        userField.text = String(value.username || "")
        keyField.text = String(value.keyPath || "")
        localField.text = String(value.localPath || (backend ? backend.defaultLocalPath : ""))
        remoteField.text = String(value.remotePath || (backend ? backend.defaultRemotePath : "/"))
        open()
    }

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
            text: "Edit SFTP connection"
            color: Theme.textPrimary
            font.bold: true
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeLarge
        }
    }

    FileDialog {
        id: keyDialog
        title: "Select SSH private key"
        nameFilters: ["SSH keys (*.pem *.key *.ppk)", "All files (*)"]
        onAccepted: keyField.text = selectedFile.toString()
    }

    contentItem: ScrollView {
        clip: true
        contentWidth: availableWidth
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        ColumnLayout {
            width: parent.availableWidth
            spacing: Theme.spacing12

            Text {
                Layout.fillWidth: true
                text: "Passwords are requested when connecting and are never stored."
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.WordWrap
            }
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: Theme.spacing8
                rowSpacing: Theme.spacing8

                StandardTextField {
                    id: nameField
                    Layout.fillWidth: true
                    Layout.columnSpan: 2
                    labelText: "Display name"
                }
                StandardTextField {
                    id: hostField
                    Layout.fillWidth: true
                    labelText: "Host / IP"
                }
                StandardSpinBox {
                    id: portField
                    Layout.preferredWidth: 150
                    labelText: "Port"
                    from: 1
                    to: 65535
                    value: 22
                    editable: true
                }
                StandardTextField {
                    id: userField
                    Layout.fillWidth: true
                    Layout.columnSpan: 2
                    labelText: "Username"
                }
                StandardTextField {
                    id: keyField
                    Layout.fillWidth: true
                    labelText: "Private key (optional)"
                }
                StandardButton {
                    Layout.alignment: Qt.AlignBottom
                    text: "Browse"
                    icon.source: AppAssets.fileTypeKey
                    onClicked: keyDialog.open()
                }
                StandardTextField {
                    id: localField
                    Layout.fillWidth: true
                    Layout.columnSpan: 2
                    labelText: "Initial local directory"
                }
                StandardTextField {
                    id: remoteField
                    Layout.fillWidth: true
                    Layout.columnSpan: 2
                    labelText: "Initial remote directory"
                }
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
            StandardButton { text: "Cancel"; type: "Text"; onClicked: root.reject() }
            StandardButton {
                text: "Save"
                type: "Primary"
                icon.source: AppAssets.actionSave
                enabled: hostField.text.trim() !== "" && userField.text.trim() !== ""
                onClicked: {
                    if (!root.backend)
                        return
                    root.backend.saveConnection(
                        root.profileId,
                        nameField.text,
                        hostField.text,
                        portField.value,
                        userField.text,
                        keyField.text,
                        localField.text,
                        remoteField.text
                    )
                    root.accept()
                }
            }
        }
    }
}
