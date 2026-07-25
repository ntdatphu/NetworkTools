pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

StandardDialog {
    id: dialog

    property string protocol: "ospf"
    property var hosts: []
    property var pendingHosts: ({})
    property var results: []
    property var previewResults: ({})
    property var pendingPreviews: ({})
    property string previewText: ""
    property string messageText: ""
    property bool isPushing: false
    property var ownerForm: null

    preferredWidth: 880
    height: Math.min(parent ? parent.height - 48 : 650, 680)
    title: "View & Push " + protocol.toUpperCase()
    subtitle: hosts.length + " target device(s)"
    closeEnabled: !isPushing

    function notify(message, type) {
        if (ownerForm && ownerForm.notify)
            ownerForm.notify(message, type)
    }

    function openPreview(targetHosts, kind) {
        hosts = targetHosts || []
        protocol = String(kind || "").toLowerCase()
        results = []
        pendingHosts = ({})
        previewResults = ({})
        const pending = {}
        for (let i = 0; i < hosts.length; i++)
            pending[String(hosts[i])] = true
        pendingPreviews = pending
        for (let i = 0; i < hosts.length; i++) {
            const host = String(hosts[i])
            if (!dbManager.previewViewPushAsync("routing", host, protocol))
                recordPreview(host, false, "Preview task could not start.", "")
        }
        previewText = ""
        messageText = "Preparing previews for " + hosts.length + " device(s)..."
        open()
    }

    function recordPreview(host, ok, message, commands) {
        if (pendingPreviews[String(host)] !== true)
            return
        const pending = Object.assign({}, pendingPreviews)
        delete pending[String(host)]
        pendingPreviews = pending
        const next = Object.assign({}, previewResults)
        next[String(host)] = {ok: Boolean(ok), message: String(message || ""),
                              commands: String(commands || "")}
        previewResults = next
        const previews = []
        const errors = []
        const keys = Object.keys(next)
        for (let i = 0; i < keys.length; i++) {
            const item = next[keys[i]]
            if (item.ok)
                previews.push("# Device: " + keys[i] + "\n" + (item.commands || "# No commands"))
            else
                errors.push(keys[i] + ": " + (item.message || "Preview failed"))
        }
        previewText = previews.join("\n\n")
        if (Object.keys(pending).length === 0)
            messageText = errors.length === 0
                    ? "Review the commands below, then press Push."
                    : "Some previews failed: " + errors.join("; ")
    }

    function pushNow() {
        const readyHosts = hosts.filter(host => previewResults[String(host)]
                                        && previewResults[String(host)].ok)
        const pending = {}
        results = []
        for (let i = 0; i < readyHosts.length; i++)
            pending[String(readyHosts[i])] = true
        pendingHosts = pending
        isPushing = true
        messageText = "Pushing configuration to " + readyHosts.length + " device(s)..."
        for (let i = 0; i < readyHosts.length; i++) {
            const host = String(readyHosts[i])
            if (!dbManager.pushViewPushAsync("routing", host, protocol))
                recordResult(host, false, "Push task could not start.")
        }
    }

    function recordResult(host, ok, message) {
        if (pendingHosts[String(host)] !== true)
            return
        const pending = Object.assign({}, pendingHosts)
        delete pending[String(host)]
        pendingHosts = pending
        const next = results.slice()
        next.push({host: String(host), ok: Boolean(ok), message: String(message || "")})
        results = next
        if (Object.keys(pending).length === 0) {
            isPushing = false
            const succeeded = next.filter(item => item.ok)
            const failed = next.filter(item => !item.ok)
            messageText = "Push completed: " + succeeded.length + " succeeded, "
                    + failed.length + " failed."
            if (failed.length > 0)
                messageText += " " + failed.map(item => item.host + ": " + item.message).join("; ")
            notify(messageText, failed.length === 0 ? "success" : "warning")
        }
    }

    Connections {
        target: typeof dbManager !== "undefined" ? dbManager : null
        function onViewPushPreviewFinished(controller, host, module, ok, message, commands) {
            if (String(controller) === "routing" && String(module) === dialog.protocol)
                dialog.recordPreview(String(host), ok, message, commands)
        }
        function onViewPushFinished(controller, host, module, ok, message) {
            if (String(controller) === "routing" && String(module) === dialog.protocol)
                dialog.recordResult(String(host), ok, message)
        }
    }

    contentItem: ColumnLayout {
        spacing: 12
        InlineMessage {
            Layout.fillWidth: true
            message: dialog.messageText
            busy: dialog.isPushing
            severity: dialog.results.some(item => !item.ok) ? "warning" : "info"
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Theme.contentBackground
            border.color: Theme.borderColor
            border.width: Theme.borderWidth
            radius: Theme.radiusSmall
            TextArea {
                anchors.fill: parent
                anchors.margins: 10
                text: dialog.previewText
                readOnly: true
                selectByMouse: true
                wrapMode: TextEdit.NoWrap
                color: Theme.textPrimary
                font.family: "Consolas"
                font.pixelSize: Theme.fontSizeSmall
                background: Rectangle { color: "transparent" }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            StandardButton { text: "Close"; type: "Text"; enabled: !dialog.isPushing; onClicked: dialog.close() }
            StandardButton {
                text: dialog.isPushing ? "Pushing..." : "Push"
                icon.source: AppAssets.actionPush
                type: "Primary"
            enabled: !dialog.isPushing && Object.keys(dialog.pendingPreviews).length === 0
                     && Object.keys(dialog.previewResults).some(
                         host => dialog.previewResults[host].ok)
                onClicked: dialog.pushNow()
            }
        }
    }
}
