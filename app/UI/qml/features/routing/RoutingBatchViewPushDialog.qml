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
        const previews = []
        const errors = []
        for (let i = 0; i < hosts.length; i++) {
            const host = String(hosts[i])
            const result = dbManager.previewViewPush("routing", host, protocol)
            if (result.ok) {
                previews.push("# Device: " + host + "\n" + String(result.commands || "# No commands"))
            } else {
                errors.push(host + ": " + String(result.message || "Preview failed"))
            }
        }
        previewText = previews.join("\n\n")
        messageText = errors.length === 0
                ? "Review the commands below, then press Push."
                : "Some previews failed: " + errors.join("; ")
        open()
    }

    function pushNow() {
        const pending = {}
        results = []
        for (let i = 0; i < hosts.length; i++)
            pending[String(hosts[i])] = true
        pendingHosts = pending
        isPushing = true
        messageText = "Pushing configuration to " + hosts.length + " device(s)..."
        for (let i = 0; i < hosts.length; i++) {
            const host = String(hosts[i])
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
                enabled: !dialog.isPushing && dialog.previewText !== ""
                onClicked: dialog.pushNow()
            }
        }
    }
}
