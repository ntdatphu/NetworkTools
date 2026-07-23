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
    readonly property bool backendAvailable: backend !== null && backend !== undefined
    property string privateKeyPath: ""
    property string selectedProfileId: ""
    property bool savedPasswordAvailable: false
    readonly property bool anyInputFocus: hostField.inputActiveFocus
                                                  || portField.inputActiveFocus
                                                  || userField.inputActiveFocus
                                                  || passwordField.inputActiveFocus

    function loadSelectedProfile() {
        if (!backend)
            return
        const profile = backend.selectedConnection || ({})
        const profileId = String(profile.id || "")
        if (profileId === "") {
            selectedProfileId = ""
            savedPasswordAvailable = false
            return
        }
        selectedProfileId = profileId
        hostField.text = String(profile.host || "")
        portField.value = Number(profile.port || 22)
        userField.text = String(profile.username || "")
        passwordField.text = ""
        savedPasswordAvailable = Boolean(profile.passwordSaved)
        privateKeyPath = String(profile.keyPath || "")
    }

    Connections {
        target: root.backend
        function onSelectedConnectionChanged() { root.loadSelectedProfile() }
        function onConnectedChanged() {
            if (root.backend && root.backend.connected)
                passwordField.text = ""
        }
    }

    Component.onCompleted: loadSelectedProfile()

    FileDialog {
        id: keyDialog
        title: "Select SSH private key"
        nameFilters: ["SSH keys (*.pem *.key)", "All files (*)"]
        onAccepted: root.privateKeyPath = selectedFile.toString()
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
            objectName: "sftpHostField"
            Layout.fillWidth: true
            Layout.minimumWidth: 180
            labelText: "Host / IP"
            placeholderText: "192.168.1.10"
        }
        StandardSpinBox {
            id: portField
            objectName: "sftpPortField"
            Layout.fillWidth: true
            Layout.minimumWidth: 105
            labelText: "Port"
            from: 1
            to: 65535
            value: 22
            stepSize: 1
            editable: true
        }
        StandardTextField {
            id: userField
            objectName: "sftpUserField"
            Layout.fillWidth: true
            Layout.minimumWidth: 150
            labelText: "Username"
            placeholderText: "admin"
        }
        StandardPasswordField {
            id: passwordField
            objectName: "sftpPasswordField"
            Layout.fillWidth: true
            Layout.minimumWidth: 170
            labelText: "Password"
            placeholderText: root.savedPasswordAvailable
                             ? "Saved password will be used" : "Not saved"
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
                text: root.privateKeyPath === "" ? "Select key" : "Key selected"
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
                icon.source: root.backend && root.backend.connected
                             ? AppAssets.actionDisconnect
                             : AppAssets.actionConnect
                enabled: root.backendAvailable
                         && (!root.backend.busy || root.backend.connected)
                onClicked: {
                    if (!root.backendAvailable)
                        return
                    if (root.backend.connected) {
                        root.backend.disconnectServer()
                    } else {
                        if (root.selectedProfileId !== "") {
                            root.backend.connectServerForProfile(
                                root.selectedProfileId,
                                hostField.text,
                                portField.value,
                                userField.text,
                                passwordField.text,
                                root.privateKeyPath
                            )
                        } else {
                            root.backend.connectServer(
                                hostField.text,
                                portField.value,
                                userField.text,
                                passwordField.text,
                                root.privateKeyPath
                            )
                        }
                    }
                }
            }
        }
        Text {
            Layout.fillWidth: true
            Layout.columnSpan: form.columns
            visible: root.backendAvailable && root.backend.autoSavePasswords
            text: "Automatic password saving is enabled (not recommended). "
                  + "Prefer a private key or SSH agent."
            color: Theme.alertWarning
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            wrapMode: Text.WordWrap
        }
    }
}
