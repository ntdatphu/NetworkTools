pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Basic
import QtQuick.Layouts
import NetworkTools

Popup {
    id: dialog

    property string hostIp: ""
    property string moduleName: "all"
    property string previewText: ""
    property string messageText: ""
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

    function notify(message, type) {
        if (ownerForm && ownerForm.notify)
            ownerForm.notify(message, type)
        else if (typeof statusBar !== "undefined")
            statusBar.showMessage(message, type)
    }

    function openPreview() {
        const host = String(hostIp || "").trim()
        if (host === "") {
            notify("Select a device tab before previewing routing push.", "warning")
            return
        }

        const payload = dbManager.previewRoutingConfig(host, moduleName)
        const ok = payload && (payload.ok === undefined || payload.ok === true)
        previewText = payload && payload.commands ? String(payload.commands) : ""
        messageText = payload && payload.message ? String(payload.message) : ""

        if (!ok) {
            notify(messageText || "Cannot preview routing configuration.", "error")
            return
        }

        open()
    }

    function pushNow() {
        if (isPushing)
            return
        const host = String(hostIp || "").trim()
        if (host === "")
            return

        isPushing = true
        const result = dbManager.pushRoutingConfig(host, moduleName)
        isPushing = false

        const ok = result && (result.ok === undefined || result.ok === true)
        const msg = result && result.message ? String(result.message) : (ok ? "Routing push completed." : "Routing push failed.")
        messageText = msg
        pushCompleted(ok, msg)
        notify(msg, ok ? "success" : "error")

        if (ok)
            close()
    }

    contentItem: ColumnLayout {
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                Layout.fillWidth: true
                text: "View & Push " + dialog.moduleName.toUpperCase()
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeTitle
                font.bold: true
                elide: Text.ElideRight
            }

            StandardButton {
                text: "Close"
                type: "Secondary"
                enabled: !dialog.isPushing
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
                text: dialog.previewText === "" ? "No pending routing configuration to push." : dialog.previewText
                readOnly: true
                selectByMouse: true
                wrapMode: TextEdit.NoWrap
                color: dialog.previewText === "" ? Theme.textDisabled : Theme.textPrimary
                selectedTextColor: Theme.buttonTextSolid
                selectionColor: Theme.accentEmphasis
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
                type: "Secondary"
                enabled: !dialog.isPushing
                onClicked: dialog.openPreview()
            }

            StandardButton {
                text: dialog.isPushing ? "Pushing..." : "Push"
                type: "Primary"
                enabled: !dialog.isPushing && dialog.previewText !== ""
                onClicked: dialog.pushNow()
            }
        }
    }
}
