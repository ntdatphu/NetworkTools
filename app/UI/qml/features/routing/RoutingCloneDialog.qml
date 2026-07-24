pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

StandardDialog {
    id: dialog

    property string protocol: "ospf"
    property string sourceHost: ""
    property var ownerForm: null
    property var processRows: []
    property var hostRows: []
    property var duplicateHosts: []
    property string operationMessage: ""
    property int validationRevision: 0
    readonly property int selectedHostCount: {
        const revision = validationRevision
        let count = 0
        for (let i = 0; i < targetModel.count; i++)
            if (targetModel.get(i).selected) count++
        return count + (revision >= 0 ? 0 : 0)
    }

    ListModel { id: targetModel }

    preferredWidth: 560
    title: "Clone " + protocol.toUpperCase() + " Process"
    subtitle: "Copy a process to multiple connected hosts"

    function notify(message, type) {
        if (ownerForm && ownerForm.notify)
            ownerForm.notify(message, type)
    }

    function openFor(source, kind) {
        sourceHost = String(source || "").trim()
        protocol = String(kind || "").toLowerCase()
        processRows = dbManager.getRoutingCloneProcesses(sourceHost, protocol)
        const options = dbManager.getRoutingCloneOptions(protocol)
        hostRows = options.hosts || []
        targetModel.clear()
        const defaultId = processRows.length > 0 ? Number(processRows[0].value) : 1
        const defaultRouterId = processRows.length > 0 ? String(processRows[0].routerId || "") : ""
        for (let i = 0; i < hostRows.length; i++) {
            targetModel.append({
                host: String(hostRows[i]),
                selected: false,
                processId: String(defaultId),
                routerId: defaultRouterId,
                duplicate: false
            })
        }
        duplicateHosts = []
        operationMessage = ""
        processCombo.model = processRows.map(row => row.label)
        processCombo.currentIndex = processRows.length > 0 ? 0 : -1
        checkDuplicate()
        open()
    }

    function updateTarget(index, role, value) {
        targetModel.setProperty(index, role, value)
        validationRevision++
        checkDuplicate()
    }

    function selectAllHosts(selected) {
        for (let i = 0; i < targetModel.count; i++)
            targetModel.setProperty(i, "selected", selected)
        validationRevision++
        checkDuplicate()
    }

    function resetTargetDefaults() {
        if (processCombo.currentIndex < 0)
            return
        const process = processRows[processCombo.currentIndex]
        for (let i = 0; i < targetModel.count; i++) {
            targetModel.setProperty(i, "processId", String(process.value))
            targetModel.setProperty(i, "routerId", String(process.routerId || ""))
        }
        validationRevision++
        checkDuplicate()
    }

    function validRouterId(value) {
        const parts = String(value || "").trim().split(".")
        if (parts.length !== 4)
            return false
        for (let i = 0; i < parts.length; i++) {
            if (!/^\d+$/.test(parts[i]) || Number(parts[i]) < 0 || Number(parts[i]) > 255)
                return false
        }
        return true
    }

    function selectedTargetsValid() {
        const revision = validationRevision
        for (let i = 0; i < targetModel.count; i++) {
            const row = targetModel.get(i)
            if (row.selected && (!/^\d+$/.test(String(row.processId))
                    || Number(row.processId) < 1 || !validRouterId(row.routerId) || row.duplicate))
                return false
        }
        return selectedHostCount > 0 && revision >= 0
    }

    function selectedTargets() {
        const targets = []
        for (let i = 0; i < targetModel.count; i++) {
            const row = targetModel.get(i)
            if (row.selected)
                targets.push({host: row.host, processId: Number(row.processId), routerId: row.routerId})
        }
        return targets
    }

    function checkDuplicate() {
        const duplicates = []
        for (let i = 0; i < targetModel.count; i++) {
            const row = targetModel.get(i)
            const duplicate = row.selected && /^\d+$/.test(String(row.processId))
                    && dbManager.routingCloneProcessExists(row.host, protocol, Number(row.processId))
            targetModel.setProperty(i, "duplicate", duplicate)
            if (duplicate)
                duplicates.push(row.host)
        }
        duplicateHosts = duplicates
    }

    function saveClone(pushAfterSave) {
        const targets = selectedTargets()
        if (processCombo.currentIndex < 0 || targets.length === 0)
            return
        if (duplicateHosts.length > 0) {
            notify("Choose another Process ID; it already exists on: " + duplicateHosts.join(", "), "warning")
            return
        }
        const result = dbManager.cloneRoutingTargets(
            sourceHost, targets, protocol,
            Number(processRows[processCombo.currentIndex].index))
        let details = String(result.message || "")
        if (result.failed && result.failed.length > 0) {
            const reasons = result.failed.map(item => item.host + ": " + item.reason)
            details += " " + reasons.join("; ")
        }
        notify(details, result.ok ? "success" : (result.partial ? "warning" : "error"))
        if (result.ok || result.partial) {
            if (ownerForm && ownerForm.loadFromDatabase
                    && (result.successful || []).indexOf(sourceHost) >= 0)
                ownerForm.loadFromDatabase()
            close()
            if (pushAfterSave)
                batchViewPushDialog.openPreview(result.successful || [], protocol)
        }
    }

    contentItem: ColumnLayout {
        spacing: 14

        StandardComboBox {
            id: processCombo
            Layout.fillWidth: true
            labelText: "1. " + dialog.protocol.toUpperCase() + " Process"
            onActivated: dialog.resetTargetDefaults()
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: "2. Target Hosts (success = 1) · " + dialog.selectedHostCount + " selected"
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                }
                StandardButton {
                    text: dialog.selectedHostCount === dialog.hostRows.length ? "Clear all" : "Select all"
                    type: "Text"
                    onClicked: dialog.selectAllHosts(dialog.selectedHostCount !== dialog.hostRows.length)
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(260, Math.max(64, hostList.contentHeight + 12))
                color: Theme.contentBackground
                border.color: Theme.borderColor
                border.width: Theme.borderWidth
                radius: Theme.radiusSmall

                ListView {
                    id: hostList
                    anchors.fill: parent
                    anchors.margins: 6
                    clip: true
                    model: targetModel
                    spacing: 6
                    delegate: RowLayout {
                        id: targetRow
                        required property int index
                        required property string host
                        required property bool selected
                        required property string processId
                        required property string routerId
                        required property bool duplicate
                        width: ListView.view.width
                        spacing: 8

                        StandardCheckBox {
                            Layout.preferredWidth: 150
                            text: targetRow.host
                            checked: targetRow.selected
                            onToggled: dialog.updateTarget(targetRow.index, "selected", checked)
                        }
                        StandardTextField {
                            Layout.fillWidth: true
                            placeholderText: dialog.protocol === "ospf" ? "Process ID" : "AS Number"
                            text: targetRow.processId
                            inputMethodHints: Qt.ImhDigitsOnly
                            validator: IntValidator { bottom: 1; top: 2147483647 }
                            onTextEdited: value => dialog.updateTarget(targetRow.index, "processId", value)
                        }
                        StandardTextField {
                            Layout.fillWidth: true
                            placeholderText: "Router ID"
                            text: targetRow.routerId
                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                            onTextEdited: value => dialog.updateTarget(targetRow.index, "routerId", value)
                        }
                        Text {
                            Layout.preferredWidth: 18
                            text: targetRow.duplicate ? "!" : ""
                            color: Theme.alertWarning
                            font.bold: true
                        }
                    }
                }
            }
        }
        InlineMessage {
            Layout.fillWidth: true
            visible: dialog.duplicateHosts.length > 0
            severity: "warning"
            message: "This Process ID already exists on: " + dialog.duplicateHosts.join(", ")
        }
        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            StandardButton {
                text: "Cancel"
                type: "Text"
                onClicked: dialog.close()
            }
            StandardButton {
                text: "Save"
                icon.source: AppAssets.actionSave
                type: "Secondary"
                enabled: processCombo.currentIndex >= 0 && dialog.selectedTargetsValid()
                onClicked: dialog.saveClone(false)
            }
            StandardButton {
                text: "Save & Push"
                icon.source: AppAssets.actionSave
                type: "Primary"
                enabled: processCombo.currentIndex >= 0 && dialog.selectedTargetsValid()
                onClicked: dialog.saveClone(true)
            }
        }
    }

    RoutingBatchViewPushDialog {
        id: batchViewPushDialog
        parent: Overlay.overlay
        ownerForm: dialog.ownerForm
    }
}
