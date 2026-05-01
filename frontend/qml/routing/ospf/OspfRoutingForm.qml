pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import NetworkUI

// Bọc toàn bộ form bằng FormLayout
FormLayout {
    id: ospfRoutingForm

    // Gắn dữ liệu vào Public API của FormLayout
    title: "OSPF Routing"
    hostIp: currentHostIp
    isDirty: hasPendingLocalChanges
    errorMessage: lastError

    property string currentHostIp: ""
    property bool isLoading: false
    property bool isSaving: false
    property bool hasPendingLocalChanges: false
    property bool showValidationDialog: false
    property string validationMessage: ""
    property string lastError: ""
    property string loadedProcessesSignature: "[]"
    property int nextUid: 1
    property var processPayloadByUid: ({})

    ListModel {
        id: processModel
    }

    function notify(message, type) {
        if (typeof statusBar !== "undefined")
            statusBar.showMessage(message, type)
    }

    function showValidation(message) {
        validationMessage = message
        showValidationDialog = true
    }

    function resetProcessModel() {
        processModel.clear()
        processPayloadByUid = ({})
    }

    function processPayloadForUid(processUid) {
        const key = String(processUid)
        return processPayloadByUid[key] !== undefined ? processPayloadByUid[key] : ({})
    }

    function processItems() {
        const items = []
        for (let i = 0; i < processRepeater.count; i++) {
            const item = processRepeater.itemAt(i)
            if (item)
                items.push(item)
        }
        return items
    }

    function currentProcessesSignature() {
        const processes = []
        const items = processItems()
        for (let i = 0; i < items.length; i++) {
            processes.push(items[i].signatureData())
        }
        return JSON.stringify(processes)
    }

    function refreshDirtyFlag() {
        if (isLoading || isSaving)
            return

        hasPendingLocalChanges = currentProcessesSignature() !== loadedProcessesSignature
    }

    function appendProcess(payload) {
        const key = String(nextUid)
        const payloadMap = payload || ({})
        const nextPayloads = Object.assign({}, processPayloadByUid)
        nextPayloads[key] = payloadMap
        processPayloadByUid = nextPayloads

        processModel.append({
            processUid: nextUid,
            processOrder: processModel.count + 1
        })
        nextUid += 1
    }

    function resequenceProcessOrders() {
        for (let i = 0; i < processModel.count; i++) {
            processModel.setProperty(i, "processOrder", i + 1)
        }
    }

    function removeProcessByUid(processUid) {
        const key = String(processUid)
        for (let i = 0; i < processModel.count; i++) {
            const row = processModel.get(i)
            if (Number(row.processUid) === Number(processUid)) {
                processModel.remove(i)
                const nextPayloads = Object.assign({}, processPayloadByUid)
                delete nextPayloads[key]
                processPayloadByUid = nextPayloads
                resequenceProcessOrders()
                Qt.callLater(refreshDirtyFlag)
                return
            }
        }
    }

    function addEmptyProcess() {
        appendProcess({
            process_id: "",
            router_id: "",
            ad: 110,
            default_info: false,
            auto_summary: false,
            networks: []
        })
        Qt.callLater(refreshDirtyFlag)
    }

    function buildProcessesPayload(strictValidation) {
        const items = processItems()
        const payload = []

        for (let i = 0; i < items.length; i++) {
            const validation = items[i].validate(strictValidation)
            if (!validation.ok) {
                lastError = validation.message
                if (strictValidation)
                    showValidation(validation.message)
                return null
            }
            payload.push(items[i].snapshotForSave())
        }

        return payload
    }

    function loadFromDatabase() {
        resetProcessModel()
        lastError = ""
        loadedProcessesSignature = "[]"
        hasPendingLocalChanges = false

        const host = String(currentHostIp || "").trim()
        if (host === "")
            return

        isLoading = true
        const payload = dbManager.getOspfRouting(host)
        const ok = payload && (payload.ok === undefined || payload.ok === true)

        if (!ok) {
            lastError = payload && payload.message ? String(payload.message) : "Load OSPF routing failed."
            notify(lastError, "error")
            isLoading = false
            return
        }

        const processes = payload.processes ? payload.processes : []
        for (let i = 0; i < processes.length; i++) {
            appendProcess(processes[i])
        }

        Qt.callLater(function() {
            ospfRoutingForm.loadedProcessesSignature = ospfRoutingForm.currentProcessesSignature()
            ospfRoutingForm.hasPendingLocalChanges = false
            ospfRoutingForm.isLoading = false
        })
    }

    function saveToDatabase() {
        if (isLoading || isSaving)
            return false

        const host = String(currentHostIp || "").trim()
        if (host === "") {
            notify("Select a device tab before saving OSPF.", "warning")
            return false
        }

        const payload = buildProcessesPayload(true)
        if (payload === null)
            return false

        isSaving = true
        const ok = dbManager.saveOspfRouting(host, payload)
        isSaving = false

        if (ok) {
            lastError = ""
            loadFromDatabase()
            notify("Saved OSPF routing for host " + host, "success")
            return true
        }

        lastError = "Save OSPF routing failed."
        notify(lastError, "error")
        return false
    }

    function cancelAllChanges() {
        if (isLoading || isSaving)
            return false

        loadFromDatabase()
        notify("Discarded local OSPF changes.", "info")
        return true
    }

    onCurrentHostIpChanged: loadFromDatabase()
    Component.onCompleted: loadFromDatabase()

    // ── NỘI DUNG CHÍNH (Body) ──
    Text {
        visible: String(ospfRoutingForm.currentHostIp || "").trim() === ""
        Layout.leftMargin: 24
        Layout.rightMargin: 24
        Layout.topMargin: 18
        Layout.fillWidth: true
        text: "Select a device tab to load OSPF configuration."
        color: Theme.textDisabled
        font.pixelSize: Theme.fontSizeNormal
        font.family: Theme.fontFamily
        horizontalAlignment: Text.AlignHCenter
    }

    Text {
        visible: !ospfRoutingForm.isLoading
            && String(ospfRoutingForm.currentHostIp || "").trim() !== ""
            && processModel.count === 0
        Layout.leftMargin: 24
        Layout.rightMargin: 24
        Layout.topMargin: 18
        Layout.fillWidth: true
        text: "No OSPF process saved. Use Add Process to create one."
        color: Theme.textDisabled
        font.pixelSize: Theme.fontSizeNormal
        font.family: Theme.fontFamily
        horizontalAlignment: Text.AlignHCenter
    }

    Repeater {
        id: processRepeater
        model: processModel

        delegate: OspfProcessCard {
            required property int processUid
            required property int processOrder
            Layout.fillWidth: true
            Layout.leftMargin: 24
            Layout.rightMargin: 24
            property int modelUid: processUid
            processIndex: processOrder
            payload: ospfRoutingForm.processPayloadForUid(modelUid)

            onRemoveRequested: {
                ospfRoutingForm.removeProcessByUid(modelUid)
            }

            onCardChanged: ospfRoutingForm.refreshDirtyFlag()
        }
    }

    Item { height: 8 }

    // ── FOOTER (Nút Bấm) ──
    footer: [
        StandardButton {
            text: "+ Add Process"
            type: "Primary"
            onClicked: ospfRoutingForm.addEmptyProcess()
        },
        Item { Layout.fillWidth: true },
        StandardButton {
            text: "Reload"
            type: "Secondary"
            onClicked: {
                ospfRoutingForm.loadFromDatabase()
                ospfRoutingForm.notify("Reloaded OSPF routing from database.", "info")
            }
        },
        StandardButton {
            text: "Cancel Changes"
            type: "Secondary"
            enabled: hasPendingLocalChanges
            onClicked: ospfRoutingForm.cancelAllChanges()
        },
        StandardButton {
            text: isSaving ? "Saving..." : "Save OSPF"
            type: "Primary"
            enabled: hasPendingLocalChanges && !isLoading && !isSaving
            onClicked: ospfRoutingForm.saveToDatabase()
        }
    ]

    StandardValidationDialog {
        id: validationDialog
        visible: ospfRoutingForm.showValidationDialog
        titleText: "OSPF Validation Error"
        messageText: ospfRoutingForm.validationMessage

        onAccepted: {
            ospfRoutingForm.showValidationDialog = false
        }

        onClosed: {
            ospfRoutingForm.showValidationDialog = false
        }
    }
}