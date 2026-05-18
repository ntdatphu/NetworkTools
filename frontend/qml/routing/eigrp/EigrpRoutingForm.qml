pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import NetworkTools

// Bọc toàn bộ form bằng FormLayout
FormLayout {
    id: eigrpRoutingForm

    // Gắn dữ liệu vào Public API của FormLayout
    title: "EIGRP Routing"
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
    property int statsRevision: 0
    property string activeRoutingSection: "Process"
    property int selectedNetworkProcessIndex: 0
    property var processOptions: []
    property var processPayloadByUid: ({})

    component SectionTab: Rectangle {
        id: sectionTab
        property string label: ""
        property bool selected: false
        signal clicked()

        implicitWidth: Math.max(92, labelText.implicitWidth + 28)
        implicitHeight: 28
        radius: Theme.radiusRound
        color: selected ? Theme.sideBarItemSelected : (tabHover.hovered ? Theme.sideBarItemHover : "transparent")
        border.color: selected ? Theme.accentColor : Theme.borderColor
        border.width: Theme.borderWidth

        Behavior on color { ColorAnimation { duration: Theme.animationDurationFast } }
        Behavior on border.color { ColorAnimation { duration: Theme.animationDurationFast } }

        Text {
            id: labelText
            anchors.centerIn: parent
            text: sectionTab.label
            color: sectionTab.selected ? Theme.accentColor : Theme.textSecondary
            font.pixelSize: Theme.fontSizeSmall
            font.family: Theme.fontFamily
            font.bold: sectionTab.selected
        }

        HoverHandler {
            id: tabHover
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: sectionTab.clicked()
        }
    }

    ListModel { id: processModel }

    function notify(message, type) {
        if (typeof statusBar !== "undefined") statusBar.showMessage(message, type)
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
            if (item) items.push(item)
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
        if (isLoading || isSaving) return
        hasPendingLocalChanges = currentProcessesSignature() !== loadedProcessesSignature
    }

    function refreshStats() {
        statsRevision += 1
    }

    function processOptionLabel(index) {
        const item = processRepeater.itemAt(index)
        const host = String(currentHostIp || "").trim()
        if (!item)
            return "Process " + (index + 1)

        const asText = String(item.processId || "").trim()
        const processText = asText !== "" ? ("AS " + asText) : ("Process " + (index + 1))
        return (host !== "" ? host : "Host") + " / " + processText
    }

    function rebuildProcessOptions() {
        const options = []
        for (let i = 0; i < processRepeater.count; i++) {
            options.push(processOptionLabel(i))
        }
        processOptions = options

        if (processOptions.length === 0) {
            selectedNetworkProcessIndex = 0
        } else if (selectedNetworkProcessIndex >= processOptions.length) {
            selectedNetworkProcessIndex = processOptions.length - 1
        }
    }

    function selectedNetworkProcessItem() {
        if (selectedNetworkProcessIndex < 0 || selectedNetworkProcessIndex >= processRepeater.count)
            return null
        return processRepeater.itemAt(selectedNetworkProcessIndex)
    }

    function totalNetworkCount() {
        const revision = statsRevision
        let total = 0
        const items = processItems()
        for (let i = 0; i < items.length; i++) {
            total += items[i].networks.count
        }
        return total
    }

    function handleCardChanged() {
        refreshDirtyFlag()
        refreshStats()
        rebuildProcessOptions()
    }

    function addNetworkToSelectedProcess(network, wildcard) {
        const item = selectedNetworkProcessItem()
        if (!item) {
            notify("Create an EIGRP process before adding networks.", "warning")
            return false
        }

        const networkText = String(network || "").trim()
        const wildcardText = String(wildcard || "").trim()
        if (networkText === "" || wildcardText === "") {
            notify("Network and wildcard are required.", "warning")
            return false
        }

        item.networks.append({
            network: networkText,
            wildcard: wildcardText,
            area: ""
        })
        handleCardChanged()
        notify("Added EIGRP network to " + processOptionLabel(selectedNetworkProcessIndex) + ".", "info")
        return true
    }

    function removeNetworkFromSelectedProcess(rowIndex) {
        const item = selectedNetworkProcessItem()
        if (!item || rowIndex < 0 || rowIndex >= item.networks.count)
            return

        item.networks.remove(rowIndex)
        handleCardChanged()
        notify("Removed EIGRP network from " + processOptionLabel(selectedNetworkProcessIndex) + ".", "warning")
    }

    function selectRoutingSection(sectionName) {
        activeRoutingSection = sectionName
        if (sectionName !== "Process" && sectionName !== "Networks")
            notify(sectionName + " UI is planned for the next data phase.", "info")
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
        Qt.callLater(rebuildProcessOptions)
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
                notify("Removed EIGRP process " + row.processOrder + " from the local editor.", "warning")
                refreshStats()
                Qt.callLater(rebuildProcessOptions)
                Qt.callLater(refreshDirtyFlag)
                return
            }
        }
    }

    function addEmptyProcess() {
        appendProcess({
            as_number:         "",
            router_id:         "",
            auto_summary:      false,
            passive_default:   false,
            use_metric_weights: false,
            metric_weights:    "0 1 0 1 0 0",
            distance_internal: 0,
            distance_external: 0,
            networks:          []
        })
        notify("Added a new EIGRP process card.", "info")
        refreshStats()
        Qt.callLater(rebuildProcessOptions)
        Qt.callLater(refreshDirtyFlag)
    }

    function buildProcessesPayload(strictValidation) {
        const items = processItems()
        const payload = []

        for (let i = 0; i < items.length; i++) {
            const validation = items[i].validate(strictValidation)
            if (!validation.ok) {
                lastError = validation.message
                if (strictValidation) showValidation(validation.message)
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
        if (host === "") return

        isLoading = true
        const payload = dbManager.getEigrpRouting(host)
        const ok = payload && (payload.ok === undefined || payload.ok === true)

        if (!ok) {
            lastError = payload && payload.message ? String(payload.message) : "Load EIGRP routing failed."
            notify(lastError, "error")
            isLoading = false
            return
        }

        const processes = payload.processes ? payload.processes : []
        for (let i = 0; i < processes.length; i++) {
            appendProcess(processes[i])
        }

        Qt.callLater(function() {
            eigrpRoutingForm.loadedProcessesSignature = eigrpRoutingForm.currentProcessesSignature()
            eigrpRoutingForm.hasPendingLocalChanges = false
            eigrpRoutingForm.isLoading = false
            eigrpRoutingForm.refreshStats()
            eigrpRoutingForm.rebuildProcessOptions()
        })
    }

    function saveToDatabase() {
        if (isLoading || isSaving) return false

        const host = String(currentHostIp || "").trim()
        if (host === "") {
            notify("Select a device tab before saving EIGRP.", "warning")
            return false
        }

        const payload = buildProcessesPayload(true)
        if (payload === null) return false

        isSaving = true
        const ok = dbManager.saveEigrpRouting(host, payload)
        isSaving = false

        if (ok) {
            lastError = ""
            loadFromDatabase()
            notify("Saved EIGRP routing for host " + host, "success")
            return true
        }

        lastError = "Save EIGRP routing failed."
        notify(lastError, "error")
        return false
    }

    function cancelAllChanges() {
        if (isLoading || isSaving) return false
        loadFromDatabase()
        notify("Discarded local EIGRP changes.", "info")
        refreshStats()
        return true
    }

    onCurrentHostIpChanged: loadFromDatabase()
    Component.onCompleted: loadFromDatabase()

    // ── NỘI DUNG CHÍNH (Body) ──
    Text {
        visible: String(eigrpRoutingForm.currentHostIp || "").trim() === ""
        Layout.leftMargin: 24
        Layout.rightMargin: 24
        Layout.topMargin: 18
        Layout.fillWidth: true
        text: "Select a device tab to load EIGRP configuration."
        color: Theme.textDisabled
        font.pixelSize: Theme.fontSizeNormal
        font.family: Theme.fontFamily
        horizontalAlignment: Text.AlignHCenter
    }

    Text {
        visible: !eigrpRoutingForm.isLoading
            && String(eigrpRoutingForm.currentHostIp || "").trim() !== ""
            && processModel.count === 0
            && (eigrpRoutingForm.activeRoutingSection === "Process"
                || eigrpRoutingForm.activeRoutingSection === "Networks")
        Layout.leftMargin: 24
        Layout.rightMargin: 24
        Layout.topMargin: 18
        Layout.fillWidth: true
        text: "No EIGRP process saved. Use Add Process to create one."
        color: Theme.textDisabled
        font.pixelSize: Theme.fontSizeNormal
        font.family: Theme.fontFamily
        horizontalAlignment: Text.AlignHCenter
    }

    GridLayout {
        visible: String(eigrpRoutingForm.currentHostIp || "").trim() !== ""
        Layout.fillWidth: true
        Layout.leftMargin: 24
        Layout.rightMargin: 24
        Layout.topMargin: 6
        columns: width < 760 ? 2 : 4
        columnSpacing: Theme.spacing12
        rowSpacing: Theme.spacing12

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 76
            radius: Theme.cardRadius
            color: Theme.contentPanelSurface
            border.color: Theme.contentPanelBorder
            border.width: Theme.borderWidth

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacing12
                spacing: Theme.spacing2

                Text { text: "EIGRP AS"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSmall; font.family: Theme.fontFamily; font.bold: true }
                Text { text: String(processModel.count); color: Theme.textPrimary; font.pixelSize: Theme.fontSizeTitle; font.family: Theme.fontFamily; font.bold: true }
                Text { text: "configured"; color: Theme.textDisabled; font.pixelSize: Theme.fontSizeSmall; font.family: Theme.fontFamily }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 76
            radius: Theme.cardRadius
            color: Theme.contentPanelSurface
            border.color: Theme.contentPanelBorder
            border.width: Theme.borderWidth

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacing12
                spacing: Theme.spacing2

                Text { text: "NETWORKS"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSmall; font.family: Theme.fontFamily; font.bold: true }
                Text { text: String(eigrpRoutingForm.totalNetworkCount()); color: Theme.accentColor; font.pixelSize: Theme.fontSizeTitle; font.family: Theme.fontFamily; font.bold: true }
                Text { text: "advertised entries"; color: Theme.textDisabled; font.pixelSize: Theme.fontSizeSmall; font.family: Theme.fontFamily }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 76
            radius: Theme.cardRadius
            color: Theme.contentPanelSurface
            border.color: Theme.contentPanelBorder
            border.width: Theme.borderWidth

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacing12
                spacing: Theme.spacing2

                Text { text: "HOST"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSmall; font.family: Theme.fontFamily; font.bold: true }
                Text { Layout.fillWidth: true; text: eigrpRoutingForm.currentHostIp; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeLarge; font.family: Theme.fontFamily; font.bold: true; elide: Text.ElideRight }
                Text { text: "selected device"; color: Theme.textDisabled; font.pixelSize: Theme.fontSizeSmall; font.family: Theme.fontFamily }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 76
            radius: Theme.cardRadius
            color: Theme.contentPanelSurface
            border.color: eigrpRoutingForm.hasPendingLocalChanges ? Theme.alertWarning : Theme.contentPanelBorder
            border.width: Theme.borderWidth

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacing12
                spacing: Theme.spacing2

                Text { text: "STATE"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSmall; font.family: Theme.fontFamily; font.bold: true }
                Text { text: eigrpRoutingForm.hasPendingLocalChanges ? "DIRTY" : "SYNC"; color: eigrpRoutingForm.hasPendingLocalChanges ? Theme.alertWarning : Theme.alertSuccess; font.pixelSize: Theme.fontSizeTitle; font.family: Theme.fontFamily; font.bold: true }
                Text { text: eigrpRoutingForm.hasPendingLocalChanges ? "pending save" : "database"; color: Theme.textDisabled; font.pixelSize: Theme.fontSizeSmall; font.family: Theme.fontFamily }
            }
        }
    }

    RowLayout {
        visible: String(eigrpRoutingForm.currentHostIp || "").trim() !== ""
        Layout.fillWidth: true
        Layout.leftMargin: 24
        Layout.rightMargin: 24
        spacing: Theme.spacing4

        SectionTab {
            label: "Process"
            selected: eigrpRoutingForm.activeRoutingSection === "Process"
            onClicked: eigrpRoutingForm.selectRoutingSection("Process")
        }

        SectionTab {
            label: "Networks"
            selected: eigrpRoutingForm.activeRoutingSection === "Networks"
            onClicked: eigrpRoutingForm.selectRoutingSection("Networks")
        }

        SectionTab {
            label: "Interfaces"
            selected: eigrpRoutingForm.activeRoutingSection === "Interfaces"
            onClicked: eigrpRoutingForm.selectRoutingSection("Interfaces")
        }

        SectionTab {
            label: "Passive iface"
            selected: eigrpRoutingForm.activeRoutingSection === "Passive iface"
            onClicked: eigrpRoutingForm.selectRoutingSection("Passive iface")
        }

        SectionTab {
            label: "Redistribute"
            selected: eigrpRoutingForm.activeRoutingSection === "Redistribute"
            onClicked: eigrpRoutingForm.selectRoutingSection("Redistribute")
        }

        SectionTab {
            label: "Distribute list"
            selected: eigrpRoutingForm.activeRoutingSection === "Distribute list"
            onClicked: eigrpRoutingForm.selectRoutingSection("Distribute list")
        }

        SectionTab {
            label: "Key chains"
            selected: eigrpRoutingForm.activeRoutingSection === "Key chains"
            onClicked: eigrpRoutingForm.selectRoutingSection("Key chains")
        }

        Item { Layout.fillWidth: true }
    }

    Rectangle {
        visible: String(eigrpRoutingForm.currentHostIp || "").trim() !== ""
            && eigrpRoutingForm.activeRoutingSection !== "Process"
            && eigrpRoutingForm.activeRoutingSection !== "Networks"
        Layout.fillWidth: true
        Layout.leftMargin: 24
        Layout.rightMargin: 24
        implicitHeight: 118
        radius: Theme.cardRadius
        color: Theme.contentPanelSurface
        border.color: Theme.contentPanelBorder
        border.width: Theme.borderWidth

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.spacing16
            spacing: Theme.spacing8

            Text {
                text: "EIGRP " + eigrpRoutingForm.activeRoutingSection
                color: Theme.textPrimary
                font.pixelSize: Theme.fontSizeLarge
                font.family: Theme.fontFamily
                font.bold: true
            }

            Text {
                Layout.fillWidth: true
                text: "Not yet implemented. This section is planned for the next data phase."
                color: Theme.textSecondary
                font.pixelSize: Theme.fontSizeNormal
                font.family: Theme.fontFamily
                wrapMode: Text.Wrap
            }
        }
    }

    Rectangle {
        visible: String(eigrpRoutingForm.currentHostIp || "").trim() !== ""
            && eigrpRoutingForm.activeRoutingSection === "Networks"
            && processModel.count > 0
        Layout.fillWidth: true
        Layout.leftMargin: 24
        Layout.rightMargin: 24
        implicitHeight: eigrpNetworksLayout.implicitHeight + Theme.spacing32
        radius: Theme.cardRadius
        color: Theme.contentPanelSurface
        border.color: Theme.contentPanelBorder
        border.width: Theme.borderWidth

        ColumnLayout {
            id: eigrpNetworksLayout
            anchors.fill: parent
            anchors.margins: Theme.spacing16
            spacing: Theme.spacing12

            Text {
                text: "EIGRP NETWORKS"
                color: Theme.textPrimary
                font.pixelSize: Theme.fontSizeLarge
                font.family: Theme.fontFamily
                font.bold: true
            }

            GridLayout {
                Layout.fillWidth: true
                columns: width < 760 ? 2 : 3
                columnSpacing: Theme.spacing12
                rowSpacing: Theme.spacing8

                StandardComboBox {
                    id: eigrpNetworkProcessCombo
                    Layout.fillWidth: true
                    labelText: "EIGRP Process"
                    model: eigrpRoutingForm.processOptions
                    currentIndex: eigrpRoutingForm.selectedNetworkProcessIndex
                    enabled: processModel.count > 0
                    onCurrentIndexChanged: {
                        if (currentIndex >= 0)
                            eigrpRoutingForm.selectedNetworkProcessIndex = currentIndex
                    }
                }

                StandardTextField {
                    id: eigrpNetworkField
                    Layout.fillWidth: true
                    labelText: "Network"
                    placeholderText: "10.0.0.0"
                    enabled: processModel.count > 0
                }

                StandardTextField {
                    id: eigrpWildcardField
                    Layout.fillWidth: true
                    labelText: "Wildcard"
                    placeholderText: "0.0.0.255"
                    enabled: processModel.count > 0
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacing8

                StandardButton {
                    text: "+ Add Network"
                    type: "Primary"
                    enabled: processModel.count > 0
                    onClicked: {
                        if (eigrpRoutingForm.addNetworkToSelectedProcess(eigrpNetworkField.text, eigrpWildcardField.text)) {
                            eigrpNetworkField.clear()
                            eigrpWildcardField.clear()
                        }
                    }
                }

                StandardButton {
                    text: "Clear"
                    type: "Secondary"
                    onClicked: {
                        eigrpNetworkField.clear()
                        eigrpWildcardField.clear()
                    }
                }

                Item { Layout.fillWidth: true }
            }
        }
    }

    Rectangle {
        visible: String(eigrpRoutingForm.currentHostIp || "").trim() !== ""
            && eigrpRoutingForm.activeRoutingSection === "Networks"
            && processModel.count > 0
        Layout.fillWidth: true
        Layout.leftMargin: 24
        Layout.rightMargin: 24
        implicitHeight: eigrpNetworkTableLayout.implicitHeight
        radius: Theme.cardRadius
        color: Theme.contentPanelSurface
        border.color: Theme.contentPanelBorder
        border.width: Theme.borderWidth

        ColumnLayout {
            id: eigrpNetworkTableLayout
            width: parent.width
            spacing: 0

            Rectangle {
                Layout.fillWidth: true
                height: 36
                color: "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spacing16
                    anchors.rightMargin: Theme.spacing16
                    spacing: Theme.spacing8

                    Text { Layout.fillWidth: true; text: "PROCESS"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSmall; font.family: Theme.fontFamily; font.bold: true }
                    Text { Layout.fillWidth: true; text: "NETWORK"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSmall; font.family: Theme.fontFamily; font.bold: true }
                    Text { Layout.fillWidth: true; text: "WILDCARD"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSmall; font.family: Theme.fontFamily; font.bold: true }
                    Text { Layout.preferredWidth: 40; text: "" }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: Theme.borderWidth
                    color: Theme.contentPanelBorder
                }
            }

            Text {
                visible: processModel.count === 0
                    || !eigrpRoutingForm.selectedNetworkProcessItem()
                    || eigrpRoutingForm.selectedNetworkProcessItem().networks.count === 0
                Layout.fillWidth: true
                text: processModel.count === 0
                      ? "No EIGRP process. Create a process before adding networks."
                      : "No networks in the selected process."
                color: Theme.textDisabled
                font.pixelSize: Theme.fontSizeNormal
                font.family: Theme.fontFamily
                horizontalAlignment: Text.AlignHCenter
                topPadding: Theme.spacing16
                bottomPadding: Theme.spacing16
            }

            Repeater {
                model: {
                    const revision = eigrpRoutingForm.statsRevision
                    const item = eigrpRoutingForm.selectedNetworkProcessItem()
                    return item ? item.networks : null
                }

                delegate: Rectangle {
                    id: eigrpNetworkRow
                    required property string network
                    required property string wildcard
                    required property int index

                    width: eigrpNetworkTableLayout.width
                    height: 42
                    color: rowHover.hovered ? Theme.sideBarItemHover : "transparent"

                    HoverHandler { id: rowHover }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacing16
                        anchors.rightMargin: Theme.spacing16
                        spacing: Theme.spacing8

                        Text { Layout.fillWidth: true; text: eigrpRoutingForm.processOptionLabel(eigrpRoutingForm.selectedNetworkProcessIndex); color: Theme.textSecondary; font.pixelSize: Theme.fontSizeNormal; font.family: Theme.fontFamily; elide: Text.ElideRight }
                        Text { Layout.fillWidth: true; text: eigrpNetworkRow.network; color: Theme.accentColor; font.pixelSize: Theme.fontSizeNormal; font.family: Theme.fontFamily; elide: Text.ElideRight }
                        Text { Layout.fillWidth: true; text: eigrpNetworkRow.wildcard; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeNormal; font.family: Theme.fontFamily; elide: Text.ElideRight }
                        StandardButton {
                            Layout.preferredWidth: 34
                            type: "Icon"
                            icon.source: "qrc:/qt/qml/NetworkTools/resources/devicetabs/close.svg"
                            tooltip: "Remove network"
                            onClicked: eigrpRoutingForm.removeNetworkFromSelectedProcess(eigrpNetworkRow.index)
                        }
                    }
                }
            }
        }
    }

    Repeater {
        id: processRepeater
        model: processModel

        delegate: EigrpProcessCard {
            required property int processUid
            required property int processOrder
            visible: eigrpRoutingForm.activeRoutingSection === "Process"
            Layout.fillWidth: true
            Layout.leftMargin: 24
            Layout.rightMargin: 24
            property int modelUid: processUid
            processIndex: processOrder
            activeSection: eigrpRoutingForm.activeRoutingSection
            showSectionTabs: false
            payload: eigrpRoutingForm.processPayloadForUid(modelUid)

            onRemoveRequested: eigrpRoutingForm.removeProcessByUid(modelUid)
            onCardChanged: eigrpRoutingForm.handleCardChanged()
        }
    }

    Item { height: 8 }

    // ── FOOTER (Nút Bấm) ──
    footer: [
        StandardButton {
            text: "+ Add Process"
            type: "Primary"
            visible: String(eigrpRoutingForm.currentHostIp || "").trim() !== ""
                && (eigrpRoutingForm.activeRoutingSection === "Process"
                    || eigrpRoutingForm.activeRoutingSection === "Networks")
            onClicked: eigrpRoutingForm.addEmptyProcess()
        },
        Item { Layout.fillWidth: true },
        StandardButton {
            text: "Reload"
            type: "Secondary"
            onClicked: {
                eigrpRoutingForm.loadFromDatabase()
                eigrpRoutingForm.notify("Reloaded EIGRP routing from database.", "info")
            }
        },
        StandardButton {
            text: "Cancel Changes"
            type: "Secondary"
            enabled: hasPendingLocalChanges
            onClicked: eigrpRoutingForm.cancelAllChanges()
        },
        StandardButton {
            text: isSaving ? "Saving..." : "Save EIGRP"
            type: "Primary"
            enabled: hasPendingLocalChanges && !isLoading && !isSaving
            onClicked: eigrpRoutingForm.saveToDatabase()
        }
    ]

    StandardValidationDialog {
        id: validationDialog
        visible: eigrpRoutingForm.showValidationDialog
        titleText: "EIGRP Validation Error"
        messageText: eigrpRoutingForm.validationMessage
        onAccepted: eigrpRoutingForm.showValidationDialog = false
        onClosed: eigrpRoutingForm.showValidationDialog = false
    }
}
