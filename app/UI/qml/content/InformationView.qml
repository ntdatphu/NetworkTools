pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

Rectangle {
    id: root
    objectName: "informationView"

    property string currentHostIp: ""
    property string configText: ""
    property string configPath: ""
    property string loadError: ""
    property bool isLoadingLive: false
    property string loadingHost: ""
    property string lastLoadedHost: ""
    property string lastReloadReason: ""
    property double lastLoadStartedAt: 0
    property bool reloadQueued: false
    property int reloadCoalesceWindowMs: 250
    readonly property string runningConfigCommand: "show running-config"
    readonly property bool isViewLoading: root.isLoadingLive
                                          || informationConfigViewer.highlightingInProgress

    color: Theme.contentBackground

    function clearContent() {
        root.configText = ""
        root.configPath = ""
        root.loadError = ""
    }

    function reloadData(reason, force) {
        const host = String(root.currentHostIp || "").trim()
        const reloadReason = String(reason || "manual")
        if (host === "") {
            root.reloadQueued = false
            root.lastLoadedHost = ""
            root.clearContent()
            return false
        }

        // A running command cannot be cancelled safely. A host switch queues
        // one reload for the new host; repeated activation of the same host is
        // coalesced without starting another command.
        if (root.isLoadingLive) {
            if (host !== root.loadingHost)
                root.reloadQueued = true
            return false
        }

        const now = Date.now()
        if (force !== true
                && host === root.lastLoadedHost
                && now - root.lastLoadStartedAt < root.reloadCoalesceWindowMs)
            return false

        root.clearContent()
        root.lastLoadedHost = host
        root.lastReloadReason = reloadReason
        root.lastLoadStartedAt = now

        if (typeof cli !== "undefined"
                && cli.hasDeviceSession
                && cli.runDeviceCommandAsync
                && cli.hasDeviceSession(host)) {
            root.isLoadingLive = true
            root.loadingHost = host
            root.configPath = "active tab session"
            const accepted = cli.runDeviceCommandAsync(host, root.runningConfigCommand)
            if (!accepted) {
                root.isLoadingLive = false
                root.loadingHost = ""
                root.loadError = "Load running-config from active session could not start."
            }
            return accepted
        }

        const payload = dbManager.getRunningConfigBackup(host)
        const ok = payload && (payload.ok === undefined || payload.ok === true)
        root.configPath = payload && payload.path ? String(payload.path) : ""

        if (ok) {
            root.configText = payload && payload.content ? String(payload.content) : ""
        } else {
            root.loadError = payload && payload.message ? String(payload.message) : "Load running-config backup failed."
        }
        return true
    }

    Connections {
        target: typeof cli !== "undefined" ? cli : null
        function onDeviceCommandFinished(host, command, ok, message, output) {
            if (String(command || "") !== root.runningConfigCommand)
                return
            if (String(host || "") !== root.loadingHost)
                return

            root.isLoadingLive = false
            root.loadingHost = ""
            const currentHost = String(root.currentHostIp || "").trim()
            if (String(host || "") !== currentHost) {
                if (root.reloadQueued && currentHost !== "") {
                    root.reloadQueued = false
                    Qt.callLater(function() { root.reloadData("queued-host-change") })
                }
                return
            }

            root.reloadQueued = false
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

    onCurrentHostIpChanged: reloadData("host-change")
    Component.onCompleted: {
        if (root.lastLoadedHost !== String(root.currentHostIp || "").trim())
            root.reloadData("initial")
    }

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
                objectName: "informationReloadButton"
                text: "Reload"
                icon.source: AppAssets.actionBackup
                type: "Secondary"
                enabled: String(root.currentHostIp || "").trim() !== ""
                         && !root.isLoadingLive
                onClicked: root.reloadData("manual", true)
            }

            StandardButton {
                objectName: "informationCopyAllButton"
                Layout.preferredWidth: 104
                text: informationConfigViewer.copyFeedbackVisible ? "Copied" : "Copy All"
                icon.source: AppAssets.actionCopy
                type: "Secondary"
                enabled: root.configText !== ""
                onClicked: informationConfigViewer.copyAll()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.radiusSmall
            color: Theme.contentPanelSurface
            border.color: Theme.contentPanelBorder
            border.width: Theme.borderWidth

            ConfigTextViewer {
                id: informationConfigViewer
                objectName: "informationConfigViewer"
                anchors.fill: parent
                anchors.margins: Theme.spacing12
                text: root.configText
                sourceLabel: root.configPath !== ""
                             ? "Running configuration · " + root.configPath
                             : "Running configuration"
                loading: root.isLoadingLive
                         && root.loadingHost === String(root.currentHostIp || "").trim()
                loadingText: "Loading running-config from active session..."
                errorText: root.loadError
                emptyText: root.currentHostIp === ""
                           ? "Choose a device to view its running-config backup."
                           : "No running-config data is available."
            }
        }
    }
}
