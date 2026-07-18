pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Dialogs
import QtQuick.Layouts
import UI

Rectangle {
    id: root
    color: Theme.contentPanelSurface
    border.color: Theme.contentPanelBorder
    radius: Theme.radiusSmall
    implicitHeight: form.implicitHeight + Theme.spacing12 * 2

    required property var backend
    property url privateKeyUrl: ""

    FileDialog {
        id: keyDialog
        title: "Select SSH private key"
        nameFilters: ["SSH keys (*.pem *.key)", "All files (*)"]
        onAccepted: root.privateKeyUrl = selectedFile
    }

    GridLayout {
        id: form
        anchors.fill: parent
        anchors.margins: Theme.spacing12
        columns: root.width >= 1100 ? 6 : root.width >= 720 ? 3 : 2
        columnSpacing: Theme.spacing8
        rowSpacing: Theme.spacing8

        StandardTextField {
            id: hostField
            Layout.fillWidth: true
            Layout.minimumWidth: 180
            labelText: "Host / IP"
            placeholderText: "192.168.1.10"
        }
        StandardSpinBox {
            id: portField
            Layout.fillWidth: true
            Layout.minimumWidth: 105
            labelText: "Port"
            from: 1
            to: 65535
            value: 22
            editable: true
        }
        StandardTextField {
            id: userField
            Layout.fillWidth: true
            Layout.minimumWidth: 150
            labelText: "Username"
            placeholderText: "admin"
        }
        StandardPasswordField {
            id: passwordField
            Layout.fillWidth: true
            Layout.minimumWidth: 170
            labelText: "Password"
            placeholderText: "Not saved"
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing4
            Text {
                text: "Private key (optional)"
                color: Theme.textSecondary
                font.pixelSize: Theme.fontSizeSmall
                font.family: Theme.fontFamily
            }
            StandardButton {
                Layout.fillWidth: true
                text: root.privateKeyUrl.toString() === "" ? "Select key" : "Key selected"
                onClicked: keyDialog.open()
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignBottom
            StandardButton {
                Layout.fillWidth: true
                text: root.backend && root.backend.connected ? "Disconnect" : "Connect"
                type: root.backend && root.backend.connected ? "Secondary" : "Primary"
                icon.source: AppAssets.resource(root.backend && root.backend.connected
                                                ? "../UI/resources/sftp_icons/power.svg"
                                                : "../UI/resources/sftp_icons/plug.svg")
                enabled: root.backend && (!root.backend.busy || root.backend.connected)
                onClicked: {
                    if (root.backend.connected) {
                        root.backend.disconnectServer()
                    } else {
                        root.backend.connectServer(
                            hostField.text,
                            portField.value,
                            userField.text,
                            passwordField.text,
                            root.privateKeyUrl.toString()
                        )
                    }
                }
            }
        }
    }
}
