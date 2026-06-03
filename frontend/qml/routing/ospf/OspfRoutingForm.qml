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
    property int selectedAreaIndex: 0
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

    function selectedProcessItem() {
        return selectedNetworkProcessItem()
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

    function totalChildCount(modelName) {
        const revision = statsRevision
        let total = 0
        const items = processItems()
        for (let i = 0; i < items.length; i++) {
            if (items[i][modelName])
                total += items[i][modelName].count
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
    }

    function addAreaToSelectedProcess(areaId, areaType, noSummary, authentication) {
        const item = selectedProcessItem()
        const areaText = String(areaId || "").trim()
        if (!item || areaText === "") {
            notify("Process and Area ID are required.", "warning")
            return false
        }
        item.areas.append({
            area_id: areaText,
            area_type: areaType || "normal",
            no_summary: noSummary,
            authentication: authentication || "",
            ranges: []
        })
        selectedAreaIndex = item.areas.count - 1
        handleCardChanged()
        notify("Added OSPF area.", "info")
        return true
    }

    function removeAreaFromSelectedProcess(rowIndex) {
        const item = selectedProcessItem()
        if (!item || rowIndex < 0 || rowIndex >= item.areas.count)
            return
        item.areas.remove(rowIndex)
        if (selectedAreaIndex >= item.areas.count)
            selectedAreaIndex = Math.max(0, item.areas.count - 1)
        handleCardChanged()
    }

    function areaOptionsForSelectedProcess() {
        const revision = statsRevision
        const item = selectedProcessItem()
        const options = []
        if (!item)
            return options
        for (let i = 0; i < item.areas.count; i++) {
            const area = item.areas.get(i)
            options.push("Area " + String(area.area_id || ""))
        }
        if (selectedAreaIndex >= options.length)
            selectedAreaIndex = Math.max(0, options.length - 1)
        return options
    }

    function selectedAreaRanges() {
        const revision = statsRevision
        const item = selectedProcessItem()
        if (!item || selectedAreaIndex < 0 || selectedAreaIndex >= item.areas.count)
            return []
        return item.areas.get(selectedAreaIndex).ranges || []
    }

    function addAreaRangeToSelectedArea(ip, mask, advertise, cost) {
        const item = selectedProcessItem()
        if (!item || selectedAreaIndex < 0 || selectedAreaIndex >= item.areas.count) {
            notify("Create/select an OSPF area before adding ranges.", "warning")
            return false
        }
        const ipText = String(ip || "").trim()
        const maskText = String(mask || "").trim()
        if (ipText === "" || maskText === "") {
            notify("Range IP and mask are required.", "warning")
            return false
        }
        const area = item.areas.get(selectedAreaIndex)
        const ranges = area.ranges ? area.ranges.slice() : []
        ranges.push({
            ip: ipText,
            mask: maskText,
            advertise: advertise,
            cost: String(cost || "").trim()
        })
        item.areas.setProperty(selectedAreaIndex, "ranges", ranges)
        handleCardChanged()
        notify("Added OSPF area range.", "info")
        return true
    }

    function removeAreaRangeFromSelectedArea(rowIndex) {
        const item = selectedProcessItem()
        if (!item || selectedAreaIndex < 0 || selectedAreaIndex >= item.areas.count)
            return
        const area = item.areas.get(selectedAreaIndex)
        const ranges = area.ranges ? area.ranges.slice() : []
        if (rowIndex < 0 || rowIndex >= ranges.length)
            return
        ranges.splice(rowIndex, 1)
        item.areas.setProperty(selectedAreaIndex, "ranges", ranges)
        handleCardChanged()
    }

    function addRedistributeToSelectedProcess(protocol, processId, subnets, metric, metricType, routeMap) {
        const item = selectedProcessItem()
        if (!item) {
            notify("Create an OSPF process before adding redistribution.", "warning")
            return false
        }
        item.redistribute.append({
            protocol: protocol || "static",
            process_id: String(processId || "").trim(),
            subnets: subnets,
            metric: String(metric || "").trim(),
            metric_type: String(metricType || "").trim(),
            route_map: String(routeMap || "").trim()
        })
        handleCardChanged()
        notify("Added OSPF redistribution.", "info")
        return true
    }

    function removeRedistributeFromSelectedProcess(rowIndex) {
        const item = selectedProcessItem()
        if (!item || rowIndex < 0 || rowIndex >= item.redistribute.count)
            return
        item.redistribute.remove(rowIndex)
        handleCardChanged()
    }

    function addPassiveInterfaceToSelectedProcess(interfaceName, passive) {
        const item = selectedProcessItem()
        const iface = String(interfaceName || "").trim()
        if (!item || iface === "") {
            notify("Process and interface name are required.", "warning")
            return false
        }
        item.passiveInterfaces.append({ interface_name: iface, passive: passive })
        handleCardChanged()
        notify("Added OSPF passive-interface entry.", "info")
        return true
    }

    function removePassiveInterfaceFromSelectedProcess(rowIndex) {
        const item = selectedProcessItem()
        if (!item || rowIndex < 0 || rowIndex >= item.passiveInterfaces.count)
            return
        item.passiveInterfaces.remove(rowIndex)
        handleCardChanged()
    }

    function addInterfaceSettingToSelectedProcess(interfaceName, area, cost, hello, dead, mtuIgnore, bfd, networkType, authType) {
        const item = selectedProcessItem()
        const iface = String(interfaceName || "").trim()
        const areaText = String(area || "").trim()
        if (!item || iface === "" || areaText === "") {
            notify("Interface name and area are required.", "warning")
            return false
        }
        item.interfaceSettings.append({
            interface_name: iface,
            area: areaText,
            cost: String(cost || "").trim(),
            hello_interval: String(hello || "").trim(),
            dead_interval: String(dead || "").trim(),
            mtu_ignore: mtuIgnore,
            bfd: bfd,
            network_type: networkType || "",
            auth_type: authType || ""
        })
        handleCardChanged()
        notify("Added OSPF interface setting.", "info")
        return true
    }

    function removeInterfaceSettingFromSelectedProcess(rowIndex) {
        const item = selectedProcessItem()
        if (!item || rowIndex < 0 || rowIndex >= item.interfaceSettings.count)
            return
        item.interfaceSettings.remove(rowIndex)
        handleCardChanged()
    }

    function setDistanceForSelectedProcess(external, intraArea, interArea) {
        const item = selectedProcessItem()
        if (!item)
            return false
        item.distance = {
            external: String(external || "").trim(),
            intra_area: String(intraArea || "").trim(),
            inter_area: String(interArea || "").trim()
        }
        handleCardChanged()
        notify("Updated OSPF distance.", "info")
        return true
    }

    function setTuningForSelectedProcess(maximumPaths, maxLsa, spfDelay, spfMin, spfMax, lsaDelay, lsaMin, lsaMax) {
        const item = selectedProcessItem()
        if (!item)
            return false
        item.tuning = {
            maximum_paths: String(maximumPaths || "").trim(),
            max_lsa: String(maxLsa || "").trim(),
            spf_delay: String(spfDelay || "").trim(),
            spf_min_delay: String(spfMin || "").trim(),
            spf_max_delay: String(spfMax || "").trim(),
            lsa_delay: String(lsaDelay || "").trim(),
            lsa_min_delay: String(lsaMin || "").trim(),
            lsa_max_delay: String(lsaMax || "").trim()
        }
        handleCardChanged()
        notify("Updated OSPF tuning.", "info")
        return true
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
            networks:                 [],
            distance:                 {},
            tuning:                   {},
            areas:                    [],
            redistribute:             [],
            passive_interfaces:       [],
            interface_settings:       []
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
            label: "Distance"
            selected: ospfRoutingForm.activeRoutingSection === "Distance"
            onClicked: ospfRoutingForm.selectRoutingSection("Distance")
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

        SectionTab {
            label: "Tuning"
            selected: ospfRoutingForm.activeRoutingSection === "Tuning"
            onClicked: ospfRoutingForm.selectRoutingSection("Tuning")
        }

        Item { Layout.fillWidth: true }
    }

    Rectangle {
        visible: false && String(ospfRoutingForm.currentHostIp || "").trim() !== ""
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
            && ospfRoutingForm.activeRoutingSection === "Areas"
            && processModel.count > 0
        Layout.fillWidth: true
        Layout.leftMargin: 24
        Layout.rightMargin: 24
        implicitHeight: ospfAreasLayout.implicitHeight + Theme.spacing32
        radius: Theme.cardRadius
        color: Theme.contentPanelSurface
        border.color: Theme.contentPanelBorder
        border.width: Theme.borderWidth

        ColumnLayout {
            id: ospfAreasLayout
            anchors.fill: parent
            anchors.margins: Theme.spacing16
            spacing: Theme.spacing12

            Text { text: "OSPF AREAS"; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeLarge; font.family: Theme.fontFamily; font.bold: true }

            GridLayout {
                Layout.fillWidth: true
                columns: width < 760 ? 2 : 5
                columnSpacing: Theme.spacing12
                rowSpacing: Theme.spacing8

                StandardComboBox {
                    Layout.fillWidth: true
                    labelText: "OSPF Process"
                    model: ospfRoutingForm.processOptions
                    currentIndex: ospfRoutingForm.selectedNetworkProcessIndex
                    onCurrentIndexChanged: if (currentIndex >= 0) ospfRoutingForm.selectedNetworkProcessIndex = currentIndex
                }
                StandardTextField { id: ospfAreaIdField; Layout.fillWidth: true; labelText: "Area ID"; placeholderText: "0" }
                StandardComboBox { id: ospfAreaTypeCombo; Layout.fillWidth: true; labelText: "Type"; model: ["normal", "stub", "nssa"] }
                StandardComboBox { id: ospfAreaAuthCombo; Layout.fillWidth: true; labelText: "Auth"; model: ["", "plain", "message-digest"] }
                StandardCheckBox { id: ospfAreaNoSummaryCheck; text: "No summary"; Layout.alignment: Qt.AlignBottom }
            }

            RowLayout {
                Layout.fillWidth: true
                StandardButton {
                    text: "+ Add Area"
                    type: "Primary"
                    onClicked: {
                        if (ospfRoutingForm.addAreaToSelectedProcess(ospfAreaIdField.text, ospfAreaTypeCombo.currentText, ospfAreaNoSummaryCheck.checked, ospfAreaAuthCombo.currentText))
                            ospfAreaIdField.clear()
                    }
                }
                Item { Layout.fillWidth: true }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: width < 760 ? 2 : 5
                columnSpacing: Theme.spacing12
                rowSpacing: Theme.spacing8

                StandardComboBox {
                    Layout.fillWidth: true
                    labelText: "Area for Range"
                    model: ospfRoutingForm.areaOptionsForSelectedProcess()
                    currentIndex: ospfRoutingForm.selectedAreaIndex
                    enabled: ospfRoutingForm.areaOptionsForSelectedProcess().length > 0
                    onCurrentIndexChanged: if (currentIndex >= 0) ospfRoutingForm.selectedAreaIndex = currentIndex
                }
                StandardTextField { id: ospfRangeIpField; Layout.fillWidth: true; labelText: "Range IP"; placeholderText: "10.0.0.0" }
                StandardTextField { id: ospfRangeMaskField; Layout.fillWidth: true; labelText: "Range mask"; placeholderText: "255.255.255.0" }
                StandardTextField { id: ospfRangeCostField; Layout.fillWidth: true; labelText: "Cost"; placeholderText: "optional" }
                StandardCheckBox { id: ospfRangeAdvertiseCheck; text: "Advertise"; checked: true; Layout.alignment: Qt.AlignBottom }
            }

            RowLayout {
                Layout.fillWidth: true
                StandardButton {
                    text: "+ Add Range"
                    type: "Secondary"
                    enabled: ospfRoutingForm.areaOptionsForSelectedProcess().length > 0
                    onClicked: {
                        if (ospfRoutingForm.addAreaRangeToSelectedArea(ospfRangeIpField.text, ospfRangeMaskField.text, ospfRangeAdvertiseCheck.checked, ospfRangeCostField.text)) {
                            ospfRangeIpField.clear()
                            ospfRangeMaskField.clear()
                            ospfRangeCostField.clear()
                        }
                    }
                }
                Item { Layout.fillWidth: true }
            }

            Repeater {
                model: {
                    const revision = ospfRoutingForm.statsRevision
                    const item = ospfRoutingForm.selectedProcessItem()
                    return item ? item.areas : null
                }
                delegate: RowLayout {
                    required property string area_id
                    required property string area_type
                    required property bool no_summary
                    required property string authentication
                    required property int index
                    Layout.fillWidth: true
                    Text { Layout.fillWidth: true; text: "Area " + area_id; color: Theme.accentColor; font.family: Theme.fontFamily }
                    Text { Layout.fillWidth: true; text: area_type; color: Theme.textPrimary; font.family: Theme.fontFamily }
                    Text { Layout.fillWidth: true; text: authentication || "no auth"; color: Theme.textSecondary; font.family: Theme.fontFamily }
                    Text { Layout.preferredWidth: 110; text: no_summary ? "no-summary" : ""; color: Theme.textSecondary; font.family: Theme.fontFamily }
                    StandardButton { Layout.preferredWidth: 34; type: "Icon"; icon.source: "qrc:/qt/qml/NetworkTools/resources/devicetabs/close.svg"; tooltip: "Remove area"; onClicked: ospfRoutingForm.removeAreaFromSelectedProcess(index) }
                }
            }

            Text {
                visible: ospfRoutingForm.areaOptionsForSelectedProcess().length > 0
                Layout.fillWidth: true
                text: "Ranges for " + (ospfRoutingForm.areaOptionsForSelectedProcess()[ospfRoutingForm.selectedAreaIndex] || "selected area")
                color: Theme.textSecondary
                font.pixelSize: Theme.fontSizeSmall
                font.family: Theme.fontFamily
                font.bold: true
            }

            Repeater {
                model: ospfRoutingForm.selectedAreaRanges()
                delegate: RowLayout {
                    required property string ip
                    required property string mask
                    required property var cost
                    required property bool advertise
                    required property int index
                    Layout.fillWidth: true
                    Text { Layout.fillWidth: true; text: ip; color: Theme.accentColor; font.family: Theme.fontFamily }
                    Text { Layout.fillWidth: true; text: mask; color: Theme.textPrimary; font.family: Theme.fontFamily }
                    Text { Layout.fillWidth: true; text: advertise ? "advertise" : "not-advertise"; color: Theme.textSecondary; font.family: Theme.fontFamily }
                    Text { Layout.fillWidth: true; text: cost ? ("cost " + cost) : ""; color: Theme.textSecondary; font.family: Theme.fontFamily }
                    StandardButton { Layout.preferredWidth: 34; type: "Icon"; icon.source: "qrc:/qt/qml/NetworkTools/resources/devicetabs/close.svg"; tooltip: "Remove range"; onClicked: ospfRoutingForm.removeAreaRangeFromSelectedArea(index) }
                }
            }
        }
    }

    Rectangle {
        visible: String(ospfRoutingForm.currentHostIp || "").trim() !== ""
            && ospfRoutingForm.activeRoutingSection === "Redistribute"
            && processModel.count > 0
        Layout.fillWidth: true
        Layout.leftMargin: 24
        Layout.rightMargin: 24
        implicitHeight: ospfRedistributeLayout.implicitHeight + Theme.spacing32
        radius: Theme.cardRadius
        color: Theme.contentPanelSurface
        border.color: Theme.contentPanelBorder
        border.width: Theme.borderWidth

        ColumnLayout {
            id: ospfRedistributeLayout
            anchors.fill: parent
            anchors.margins: Theme.spacing16
            spacing: Theme.spacing12

            Text { text: "OSPF REDISTRIBUTE"; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeLarge; font.family: Theme.fontFamily; font.bold: true }

            GridLayout {
                Layout.fillWidth: true
                columns: width < 760 ? 2 : 6
                columnSpacing: Theme.spacing12
                rowSpacing: Theme.spacing8

                StandardComboBox { Layout.fillWidth: true; labelText: "OSPF Process"; model: ospfRoutingForm.processOptions; currentIndex: ospfRoutingForm.selectedNetworkProcessIndex; onCurrentIndexChanged: if (currentIndex >= 0) ospfRoutingForm.selectedNetworkProcessIndex = currentIndex }
                StandardComboBox { id: ospfRedistProtocolCombo; Layout.fillWidth: true; labelText: "Protocol"; model: ["static", "connected", "eigrp", "bgp", "rip", "isis"] }
                StandardTextField { id: ospfRedistPidField; Layout.fillWidth: true; labelText: "Process ID"; placeholderText: "optional" }
                StandardTextField { id: ospfRedistMetricField; Layout.fillWidth: true; labelText: "Metric"; placeholderText: "optional" }
                StandardComboBox { id: ospfRedistMetricTypeCombo; Layout.fillWidth: true; labelText: "Metric type"; model: ["", "1", "2"] }
                StandardTextField { id: ospfRedistRouteMapField; Layout.fillWidth: true; labelText: "Route map"; placeholderText: "optional" }
                StandardCheckBox { id: ospfRedistSubnetsCheck; text: "Subnets"; checked: true }
            }

            RowLayout {
                Layout.fillWidth: true
                StandardButton {
                    text: "+ Add Redistribute"
                    type: "Primary"
                    onClicked: ospfRoutingForm.addRedistributeToSelectedProcess(ospfRedistProtocolCombo.currentText, ospfRedistPidField.text, ospfRedistSubnetsCheck.checked, ospfRedistMetricField.text, ospfRedistMetricTypeCombo.currentText, ospfRedistRouteMapField.text)
                }
                Item { Layout.fillWidth: true }
            }

            Repeater {
                model: {
                    const revision = ospfRoutingForm.statsRevision
                    const item = ospfRoutingForm.selectedProcessItem()
                    return item ? item.redistribute : null
                }
                delegate: RowLayout {
                    required property string protocol
                    required property string process_id
                    required property bool subnets
                    required property string metric
                    required property string metric_type
                    required property string route_map
                    required property int index
                    Layout.fillWidth: true
                    Text { Layout.fillWidth: true; text: protocol + (process_id ? " " + process_id : ""); color: Theme.accentColor; font.family: Theme.fontFamily }
                    Text { Layout.fillWidth: true; text: subnets ? "subnets" : ""; color: Theme.textPrimary; font.family: Theme.fontFamily }
                    Text { Layout.fillWidth: true; text: metric ? ("metric " + metric) : ""; color: Theme.textSecondary; font.family: Theme.fontFamily }
                    Text { Layout.fillWidth: true; text: metric_type ? ("type " + metric_type) : ""; color: Theme.textSecondary; font.family: Theme.fontFamily }
                    Text { Layout.fillWidth: true; text: route_map ? ("route-map " + route_map) : ""; color: Theme.textSecondary; font.family: Theme.fontFamily }
                    StandardButton { Layout.preferredWidth: 34; type: "Icon"; icon.source: "qrc:/qt/qml/NetworkTools/resources/devicetabs/close.svg"; tooltip: "Remove redistribution"; onClicked: ospfRoutingForm.removeRedistributeFromSelectedProcess(index) }
                }
            }
        }
    }

    Rectangle {
        visible: String(ospfRoutingForm.currentHostIp || "").trim() !== ""
            && ospfRoutingForm.activeRoutingSection === "Passive iface"
            && processModel.count > 0
        Layout.fillWidth: true
        Layout.leftMargin: 24
        Layout.rightMargin: 24
        implicitHeight: ospfPassiveLayout.implicitHeight + Theme.spacing32
        radius: Theme.cardRadius
        color: Theme.contentPanelSurface
        border.color: Theme.contentPanelBorder
        border.width: Theme.borderWidth

        ColumnLayout {
            id: ospfPassiveLayout
            anchors.fill: parent
            anchors.margins: Theme.spacing16
            spacing: Theme.spacing12

            Text { text: "OSPF PASSIVE INTERFACES"; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeLarge; font.family: Theme.fontFamily; font.bold: true }

            GridLayout {
                Layout.fillWidth: true
                columns: width < 760 ? 2 : 4
                columnSpacing: Theme.spacing12
                rowSpacing: Theme.spacing8

                StandardComboBox { Layout.fillWidth: true; labelText: "OSPF Process"; model: ospfRoutingForm.processOptions; currentIndex: ospfRoutingForm.selectedNetworkProcessIndex; onCurrentIndexChanged: if (currentIndex >= 0) ospfRoutingForm.selectedNetworkProcessIndex = currentIndex }
                StandardTextField { id: ospfPassiveIfaceField; Layout.fillWidth: true; labelText: "Interface"; placeholderText: "GigabitEthernet0/0" }
                StandardCheckBox { id: ospfPassiveCheck; text: "Passive"; checked: true; Layout.alignment: Qt.AlignBottom }
                StandardButton {
                    text: "+ Add"
                    type: "Primary"
                    Layout.alignment: Qt.AlignBottom
                    onClicked: {
                        if (ospfRoutingForm.addPassiveInterfaceToSelectedProcess(ospfPassiveIfaceField.text, ospfPassiveCheck.checked))
                            ospfPassiveIfaceField.clear()
                    }
                }
            }

            Repeater {
                model: {
                    const revision = ospfRoutingForm.statsRevision
                    const item = ospfRoutingForm.selectedProcessItem()
                    return item ? item.passiveInterfaces : null
                }
                delegate: RowLayout {
                    required property string interface_name
                    required property bool passive
                    required property int index
                    Layout.fillWidth: true
                    Text { Layout.fillWidth: true; text: interface_name; color: Theme.accentColor; font.family: Theme.fontFamily }
                    Text { Layout.fillWidth: true; text: passive ? "passive" : "no passive"; color: Theme.textPrimary; font.family: Theme.fontFamily }
                    StandardButton { Layout.preferredWidth: 34; type: "Icon"; icon.source: "qrc:/qt/qml/NetworkTools/resources/devicetabs/close.svg"; tooltip: "Remove passive interface"; onClicked: ospfRoutingForm.removePassiveInterfaceFromSelectedProcess(index) }
                }
            }
        }
    }

    Rectangle {
        visible: String(ospfRoutingForm.currentHostIp || "").trim() !== ""
            && ospfRoutingForm.activeRoutingSection === "Distance"
            && processModel.count > 0
        Layout.fillWidth: true
        Layout.leftMargin: 24
        Layout.rightMargin: 24
        implicitHeight: ospfDistanceLayout.implicitHeight + Theme.spacing32
        radius: Theme.cardRadius
        color: Theme.contentPanelSurface
        border.color: Theme.contentPanelBorder
        border.width: Theme.borderWidth

        ColumnLayout {
            id: ospfDistanceLayout
            anchors.fill: parent
            anchors.margins: Theme.spacing16
            spacing: Theme.spacing12

            Text { text: "OSPF DISTANCE"; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeLarge; font.family: Theme.fontFamily; font.bold: true }

            GridLayout {
                Layout.fillWidth: true
                columns: width < 760 ? 2 : 5
                columnSpacing: Theme.spacing12
                rowSpacing: Theme.spacing8

                StandardComboBox { Layout.fillWidth: true; labelText: "OSPF Process"; model: ospfRoutingForm.processOptions; currentIndex: ospfRoutingForm.selectedNetworkProcessIndex; onCurrentIndexChanged: if (currentIndex >= 0) ospfRoutingForm.selectedNetworkProcessIndex = currentIndex }
                StandardTextField { id: ospfDistanceExternalField; Layout.fillWidth: true; labelText: "External"; placeholderText: "110" }
                StandardTextField { id: ospfDistanceIntraField; Layout.fillWidth: true; labelText: "Intra-area"; placeholderText: "110" }
                StandardTextField { id: ospfDistanceInterField; Layout.fillWidth: true; labelText: "Inter-area"; placeholderText: "110" }
                StandardButton { text: "Apply"; type: "Primary"; Layout.alignment: Qt.AlignBottom; onClicked: ospfRoutingForm.setDistanceForSelectedProcess(ospfDistanceExternalField.text, ospfDistanceIntraField.text, ospfDistanceInterField.text) }
            }
        }
    }

    Rectangle {
        visible: String(ospfRoutingForm.currentHostIp || "").trim() !== ""
            && ospfRoutingForm.activeRoutingSection === "Tuning"
            && processModel.count > 0
        Layout.fillWidth: true
        Layout.leftMargin: 24
        Layout.rightMargin: 24
        implicitHeight: ospfTuningLayout.implicitHeight + Theme.spacing32
        radius: Theme.cardRadius
        color: Theme.contentPanelSurface
        border.color: Theme.contentPanelBorder
        border.width: Theme.borderWidth

        ColumnLayout {
            id: ospfTuningLayout
            anchors.fill: parent
            anchors.margins: Theme.spacing16
            spacing: Theme.spacing12

            Text { text: "OSPF TUNING"; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeLarge; font.family: Theme.fontFamily; font.bold: true }

            GridLayout {
                Layout.fillWidth: true
                columns: width < 860 ? 2 : 5
                columnSpacing: Theme.spacing12
                rowSpacing: Theme.spacing8

                StandardComboBox { Layout.fillWidth: true; labelText: "OSPF Process"; model: ospfRoutingForm.processOptions; currentIndex: ospfRoutingForm.selectedNetworkProcessIndex; onCurrentIndexChanged: if (currentIndex >= 0) ospfRoutingForm.selectedNetworkProcessIndex = currentIndex }
                StandardTextField { id: ospfTuneMaxPathsField; Layout.fillWidth: true; labelText: "Max paths"; placeholderText: "optional" }
                StandardTextField { id: ospfTuneMaxLsaField; Layout.fillWidth: true; labelText: "Max LSA"; placeholderText: "optional" }
                StandardTextField { id: ospfTuneSpfDelayField; Layout.fillWidth: true; labelText: "SPF delay"; placeholderText: "optional" }
                StandardTextField { id: ospfTuneSpfMinField; Layout.fillWidth: true; labelText: "SPF min"; placeholderText: "optional" }
                StandardTextField { id: ospfTuneSpfMaxField; Layout.fillWidth: true; labelText: "SPF max"; placeholderText: "optional" }
                StandardTextField { id: ospfTuneLsaDelayField; Layout.fillWidth: true; labelText: "LSA delay"; placeholderText: "optional" }
                StandardTextField { id: ospfTuneLsaMinField; Layout.fillWidth: true; labelText: "LSA min"; placeholderText: "optional" }
                StandardTextField { id: ospfTuneLsaMaxField; Layout.fillWidth: true; labelText: "LSA max"; placeholderText: "optional" }
                StandardButton { text: "Apply"; type: "Primary"; Layout.alignment: Qt.AlignBottom; onClicked: ospfRoutingForm.setTuningForSelectedProcess(ospfTuneMaxPathsField.text, ospfTuneMaxLsaField.text, ospfTuneSpfDelayField.text, ospfTuneSpfMinField.text, ospfTuneSpfMaxField.text, ospfTuneLsaDelayField.text, ospfTuneLsaMinField.text, ospfTuneLsaMaxField.text) }
            }
        }
    }

    Rectangle {
        visible: String(ospfRoutingForm.currentHostIp || "").trim() !== ""
            && ospfRoutingForm.activeRoutingSection === "Interfaces"
            && processModel.count > 0
        Layout.fillWidth: true
        Layout.leftMargin: 24
        Layout.rightMargin: 24
        implicitHeight: ospfInterfacesLayout.implicitHeight + Theme.spacing32
        radius: Theme.cardRadius
        color: Theme.contentPanelSurface
        border.color: Theme.contentPanelBorder
        border.width: Theme.borderWidth

        ColumnLayout {
            id: ospfInterfacesLayout
            anchors.fill: parent
            anchors.margins: Theme.spacing16
            spacing: Theme.spacing12

            Text { text: "OSPF INTERFACE SETTINGS"; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeLarge; font.family: Theme.fontFamily; font.bold: true }

            GridLayout {
                Layout.fillWidth: true
                columns: width < 860 ? 2 : 5
                columnSpacing: Theme.spacing12
                rowSpacing: Theme.spacing8

                StandardComboBox { Layout.fillWidth: true; labelText: "OSPF Process"; model: ospfRoutingForm.processOptions; currentIndex: ospfRoutingForm.selectedNetworkProcessIndex; onCurrentIndexChanged: if (currentIndex >= 0) ospfRoutingForm.selectedNetworkProcessIndex = currentIndex }
                StandardTextField { id: ospfIfaceNameField; Layout.fillWidth: true; labelText: "Interface"; placeholderText: "GigabitEthernet0/0" }
                StandardTextField { id: ospfIfaceAreaField; Layout.fillWidth: true; labelText: "Area"; placeholderText: "0" }
                StandardTextField { id: ospfIfaceCostField; Layout.fillWidth: true; labelText: "Cost"; placeholderText: "optional" }
                StandardTextField { id: ospfIfaceHelloField; Layout.fillWidth: true; labelText: "Hello"; placeholderText: "optional" }
                StandardTextField { id: ospfIfaceDeadField; Layout.fillWidth: true; labelText: "Dead"; placeholderText: "optional" }
                StandardComboBox { id: ospfIfaceNetworkTypeCombo; Layout.fillWidth: true; labelText: "Network type"; model: ["", "broadcast", "non-broadcast", "point-to-point", "point-to-multipoint"] }
                StandardComboBox { id: ospfIfaceAuthTypeCombo; Layout.fillWidth: true; labelText: "Auth"; model: ["", "plain", "message-digest"] }
                StandardCheckBox { id: ospfIfaceMtuCheck; text: "MTU ignore"; Layout.alignment: Qt.AlignBottom }
                StandardCheckBox { id: ospfIfaceBfdCheck; text: "BFD"; Layout.alignment: Qt.AlignBottom }
            }

            RowLayout {
                Layout.fillWidth: true
                StandardButton {
                    text: "+ Add Interface Setting"
                    type: "Primary"
                    onClicked: ospfRoutingForm.addInterfaceSettingToSelectedProcess(ospfIfaceNameField.text, ospfIfaceAreaField.text, ospfIfaceCostField.text, ospfIfaceHelloField.text, ospfIfaceDeadField.text, ospfIfaceMtuCheck.checked, ospfIfaceBfdCheck.checked, ospfIfaceNetworkTypeCombo.currentText, ospfIfaceAuthTypeCombo.currentText)
                }
                Item { Layout.fillWidth: true }
            }

            Repeater {
                model: {
                    const revision = ospfRoutingForm.statsRevision
                    const item = ospfRoutingForm.selectedProcessItem()
                    return item ? item.interfaceSettings : null
                }
                delegate: RowLayout {
                    required property string interface_name
                    required property string area
                    required property string cost
                    required property string hello_interval
                    required property string dead_interval
                    required property string network_type
                    required property string auth_type
                    required property int index
                    Layout.fillWidth: true
                    Text { Layout.fillWidth: true; text: interface_name; color: Theme.accentColor; font.family: Theme.fontFamily; elide: Text.ElideRight }
                    Text { Layout.preferredWidth: 72; text: "area " + area; color: Theme.textPrimary; font.family: Theme.fontFamily }
                    Text { Layout.fillWidth: true; text: cost ? ("cost " + cost) : ""; color: Theme.textSecondary; font.family: Theme.fontFamily }
                    Text { Layout.fillWidth: true; text: hello_interval || dead_interval ? ("hello/dead " + hello_interval + "/" + dead_interval) : ""; color: Theme.textSecondary; font.family: Theme.fontFamily }
                    Text { Layout.fillWidth: true; text: network_type || auth_type; color: Theme.textSecondary; font.family: Theme.fontFamily; elide: Text.ElideRight }
                    StandardButton { Layout.preferredWidth: 34; type: "Icon"; icon.source: "qrc:/qt/qml/NetworkTools/resources/devicetabs/close.svg"; tooltip: "Remove interface setting"; onClicked: ospfRoutingForm.removeInterfaceSettingFromSelectedProcess(index) }
                }
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
