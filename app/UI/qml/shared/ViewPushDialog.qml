pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

Popup {
    id: dialog

    property string controllerName: "routing"
    property string hostIp: ""
    property string moduleName: "all"
    property string previewText: ""
    property string messageText: ""
    property bool isPreviewing: false
    property bool isPushing: false
    property var ownerForm: null

    signal pushCompleted(bool ok, string message)

    anchors.centerIn: parent
    width: Math.min(parent ? parent.width - 48 : 820, 860)
    height: Math.min(parent ? parent.height - 48 : 620, 640)
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape

    Overlay.modal: Rectangle { color: Theme.dialogOverlay }

    background: Rectangle {
        color: Theme.contentSurface
        radius: Theme.cardRadius
        border.color: Theme.borderColor
        border.width: Theme.borderWidth
    }

    function controllerTitle() {
        const controller = String(controllerName || "").toLowerCase()
        if (controller === "dhcp")
            return "DHCP"
        return String(moduleName || "all").toUpperCase()
    }

    function notify(message, type) {
        if (ownerForm && ownerForm.notify)
            ownerForm.notify(message, type)
        else if (typeof statusBar !== "undefined")
            statusBar.showMessage(message, type)
    }

    function openPreview() {
        const host = String(hostIp || "").trim()
        if (host === "") {
            notify("Select a device tab before previewing configuration push.", "warning")
            return
        }

        if (!dbManager.previewViewPushAsync) {
            notify("Async preview backend is not available.", "error")
            return
        }

        previewText = ""
        messageText = "Preparing configuration preview..."
        isPreviewing = true
        open()

        const accepted = dbManager.previewViewPushAsync(controllerName, host, moduleName)
        if (!accepted) {
            isPreviewing = false
            messageText = "Cannot start configuration preview."
            notify(messageText, "error")
        }
    }

    function pushNow() {
        if (isPushing)
            return
        const host = String(hostIp || "").trim()
        if (host === "")
            return

        isPushing = true
        if (!dbManager.pushViewPushAsync) {
            isPushing = false
            notify("Async push backend is not available.", "error")
            return
        }

        const accepted = dbManager.pushViewPushAsync(controllerName, host, moduleName)
        if (!accepted) {
            isPushing = false
            notify("Configuration push could not start.", "error")
        }
    }

    Connections {
        target: typeof dbManager !== "undefined" ? dbManager : null
        function onViewPushPreviewFinished(controller, host, module, ok, message, commands) {
            if (String(controller || "") !== String(dialog.controllerName || "").toLowerCase())
                return
            if (String(host || "") !== String(dialog.hostIp || "").trim())
                return
            if (String(module || "all") !== String(dialog.moduleName || "all").toLowerCase())
                return
            if (!dialog.isPreviewing)
                return

            dialog.isPreviewing = false
            dialog.previewText = String(commands || "")
            dialog.messageText = String(message || "")

            if (!ok)
                notify(dialog.messageText || "Cannot preview configuration.", "error")
        }

        function onViewPushFinished(controller, host, module, ok, message) {
            if (String(controller || "") !== String(dialog.controllerName || "").toLowerCase())
                return
            if (String(host || "") !== String(dialog.hostIp || "").trim())
                return
            if (String(module || "all") !== String(dialog.moduleName || "all").toLowerCase())
                return
            if (!dialog.isPushing)
                return

            const msg = String(message || (ok ? "Configuration push completed." : "Configuration push failed."))
            dialog.isPushing = false
            dialog.messageText = msg
            dialog.pushCompleted(ok, msg)

            if (ok)
                dialog.close()
        }
    }

    contentItem: ColumnLayout {
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                Layout.fillWidth: true
                text: "View & Push " + dialog.controllerTitle()
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeTitle
                font.bold: true
                elide: Text.ElideRight
            }

            StandardButton {
                text: "Close"
                type: "Secondary"
                enabled: !dialog.isPushing && !dialog.isPreviewing
                onClicked: dialog.close()
            }
        }

        Text {
            Layout.fillWidth: true
            text: dialog.messageText
            color: dialog.previewText === "" ? Theme.textDisabled : Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            wrapMode: Text.WordWrap
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Theme.contentBackground
            radius: Theme.radiusSmall
            border.color: Theme.borderColor
            border.width: Theme.borderWidth

            TextArea {
                anchors.fill: parent
                anchors.margins: 10
                text: dialog.isPreviewing ? "Preparing configuration preview..." : (dialog.previewText === "" ? "No configuration required for Push." : dialog.previewText)
                readOnly: true
                selectByMouse: true
                wrapMode: TextEdit.NoWrap
                color: dialog.previewText === "" ? Theme.textDisabled : Theme.textPrimary
                selectedTextColor: Theme.selectionForeground
                selectionColor: Theme.selectionBackground
                font.family: "Consolas"
                font.pixelSize: Theme.fontSizeSmall
                background: Rectangle { color: "transparent" }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                Layout.fillWidth: true
                text: dialog.hostIp
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideRight
            }

            StandardButton {
                text: "Refresh"
                icon.source: AppAssets.resource("resources/general/database-reload.svg")
                type: "Secondary"
                enabled: !dialog.isPushing && !dialog.isPreviewing
                onClicked: dialog.openPreview()
            }

            StandardButton {
                text: dialog.isPushing ? "Pushing..." : (dialog.isPreviewing ? "Preparing..." : "Push")
                icon.source: AppAssets.resource("resources/general/push.svg")
                type: "Primary"
                enabled: !dialog.isPushing && !dialog.isPreviewing && dialog.previewText !== ""
                onClicked: dialog.pushNow()
            }
        }
    }
}
