pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import NetworkTools

// Bọc toàn bộ form bằng FormLayout
FormLayout {
    id: ospfRoutingForm

    // Gắn dữ liệu vào Public API của FormLayout
    title: "OSPF Routing"
    hostIp: currentHostIp
    isDirty: hasPendingLocalChanges
    errorMessage: ""

    property string currentHostIp: ""
    property bool isLoading: false
    property bool isSaving: false
    property bool hasPendingLocalChanges: false
    property string lastError: ""
    property string loadedProcessesSignature: "[]"
    property int nextUid: 1
    property int statsRevision: 0
    property string activeRoutingSection: "Process"
    property int selectedNetworkProcessIndex: 0
    property var processOptions: []
    property var processPayloadByUid: ({})

    component SectionTab: SegmentTab {
        minWidth: 92
        idleBorderColor: Theme.borderColor
    }

    ListModel {
        id: processModel
    }

    function notify(message, type) {
        if (typeof statusBar !== "undefined")
            statusBar.showMessage(message, type)
    }

    function showValidation(message) {
        notify(message, "error")
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

    function refreshStats() {
        statsRevision += 1
    }

    function processOptionLabel(index) {
        const item = processRepeater.itemAt(index)
        const host = String(currentHostIp || "").trim()
        if (!item)
            return "Process " + (index + 1)

        const processIdText = String(item.processId || "").trim()
        const processText = processIdText !== "" ? ("PID " + processIdText) : ("Process " + (index + 1))
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

    function addNetworkToSelectedProcess(network, wildcard, area) {
        const item = selectedNetworkProcessItem()
        if (!item) {
            notify("Create an OSPF process before adding networks.", "warning")
            return false
        }

        const networkText = String(network || "").trim()
        const wildcardText = String(wildcard || "").trim()
        const areaText = String(area || "").trim()
        if (networkText === "" || wildcardText === "" || areaText === "") {
            notify("Network, wildcard, and area are required.", "warning")
            return false
        }

        item.networks.append({
            network: networkText,
            wildcard: wildcardText,
            area: areaText
        })
        handleCardChanged()
        notify("Added OSPF network to " + processOptionLabel(selectedNetworkProcessIndex) + ".", "info")
        return true
    }

    function removeNetworkFromSelectedProcess(rowIndex) {
        const item = selectedNetworkProcessItem()
        if (!item || rowIndex < 0 || rowIndex >= item.networks.count)
            return

        item.networks.remove(rowIndex)
        handleCardChanged()
        notify("Removed OSPF network from " + processOptionLabel(selectedNetworkProcessIndex) + ".", "warning")
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
                notify("Removed OSPF process " + row.processOrder + " from the local editor.", "warning")
                refreshStats()
                Qt.callLater(rebuildProcessOptions)
                Qt.callLater(refreshDirtyFlag)
                return
            }
        }
    }

    function addEmptyProcess() {
        appendProcess({
            process_id:               "",
            router_id:                "",
            reference_bandwidth:      0,
            passive_default:          false,
            default_originate:        false,
            default_originate_always: false,
            networks:                 []
        })
        notify("Added a new OSPF process card.", "info")
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
            ospfRoutingForm.refreshStats()
            ospfRoutingForm.rebuildProcessOptions()
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
        refreshStats()
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
            && (ospfRoutingForm.activeRoutingSection === "Process"
                || ospfRoutingForm.activeRoutingSection === "Networks")
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

    GridLayout {
        visible: String(ospfRoutingForm.currentHostIp || "").trim() !== ""
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

                Text { text: "OSPF PROCESS"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSmall; font.family: Theme.fontFamily; font.bold: true }
                Text { text: String(processModel.count); color: Theme.textPrimary; font.pixelSize: Theme.fontSizeTitle; font.family: Theme.fontFamily; font.bold: true }
                Text { text: "active cards"; color: Theme.textDisabled; font.pixelSize: Theme.fontSizeSmall; font.family: Theme.fontFamily }
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
                Text { text: String(ospfRoutingForm.totalNetworkCount()); color: Theme.accentColor; font.pixelSize: Theme.fontSizeTitle; font.family: Theme.fontFamily; font.bold: true }
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
                Text { Layout.fillWidth: true; text: ospfRoutingForm.currentHostIp; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeLarge; font.family: Theme.fontFamily; font.bold: true; elide: Text.ElideRight }
                Text { text: "selected device"; color: Theme.textDisabled; font.pixelSize: Theme.fontSizeSmall; font.family: Theme.fontFamily }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 76
            radius: Theme.cardRadius
            color: Theme.contentPanelSurface
            border.color: ospfRoutingForm.hasPendingLocalChanges ? Theme.alertWarning : Theme.contentPanelBorder
            border.width: Theme.borderWidth

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacing12
                spacing: Theme.spacing2

                Text { text: "STATE"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSmall; font.family: Theme.fontFamily; font.bold: true }
                Text { text: ospfRoutingForm.hasPendingLocalChanges ? "DIRTY" : "SYNC"; color: ospfRoutingForm.hasPendingLocalChanges ? Theme.alertWarning : Theme.alertSuccess; font.pixelSize: Theme.fontSizeTitle; font.family: Theme.fontFamily; font.bold: true }
                Text { text: ospfRoutingForm.hasPendingLocalChanges ? "pending save" : "database"; color: Theme.textDisabled; font.pixelSize: Theme.fontSizeSmall; font.family: Theme.fontFamily }
            }
        }
    }

    RowLayout {
        visible: String(ospfRoutingForm.currentHostIp || "").trim() !== ""
        Layout.fillWidth: true
        Layout.leftMargin: 24
        Layout.rightMargin: 24
        spacing: Theme.spacing4

        SectionTab {
            label: "Process"
            selected: ospfRoutingForm.activeRoutingSection === "Process"
            onClicked: ospfRoutingForm.selectRoutingSection("Process")
        }

        SectionTab {
            label: "Networks"
            selected: ospfRoutingForm.activeRoutingSection === "Networks"
            onClicked: ospfRoutingForm.selectRoutingSection("Networks")
        }

        SectionTab {
            label: "Areas"
            selected: ospfRoutingForm.activeRoutingSection === "Areas"
            onClicked: ospfRoutingForm.selectRoutingSection("Areas")
        }

        SectionTab {
            label: "Redistribute"
            selected: ospfRoutingForm.activeRoutingSection === "Redistribute"
            onClicked: ospfRoutingForm.selectRoutingSection("Redistribute")
        }

        SectionTab {
            label: "Interfaces"
            selected: ospfRoutingForm.activeRoutingSection === "Interfaces"
            onClicked: ospfRoutingForm.selectRoutingSection("Interfaces")
        }

        SectionTab {
            label: "Passive iface"
            selected: ospfRoutingForm.activeRoutingSection === "Passive iface"
            onClicked: ospfRoutingForm.selectRoutingSection("Passive iface")
        }

        Item { Layout.fillWidth: true }
    }

    Rectangle {
        visible: String(ospfRoutingForm.currentHostIp || "").trim() !== ""
            && ospfRoutingForm.activeRoutingSection !== "Process"
            && ospfRoutingForm.activeRoutingSection !== "Networks"
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
                text: "OSPF " + ospfRoutingForm.activeRoutingSection
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
        visible: String(ospfRoutingForm.currentHostIp || "").trim() !== ""
            && ospfRoutingForm.activeRoutingSection === "Networks"
            && processModel.count > 0
        Layout.fillWidth: true
        Layout.leftMargin: 24
        Layout.rightMargin: 24
        implicitHeight: ospfNetworksLayout.implicitHeight + Theme.spacing32
        radius: Theme.cardRadius
        color: Theme.contentPanelSurface
        border.color: Theme.contentPanelBorder
        border.width: Theme.borderWidth

        ColumnLayout {
            id: ospfNetworksLayout
            anchors.fill: parent
            anchors.margins: Theme.spacing16
            spacing: Theme.spacing12

            Text {
                text: "OSPF NETWORKS"
                color: Theme.textPrimary
                font.pixelSize: Theme.fontSizeLarge
                font.family: Theme.fontFamily
                font.bold: true
            }

            GridLayout {
                Layout.fillWidth: true
                columns: width < 760 ? 2 : 4
                columnSpacing: Theme.spacing12
                rowSpacing: Theme.spacing8

                StandardComboBox {
                    id: ospfNetworkProcessCombo
                    Layout.fillWidth: true
                    labelText: "OSPF Process"
                    model: ospfRoutingForm.processOptions
                    currentIndex: ospfRoutingForm.selectedNetworkProcessIndex
                    enabled: processModel.count > 0
                    onCurrentIndexChanged: {
                        if (currentIndex >= 0)
                            ospfRoutingForm.selectedNetworkProcessIndex = currentIndex
                    }
                }

                StandardTextField {
                    id: ospfNetworkField
                    Layout.fillWidth: true
                    labelText: "Network"
                    placeholderText: "10.0.0.0"
                    enabled: processModel.count > 0
                }

                StandardTextField {
                    id: ospfWildcardField
                    Layout.fillWidth: true
                    labelText: "Wildcard"
                    placeholderText: "0.0.0.255"
                    enabled: processModel.count > 0
                }

                StandardTextField {
                    id: ospfAreaField
                    Layout.fillWidth: true
                    labelText: "Area"
                    placeholderText: "0"
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
                        if (ospfRoutingForm.addNetworkToSelectedProcess(ospfNetworkField.text, ospfWildcardField.text, ospfAreaField.text)) {
                            ospfNetworkField.clear()
                            ospfWildcardField.clear()
                            ospfAreaField.clear()
                        }
                    }
                }

                StandardButton {
                    text: "Clear"
                    type: "Secondary"
                    onClicked: {
                        ospfNetworkField.clear()
                        ospfWildcardField.clear()
                        ospfAreaField.clear()
                    }
                }

                Item { Layout.fillWidth: true }
            }
        }
    }

    Rectangle {
        visible: String(ospfRoutingForm.currentHostIp || "").trim() !== ""
            && ospfRoutingForm.activeRoutingSection === "Networks"
            && processModel.count > 0
        Layout.fillWidth: true
        Layout.leftMargin: 24
        Layout.rightMargin: 24
        implicitHeight: ospfNetworkTableLayout.implicitHeight
        radius: Theme.cardRadius
        color: Theme.contentPanelSurface
        border.color: Theme.contentPanelBorder
        border.width: Theme.borderWidth

        ColumnLayout {
            id: ospfNetworkTableLayout
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
                    Text { Layout.preferredWidth: 96; text: "AREA"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSmall; font.family: Theme.fontFamily; font.bold: true }
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
                    || !ospfRoutingForm.selectedNetworkProcessItem()
                    || ospfRoutingForm.selectedNetworkProcessItem().networks.count === 0
                Layout.fillWidth: true
                text: processModel.count === 0
                      ? "No OSPF process. Create a process before adding networks."
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
                    const revision = ospfRoutingForm.statsRevision
                    const item = ospfRoutingForm.selectedNetworkProcessItem()
                    return item ? item.networks : null
                }

                delegate: Rectangle {
                    id: ospfNetworkRow
                    required property string network
                    required property string wildcard
                    required property string area
                    required property int index

                    width: ospfNetworkTableLayout.width
                    height: 42
                    color: rowHover.hovered ? Theme.sideBarItemHover : "transparent"

                    HoverHandler { id: rowHover }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacing16
                        anchors.rightMargin: Theme.spacing16
                        spacing: Theme.spacing8

                        Text { Layout.fillWidth: true; text: ospfRoutingForm.processOptionLabel(ospfRoutingForm.selectedNetworkProcessIndex); color: Theme.textSecondary; font.pixelSize: Theme.fontSizeNormal; font.family: Theme.fontFamily; elide: Text.ElideRight }
                        Text { Layout.fillWidth: true; text: ospfNetworkRow.network; color: Theme.accentColor; font.pixelSize: Theme.fontSizeNormal; font.family: Theme.fontFamily; elide: Text.ElideRight }
                        Text { Layout.fillWidth: true; text: ospfNetworkRow.wildcard; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeNormal; font.family: Theme.fontFamily; elide: Text.ElideRight }
                        Text { Layout.preferredWidth: 96; text: ospfNetworkRow.area; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeNormal; font.family: Theme.fontFamily; elide: Text.ElideRight }
                        StandardButton {
                            Layout.preferredWidth: 34
                            type: "Icon"
                            icon.source: "qrc:/qt/qml/NetworkTools/resources/devicetabs/close.svg"
                            tooltip: "Remove network"
                            onClicked: ospfRoutingForm.removeNetworkFromSelectedProcess(ospfNetworkRow.index)
                        }
                    }
                }
            }
        }
    }

    Repeater {
        id: processRepeater
        model: processModel

        delegate: OspfProcessCard {
            required property int processUid
            required property int processOrder
            visible: ospfRoutingForm.activeRoutingSection === "Process"
            Layout.fillWidth: true
            Layout.leftMargin: 24
            Layout.rightMargin: 24
            property int modelUid: processUid
            processIndex: processOrder
            activeSection: ospfRoutingForm.activeRoutingSection
            showSectionTabs: false
            payload: ospfRoutingForm.processPayloadForUid(modelUid)

            onRemoveRequested: {
                ospfRoutingForm.removeProcessByUid(modelUid)
            }

            onCardChanged: ospfRoutingForm.handleCardChanged()
        }
    }

    Item { height: 8 }

    // ── FOOTER (Nút Bấm) ──
    footer: [
        StandardButton {
            text: "+ Add Process"
            type: "Primary"
            visible: String(ospfRoutingForm.currentHostIp || "").trim() !== ""
                && (ospfRoutingForm.activeRoutingSection === "Process"
                    || ospfRoutingForm.activeRoutingSection === "Networks")
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

}
