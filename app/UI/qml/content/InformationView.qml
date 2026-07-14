pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

Rectangle {
    id: root

    property string currentHostIp: ""
    property string configText: ""
    property string configPath: ""
    property string loadError: ""
    property bool isLoadingLive: false
    readonly property string runningConfigCommand: "show running-config"

    color: Theme.contentBackground

    function loadBackup() {
        root.configText = ""
        root.configPath = ""
        root.loadError = ""

        const host = String(root.currentHostIp || "").trim()
        if (host === "")
            return

        if (typeof cli !== "undefined"
                && cli.hasDeviceSession
                && cli.runDeviceCommandAsync
                && cli.hasDeviceSession(host)) {
            root.isLoadingLive = true
            root.configPath = "active tab session"
            const accepted = cli.runDeviceCommandAsync(host, root.runningConfigCommand)
            if (!accepted) {
                root.isLoadingLive = false
                root.loadError = "Load running-config from active session could not start."
            }
            return
        }

        const payload = dbManager.getRunningConfigBackup(host)
        const ok = payload && (payload.ok === undefined || payload.ok === true)
        root.configPath = payload && payload.path ? String(payload.path) : ""

        if (ok) {
            root.configText = payload && payload.content ? String(payload.content) : ""
        } else {
            root.loadError = payload && payload.message ? String(payload.message) : "Load running-config backup failed."
        }
    }

    Connections {
        target: typeof cli !== "undefined" ? cli : null
        function onDeviceCommandFinished(host, command, ok, message, output) {
            if (String(host || "") !== String(root.currentHostIp || "").trim())
                return
            if (String(command || "") !== root.runningConfigCommand)
                return

            root.isLoadingLive = false
            if (ok) {
                root.configText = String(output || "")
                root.configPath = "active tab session"
                root.loadError = ""
                return
            }

            root.configText = ""
            root.configPath = "active tab session"
            root.loadError = String(message || "Load running-config from active session failed.")
        }
    }

    onCurrentHostIpChanged: loadBackup()
    Component.onCompleted: loadBackup()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: Theme.spacing12

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing12

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                Text {
                    text: "Information"
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLarge
                    font.bold: true
                }

                Text {
                    Layout.fillWidth: true
                    text: root.currentHostIp === ""
                          ? "No device selected"
                          : root.currentHostIp + (root.configPath !== "" ? " · " + root.configPath : "")
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    elide: Text.ElideLeft
                }
            }

            StandardButton {
                text: "Reload"
                icon.source: AppAssets.resource("resources/general/backup.svg")
                type: "Secondary"
                enabled: String(root.currentHostIp || "").trim() !== ""
                onClicked: root.loadBackup()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.radiusSmall
            color: Theme.contentPanelSurface
            border.color: Theme.contentPanelBorder
            border.width: Theme.borderWidth

            Text {
                anchors.centerIn: parent
                visible: root.currentHostIp === ""
                text: "Choose a device to view its running-config backup."
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeNormal
            }

            Text {
                anchors.centerIn: parent
                width: Math.min(parent.width - 48, 620)
                visible: root.currentHostIp !== "" && root.loadError !== "" && !root.isLoadingLive
                text: root.loadError
                color: Theme.alertWarning
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeNormal
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            ScrollView {
                anchors.fill: parent
                anchors.margins: Theme.spacing12
                visible: root.currentHostIp !== "" && root.loadError === "" && !root.isLoadingLive
                clip: true

                TextArea {
                    text: root.configText
                    readOnly: true
                    selectByMouse: true
                    wrapMode: TextEdit.NoWrap
                    color: Theme.textPrimary
                    selectedTextColor: Theme.selectionForeground
                    selectionColor: Theme.selectionBackground
                    font.family: "Consolas"
                    font.pixelSize: Theme.fontSizeSmall
                    background: null
                }
            }

            Text {
                anchors.centerIn: parent
                visible: root.currentHostIp !== "" && root.isLoadingLive
                text: "Loading running-config from active session..."
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeNormal
            }
        }
    }
}
