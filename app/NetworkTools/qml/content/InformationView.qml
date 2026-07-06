pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import NetworkTools

Rectangle {
    id: root

    property string currentHostIp: ""
    property string configText: ""
    property string configPath: ""
    property string loadError: ""

    color: Theme.contentBackground

    function loadBackup() {
        root.configText = ""
        root.configPath = ""
        root.loadError = ""

        const host = String(root.currentHostIp || "").trim()
        if (host === "")
            return

        const payload = dbManager.getRunningConfigBackup(host)
        const ok = payload && (payload.ok === undefined || payload.ok === true)
        root.configPath = payload && payload.path ? String(payload.path) : ""

        if (ok) {
            root.configText = payload && payload.content ? String(payload.content) : ""
        } else {
            root.loadError = payload && payload.message ? String(payload.message) : "Load running-config backup failed."
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
                visible: root.currentHostIp !== "" && root.loadError !== ""
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
                visible: root.currentHostIp !== "" && root.loadError === ""
                clip: true

                TextArea {
                    text: root.configText
                    readOnly: true
                    selectByMouse: true
                    wrapMode: TextEdit.NoWrap
                    color: Theme.textPrimary
                    selectedTextColor: Theme.contentBackground
                    selectionColor: Theme.accentColor
                    font.family: "Consolas"
                    font.pixelSize: Theme.fontSizeSmall
                    background: null
                }
            }
        }
    }
}
