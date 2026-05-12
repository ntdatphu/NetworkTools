pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import NetworkTools

Rectangle {
    id: panelSideBar
    color: Theme.sideBarBackground

    // ── Public API ────────────────────────────────────────────────────────────
    property int selectedSection: -1
    property int selectedIndex: -1
    property string displayFormat: "both"
    property var allDevices: []
    property bool hasActiveTabs: false
    property bool isConnectRunning: false
    property string connectTargetIp: ""
    property string pendingConnectIp: ""
    property bool pythonDepsChecking: false
    property var openEditorItems: []

    signal deviceSelected(string ip, string name)
    signal deviceDeleted(string ip)
    signal devicesLoaded(var validIps)
    signal openEditorSelected(string uid)
    signal openEditorCloseRequested(string uid)

    // ── Functions ─────────────────────────────────────────────────────────────
    function applyFilters() {
        let connected    = []
        let waiting      = []
        let disconnected = []

        const searchStr    = searchBar.text.toLowerCase()
        const activeStatus = standardDropdown.activeStatusFilters
        const activeType   = standardDropdown.activeTypeFilters

        for (let i = 0; i < allDevices.length; i++) {
            const d = allDevices[i]
            const matchStatus = activeStatus.length === 0
                                || activeStatus.indexOf(d.status) !== -1
            const matchType   = activeType.length === 0
                                || activeType.indexOf(d.type) !== -1
            const matchSearch = searchStr === ""
                                || d.name.toLowerCase().indexOf(searchStr) !== -1
                                || d.ip.indexOf(searchStr) !== -1

            if (matchStatus && matchType && matchSearch) {
                if      (d.status === "connected")    connected.push(d)
                else if (d.status === "waiting")      waiting.push(d)
                else if (d.status === "disconnected") disconnected.push(d)
            }
        }

        connectedSection.devices    = connected
        waitingSection.devices      = waiting
        disconnectedSection.devices = disconnected
    }

    function reloadDevices() {
        panelSideBar.allDevices = dbManager.getDevices()
        panelSideBar.applyFilters()
        const validIps = panelSideBar.allDevices.map(function(d) { return d.ip })
        panelSideBar.devicesLoaded(validIps)
    }

    function openNewDeviceWindow() {
        newDeviceLoader.active = true
        if (Theme.windowLock && !newDeviceLoader.item.visible)
            Theme.windowLock = false
        newDeviceLoader.item.resetAndOpen(false, null)
    }

    function openBatchDeviceWindow() {
        batchDeviceLoader.active = true
        if (Theme.windowLock && !batchDeviceLoader.item.visible)
            Theme.windowLock = false
        batchDeviceLoader.item.resetAndOpen()
    }

    function openAddYangcfgWindow(hostIp) {
        addYangcfgLoader.active = true
        if (Theme.windowLock && !addYangcfgLoader.item.visible)
            Theme.windowLock = false
        if (!Theme.windowLock) {
            Theme.windowLock = true
            addYangcfgLoader.item.resetAndOpen(hostIp)
        }
    }

    function handleEditDevice(ip) {
        const deviceData = dbManager.getDeviceByHost(ip)
        if (!deviceData || !deviceData.ip) return
        newDeviceLoader.active = true
        if (Theme.windowLock && !newDeviceLoader.item.visible)
            Theme.windowLock = false
        if (!Theme.windowLock) {
            Theme.windowLock = true
            newDeviceLoader.item.resetAndOpen(true, deviceData)
        }
    }

    function handleDeleteDevice(ip) {
        deleteConfirmLoader.active = true
        deleteConfirmLoader.item.targetIp = ip
        deleteConfirmLoader.item.openAlert()
    }

    function handleDeviceClicked(section, idx) {
        let list
        if      (section === 0) list = connectedSection.devices
        else if (section === 1) list = waitingSection.devices
        else                    list = disconnectedSection.devices

        const dev = list[idx]
        if (!dev) return

        if (dev.status === "waiting") {
            if (typeof statusBar !== "undefined")
                statusBar.showMessage(
                    "Device is waiting. Configuration is disabled.", "warning")
            return
        }

        panelSideBar.selectedSection = section
        panelSideBar.selectedIndex   = idx
        panelSideBar.deviceSelected(dev.ip, dev.name)
    }

    function selectDeviceByIp(ip) {
        if (allDevices.length === 0) reloadDevices()
        const sections = [
            connectedSection.devices,
            waitingSection.devices,
            disconnectedSection.devices
        ]
        for (let s = 0; s < sections.length; s++) {
            for (let i = 0; i < sections[s].length; i++) {
                if (sections[s][i].ip === ip) {
                    panelSideBar.selectedSection = s
                    panelSideBar.selectedIndex   = i
                    return
                }
            }
        }
        panelSideBar.selectedSection = -1
        panelSideBar.selectedIndex   = -1
    }

    function triggerPythonCheck() {
        if (!panelSideBar.pythonDepsChecking)
            pythonDepsCheckTimer.restart()
    }

    // ─────────────────────────────────────────────────────────────────────────
    // LAYOUT
    // Cấu trúc:
    //   ┌─ fixedHeader (anchors.top)
    //   ├─ openEditorsSection (anchors.bottom) ← cố định dưới cùng
    //   └─ mainScrollView (top=fixedHeader.bottom, bottom=openEditorsSection.top)
    // ─────────────────────────────────────────────────────────────────────────

    // ── 1. HEADER ─────────────────────────────────────────────────────────────
    Column {
        id: fixedHeader
        anchors.top:   parent.top
        anchors.left:  parent.left
        anchors.right: parent.right
        z: 1

        SideBarHeader {
            width: parent.width
            isFilterActive: standardDropdown.visible
            onFilterClicked:  standardDropdown.toggle()
            onRefreshClicked: panelSideBar.reloadDevices()
            onAddClicked: {
                if (!Theme.windowLock) {
                    Theme.windowLock = true
                    panelSideBar.openNewDeviceWindow()
                }
            }
        }

        SideBarSearch {
            id: searchBar
            width: parent.width - 16
            anchors.horizontalCenter: parent.horizontalCenter
            onTextChanged: searchDebounceTimer.restart()
        }

        Item { width: 1; height: 6 }
    }

    // ── 2. OPEN EDITORS — neo dưới cùng ──────────────────────────────────────
    Column {
        id: openEditorsSection
        anchors.bottom: parent.bottom
        anchors.left:   parent.left
        anchors.right:  parent.right
        visible:        panelSideBar.hasActiveTabs

        // Divider
        Rectangle {
            width:   parent.width
            height:  Theme.borderWidth
            color:   Theme.borderColor
            opacity: 0.8
        }

        // Header row
        Rectangle {
            id: openEditorsHeader
            width:  parent.width
            height: Theme.listItemHeight
            color:  openEditorsHeaderHover.hovered
                        ? Theme.sideBarItemHover : "transparent"

            property bool sectionExpanded: true

            Row {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left:           parent.left
                anchors.leftMargin:     8
                spacing:                4

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text:           openEditorsHeader.sectionExpanded ? "▾" : "▸"
                    font.pixelSize: 10
                    color:          Theme.textSecondary
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text:                "OPEN EDITORS"
                    font.pixelSize:      Theme.fontSizeSmall
                    font.family:         Theme.fontFamily
                    font.capitalization: Font.AllUppercase
                    font.weight:         Font.Medium
                    color:               Theme.textSecondary
                }
            }

            HoverHandler { id: openEditorsHeaderHover }
            TapHandler {
                onTapped: openEditorsHeader.sectionExpanded =
                          !openEditorsHeader.sectionExpanded
            }
        }

        // Editor items
        Column {
            id: openEditorsList
            width:   parent.width
            visible: openEditorsHeader.sectionExpanded

            Repeater {
                model: Math.min(
                    panelSideBar.openEditorItems
                        ? panelSideBar.openEditorItems.length : 0,
                    Theme.openEditorsMaxCount
                )

                delegate: Rectangle {
                    required property int index

                    readonly property var itemData:
                        panelSideBar.openEditorItems
                            ? panelSideBar.openEditorItems[index] : null

                    readonly property bool isActiveEditor:
                        itemData ? itemData.isActive : false

                    width:  openEditorsList.width
                    height: Theme.listItemHeight

                    color: isActiveEditor
                               ? Theme.sideBarItemSelected
                               : (editorItemHover.hovered
                                      ? Theme.sideBarItemHover : "transparent")

                    Behavior on color {
                        ColorAnimation { duration: Theme.animationDurationFast }
                    }

                    // Active bar
                    Rectangle {
                        width:   2
                        height:  parent.height
                        color:   Theme.accentColor
                        opacity: isActiveEditor ? 1.0 : 0.0
                        Behavior on opacity {
                            NumberAnimation { duration: Theme.animationDurationFast }
                        }
                    }

                    // Close button + title
                    Row {
                        anchors.fill:        parent
                        anchors.leftMargin:  20
                        anchors.rightMargin: 8
                        spacing:             6

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width:  14; height: 14
                            radius: 3
                            color:  closeEditorHover.hovered
                                        ? Theme.sideBarItemHover : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text:           "✕"
                                font.pixelSize: 9
                                font.family:    Theme.fontFamily
                                color: closeEditorHover.hovered
                                           ? Theme.textPrimary : "transparent"
                            }

                            HoverHandler { id: closeEditorHover }
                            TapHandler {
                                onTapped: {
                                    if (itemData)
                                        panelSideBar.openEditorCloseRequested(
                                            itemData.uid)
                                }
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width:          parent.width - 20
                            text:           itemData ? itemData.title : ""
                            color:          isActiveEditor
                                                ? Theme.textPrimary
                                                : Theme.textSecondary
                            font.pixelSize: Theme.fontSizeNormal
                            font.family:    Theme.fontFamily
                            elide:          Text.ElideRight
                            Behavior on color {
                                ColorAnimation { duration: Theme.animationDurationFast }
                            }
                        }
                    }

                    HoverHandler { id: editorItemHover }
                    TapHandler {
                        onTapped: {
                            if (itemData)
                                panelSideBar.openEditorSelected(itemData.uid)
                        }
                    }
                }
            }

            // +N more...
            Text {
                width:   parent.width
                height:  Theme.listItemHeight
                visible: panelSideBar.openEditorItems
                         && panelSideBar.openEditorItems.length
                            > Theme.openEditorsMaxCount
                leftPadding:       32
                verticalAlignment: Text.AlignVCenter
                text: panelSideBar.openEditorItems
                      ? "+" + (panelSideBar.openEditorItems.length
                               - Theme.openEditorsMaxCount) + " more..."
                      : ""
                color:          Theme.textDisabled
                font.pixelSize: Theme.fontSizeSmall
                font.family:    Theme.fontFamily
            }
        }
    }

    // ── 3. DEVICE LIST ────────────────────────────────────────────────────────
    // anchors.bottom neo vào openEditorsSection.top khi visible,
    // hoặc parent.bottom khi không có tab nào
    ScrollView {
        id: mainScrollView
        anchors.top:    fixedHeader.bottom
        anchors.left:   parent.left
        anchors.right:  parent.right
        anchors.bottom: openEditorsSection.visible
                            ? openEditorsSection.top
                            : parent.bottom
        clip: true
        contentWidth: width
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy:   ScrollBar.AsNeeded

        Column {
            width: mainScrollView.width

            DeviceSection {
                id: connectedSection
                width: parent.width
                sectionTitle: "Connected"
                expanded: true
                selectedIndex: panelSideBar.selectedSection === 0
                               ? panelSideBar.selectedIndex : -1
                displayFormat: panelSideBar.displayFormat
                onDeviceClicked:      (idx) => panelSideBar.handleDeviceClicked(0, idx)
                onDeviceRightClicked: (ip, status, mx, my) =>
                    deviceContextMenu.openAt(mx, my, ip, status)
            }

            DeviceSection {
                id: waitingSection
                width: parent.width
                sectionTitle: "Waiting"
                expanded: true
                selectedIndex: panelSideBar.selectedSection === 1
                               ? panelSideBar.selectedIndex : -1
                displayFormat: panelSideBar.displayFormat
                onDeviceClicked:      (idx) => panelSideBar.handleDeviceClicked(1, idx)
                onDeviceRightClicked: (ip, status, mx, my) =>
                    deviceContextMenu.openAt(mx, my, ip, status)
            }

            DeviceSection {
                id: disconnectedSection
                width: parent.width
                sectionTitle: "Disconnected"
                expanded: false
                selectedIndex: panelSideBar.selectedSection === 2
                               ? panelSideBar.selectedIndex : -1
                displayFormat: panelSideBar.displayFormat
                onDeviceClicked:      (idx) => panelSideBar.handleDeviceClicked(2, idx)
                onDeviceRightClicked: (ip, status, mx, my) =>
                    deviceContextMenu.openAt(mx, my, ip, status)
            }

            Item { width: 1; height: 8 }
        }
    }

    // ── 4. FILTER DROPDOWN ────────────────────────────────────────────────────
    StandardDropdown {
        id: standardDropdown
        anchors.top:         parent.top
        anchors.topMargin:   36
        anchors.right:       parent.right
        anchors.rightMargin: 4
        z: 10
        onFiltersChanged: panelSideBar.applyFilters()
    }

    // ── 5. CONTEXT MENU ───────────────────────────────────────────────────────
    DeviceContextMenu {
        id: deviceContextMenu
        parent: Overlay.overlay
        connectRunning: panelSideBar.isConnectRunning
        runningIp:      panelSideBar.connectTargetIp

        onPingRequested:       (ip) => cli.pingHost(ip)
        onAddYangcfgRequested: (ip) => panelSideBar.openAddYangcfgWindow(ip)
        onEditRequested:       (ip) => panelSideBar.handleEditDevice(ip)
        onDeleteRequested:     (ip) => panelSideBar.handleDeleteDevice(ip)

        onUpAdminRequested: (ip) => {
            const ok = dbManager.updateDeviceSuccess(ip, 1)
            if (typeof statusBar !== "undefined")
                statusBar.showMessage(
                    ok ? "Updated " + ip + " to connected (admin)."
                       : "Failed to update " + ip + " to connected.",
                    ok ? "success" : "error")
            if (ok) panelSideBar.reloadDevices()
        }

        onDownAdminRequested: (ip) => {
            const ok = dbManager.updateDeviceSuccess(ip, 0)
            if (typeof statusBar !== "undefined")
                statusBar.showMessage(
                    ok ? "Updated " + ip + " to waiting (admin)."
                       : "Failed to update " + ip + " to waiting.",
                    ok ? "success" : "error")
            if (ok) panelSideBar.reloadDevices()
        }

        onConnecRequested: (_ip) => {
            if (panelSideBar.isConnectRunning) {
                if (typeof statusBar !== "undefined")
                    statusBar.showMessage(
                        "A connect task is already running for "
                        + panelSideBar.connectTargetIp, "warning")
                return
            }
            panelSideBar.isConnectRunning = true
            panelSideBar.connectTargetIp  = _ip
            panelSideBar.pendingConnectIp = _ip
            if (typeof statusBar !== "undefined")
                statusBar.showMessage("Connecting " + _ip + "...", "warning")
            connectRunTimer.restart()
        }
    }

    // ── 6. TIMERS ─────────────────────────────────────────────────────────────
    Timer {
        id: connectRunTimer
        interval: 1; repeat: false
        onTriggered: {
            const targetIp = panelSideBar.pendingConnectIp
            const result   = cli.connectHostAndSync(targetIp)
            panelSideBar.reloadDevices()
            if (typeof statusBar !== "undefined")
                statusBar.showMessage(
                    result.message ? String(result.message)
                                   : "Connect finished for " + targetIp,
                    result.ok ? "success" : "warning")
            panelSideBar.pendingConnectIp = ""
            panelSideBar.connectTargetIp  = ""
            panelSideBar.isConnectRunning = false
        }
    }

    Timer {
        id: pythonDepsCheckTimer
        interval: 1; repeat: false
        onTriggered: {
            if (panelSideBar.pythonDepsChecking) return
            panelSideBar.pythonDepsChecking = true
            if (typeof statusBar !== "undefined")
                statusBar.showMessage(
                    "Checking Python runtime and login packages...", "warning")
            const result = cli.ensurePythonLoginDeps()
            if (typeof statusBar !== "undefined")
                statusBar.showMessage(
                    result.message ? String(result.message)
                                   : "Python dependency check finished.",
                    result.ok ? "success" : "error")
            panelSideBar.pythonDepsChecking = false
        }
    }

    Timer {
        id: searchDebounceTimer
        interval: 300; repeat: false
        onTriggered: panelSideBar.applyFilters()
    }

    // ── 7. SHORTCUTS ──────────────────────────────────────────────────────────
    Shortcut {
        sequence: "Ctrl+N"
        onActivated: {
            if (!Theme.windowLock) {
                Theme.windowLock = true
                panelSideBar.openNewDeviceWindow()
            }
        }
    }

    Shortcut {
        sequence: "Ctrl+Shift+N"
        onActivated: {
            if (!Theme.windowLock) {
                Theme.windowLock = true
                panelSideBar.openBatchDeviceWindow()
            }
        }
    }

    // ── 8. ĐƯỜNG VIỀN PHẢI ────────────────────────────────────────────────────
    Rectangle {
        anchors.right: parent.right
        width:         Theme.borderWidth
        height:        parent.height
        color:         Theme.borderColor
    }

    // ── 9. LOADERS ────────────────────────────────────────────────────────────
    Loader {
        id: deleteConfirmLoader
        active: false
        sourceComponent: Component {
            CustomAlert {
                property string targetIp: ""
                titleText:   "Confirm Delete"
                messageText: "Are you sure you want to delete\n" + targetIp + "?"
                isError:     true
                onAccepted: {
                    if (targetIp !== "") {
                        const ok = dbManager.deleteDevice(targetIp)
                        if (ok) {
                            panelSideBar.reloadDevices()
                            panelSideBar.deviceDeleted(targetIp)
                        }
                        if (typeof statusBar !== "undefined")
                            statusBar.showMessage(
                                ok ? "Device " + targetIp + " deleted."
                                   : "Failed to delete " + targetIp,
                                ok ? "success" : "error")
                        targetIp = ""
                    }
                }
            }
        }
    }

    Loader {
        id: newDeviceLoader
        active: false
        sourceComponent: Component {
            NewDevice {
                onDeviceAdded: function(newDev) {
                    panelSideBar.reloadDevices()
                    const added = panelSideBar.allDevices.find(
                        function(d) { return d.ip === newDev.ip })
                    if (added && added.status === "waiting") {
                        if (typeof statusBar !== "undefined")
                            statusBar.showMessage(
                                "Device added in waiting state. "
                                + "Configuration is disabled until connected.",
                                "warning")
                        return
                    }
                    panelSideBar.deviceSelected(newDev.ip, newDev.name)
                }
                onDeviceEdited: function(originalIp, dev) {
                    panelSideBar.reloadDevices()
                }
            }
        }
    }

    Loader {
        id: batchDeviceLoader
        active: false
        sourceComponent: Component {
            BatchNewDevice {
                onDevicesAdded: function(addedList) {
                    panelSideBar.reloadDevices()
                    if (typeof statusBar !== "undefined")
                        statusBar.showMessage(
                            "Added " + addedList.length
                            + " devices from batch input.", "success")
                }
            }
        }
    }

    Loader {
        id: addYangcfgLoader
        active: false
        sourceComponent: Component {
            AddYangcfg {
                onYangcfgAdded: function(hostIp) {
                    if (typeof statusBar !== "undefined")
                        statusBar.showMessage(
                            "Yangcfg added for " + hostIp, "success")
                }
            }
        }
    }

    Component.onCompleted: {
        panelSideBar.reloadDevices()
        pythonDepsCheckTimer.restart()
    }
}