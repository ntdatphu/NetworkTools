pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import UI

Rectangle {
    id: root
    objectName: "sftpWorkspace"
    color: Theme.contentBackground
    readonly property var backend: typeof sftpController !== "undefined"
                                   ? sftpController : null

    Connections {
        target: root.backend
        function onErrorOccurred(message) {
            errorDialog.messageText = message
            errorDialog.open()
        }
        function onHostKeyConfirmationRequired(host, keyType, fingerprint) {
            hostKeyDialog.messageText = "Host: " + host
                + "\nKey type: " + keyType
                + "\nFingerprint: " + fingerprint
                + "\n\nContinue only if this fingerprint matches the server you manage."
            hostKeyDialog.open()
        }
    }

    SftpMessageDialog {
        id: errorDialog
        objectName: "sftpErrorDialog"
        titleText: "SFTP Error"
    }
    SftpMessageDialog {
        id: hostKeyDialog
        objectName: "sftpHostKeyDialog"
        titleText: "Confirm SSH Host Key"
        confirmation: true
        onAccepted: root.backend.confirmHostKey(true)
        onRejected: root.backend.confirmHostKey(false)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacing12
        spacing: Theme.spacing8

        SftpConnectionBar {
            Layout.fillWidth: true
            backend: root.backend
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: root.width >= 900 ? 2 : 1
            columnSpacing: Theme.spacing8
            rowSpacing: Theme.spacing8

            SftpFilePanel {
                objectName: "sftpLocalPanel"
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 260
                backend: root.backend
                fileModel: root.backend.localModel
                currentPath: root.backend.localPath
            }
            SftpFilePanel {
                objectName: "sftpRemotePanel"
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 260
                backend: root.backend
                fileModel: root.backend.remoteModel
                currentPath: root.backend.remotePath
                remoteSide: true
            }
        }

        SftpTransferQueue {
            Layout.fillWidth: true
            Layout.preferredHeight: 142
            backend: root.backend
        }
    }

    Text {
        anchors.centerIn: parent
        visible: root.backend === null
        text: "SFTP backend is unavailable"
        color: Theme.alertError
        font.family: Theme.fontFamily
    }
}
