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
    property var invalidHosts: []
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
    Timer {
        id: validationTimer
        interval: 300
        repeat: false
        onTriggered: dialog.runValidation()
    }

    preferredWidth: 760
    title: "Clone " + protocol.toUpperCase() + " Process"
    subtitle: sourceHost !== ""
              ? "Source: " + sourceHost + " · Copy to connected hosts"
              : "Copy a process to connected hosts"

    function notify(message, type) {
        if (ownerForm && ownerForm.notify)
            ownerForm.notify(message, type)
    }

    function openFor(source, kind) {
        sourceHost = String(source || "").trim()
        protocol = String(kind || "").toLowerCase()
        processRows = dbManager.getRoutingCloneProcesses(sourceHost, protocol)
        const options = dbManager.getRoutingCloneOptions(sourceHost, protocol)
        hostRows = options.hosts || []
        targetModel.clear()
        const defaultId = processRows.length > 0 ? Number(processRows[0].value) : 1
        for (let i = 0; i < hostRows.length; i++) {
            targetModel.append({
                host: String(hostRows[i]),
                selected: false,
                processId: String(defaultId),
                routerId: "",
                duplicate: false,
                processOnly: false,
                validationCode: ""
            })
        }
        duplicateHosts = []
        invalidHosts = []
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
            targetModel.setProperty(i, "routerId", "")
        }
        validationRevision++
        checkDuplicate()
    }

    function validRouterId(value) {
        if (String(value || "").trim() === "")
            return true
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
        const routerIds = {}
        for (let i = 0; i < targetModel.count; i++) {
            const row = targetModel.get(i)
            if (row.selected && (!/^\d+$/.test(String(row.processId))
                    || Number(row.processId) < 1 || !validRouterId(row.routerId)
                    || row.validationCode !== ""))
                return false
            const routerId = String(row.routerId || "").trim()
            if (row.selected && routerId !== "") {
                if (routerIds[routerId])
                    return false
                routerIds[routerId] = true
            }
        }
        return selectedHostCount > 0 && revision >= 0
    }

    function selectedTargets() {
        const targets = []
        for (let i = 0; i < targetModel.count; i++) {
            const row = targetModel.get(i)
            if (row.selected)
                targets.push({host: row.host, processId: Number(row.processId),
                              routerId: row.routerId, processOnly: row.processOnly})
        }
        return targets
    }

    function checkDuplicate() {
        validationTimer.restart()
    }

    function runValidation() {
        if (processCombo.currentIndex < 0)
            return
        const targets = selectedTargets()
        const stableId = Number(processRows[processCombo.currentIndex].stableId)
        const validation = dbManager.validateRoutingCloneTargets(
            sourceHost, protocol, stableId, targets)
        const byHost = {}
        const duplicates = []
        const invalid = []
        const routerOwners = {}
        for (let i = 0; i < validation.length; i++) {
            byHost[String(validation[i].host)] = validation[i]
            if (validation[i].conflictingProcessId)
                duplicates.push(String(validation[i].host))
            if (!validation[i].ok)
                invalid.push(String(validation[i].host) + ": " + String(validation[i].code))
            const selectedRow = targets[i]
            const routerId = selectedRow ? String(selectedRow.routerId || "").trim() : ""
            if (routerId !== "") {
                if (routerOwners[routerId])
                    invalid.push(String(validation[i].host) + ": DUPLICATE_ROUTER_ID")
                else
                    routerOwners[routerId] = String(validation[i].host)
            }
        }
        for (let j = 0; j < targetModel.count; j++) {
            const row = targetModel.get(j)
            targetModel.setProperty(j, "duplicate",
                                    Boolean(byHost[row.host] && byHost[row.host].conflictingProcessId))
            targetModel.setProperty(j, "validationCode",
                                    byHost[row.host] && !byHost[row.host].ok
                                    ? String(byHost[row.host].code) : "")
        }
        duplicateHosts = duplicates
        invalidHosts = invalid
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
            Number(processRows[processCombo.currentIndex].stableId))
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
                Layout.preferredHeight: Math.min(300, Math.max(96, hostList.contentHeight + 42))
                color: Theme.contentBackground
                border.color: Theme.borderColor
                border.width: Theme.borderWidth
                radius: Theme.radiusSmall

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            Layout.preferredWidth: 140
                            text: "Target host"
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                        }
                        Text {
                            Layout.minimumWidth: 100
                            Layout.preferredWidth: 110
                            text: dialog.protocol === "ospf" ? "Process ID" : "AS number"
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                        }
                        Text {
                            Layout.minimumWidth: 130
                            Layout.fillWidth: true
                            text: "Router ID (optional)"
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                        }
                        Text {
                            Layout.preferredWidth: 100
                            text: "Process only"
                            horizontalAlignment: Text.AlignHCenter
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                        }
                        Text {
                            Layout.preferredWidth: 64
                            text: "Status"
                            horizontalAlignment: Text.AlignHCenter
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: Theme.borderWidth
                        color: Theme.borderColor
                    }

                    ListView {
                        id: hostList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
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
                            required property bool processOnly
                            required property string validationCode
                            width: ListView.view.width
                            spacing: 8

                            StandardCheckBox {
                                Layout.preferredWidth: 140
                                text: targetRow.host
                                checked: targetRow.selected
                                onToggled: dialog.updateTarget(targetRow.index, "selected", checked)
                            }
                            StandardTextField {
                                Layout.minimumWidth: 100
                                Layout.preferredWidth: 110
                                placeholderText: dialog.protocol === "ospf" ? "Process ID" : "AS Number"
                                text: targetRow.processId
                                inputMethodHints: Qt.ImhDigitsOnly
                                validator: IntValidator { bottom: 1; top: 2147483647 }
                                onTextEdited: value => dialog.updateTarget(targetRow.index, "processId", value)
                            }
                            StandardTextField {
                                Layout.minimumWidth: 130
                                Layout.fillWidth: true
                                placeholderText: "Optional"
                                text: targetRow.routerId
                                inputMethodHints: Qt.ImhFormattedNumbersOnly
                                onTextEdited: value => dialog.updateTarget(targetRow.index, "routerId", value)
                            }
                            Item {
                                Layout.preferredWidth: 100
                                Layout.fillHeight: true
                                StandardCheckBox {
                                    anchors.centerIn: parent
                                    checked: targetRow.processOnly
                                    Accessible.name: "Process only for " + targetRow.host
                                    onToggled: dialog.updateTarget(targetRow.index, "processOnly", checked)
                                }
                            }
                            Text {
                                Layout.preferredWidth: 64
                                text: {
                                    if (targetRow.validationCode !== "")
                                        return "Invalid"
                                    if (targetRow.duplicate)
                                        return "Exists"
                                    return targetRow.selected ? "Ready" : "—"
                                }
                                horizontalAlignment: Text.AlignHCenter
                                color: targetRow.validationCode !== "" || targetRow.duplicate
                                       ? Theme.alertWarning
                                       : (targetRow.selected ? Theme.alertSuccess : Theme.textDisabled)
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                font.bold: targetRow.selected
                            }
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
        InlineMessage {
            Layout.fillWidth: true
            visible: dialog.invalidHosts.length > 0
            severity: "warning"
            message: "Target validation: " + dialog.invalidHosts.join("; ")
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
