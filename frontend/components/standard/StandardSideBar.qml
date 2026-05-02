pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import NetworkUI

// PanelSideBar hiện tại chỉ đóng vai trò Controller cho Device
Rectangle {
    id: panelSideBar

    property int selectedSection: -1
    property int selectedIndex: -1
    property string displayFormat: "both"
    property var allDevices: []
    property bool hasActiveTabs: false
    property bool isConnectRunning: false
    property string connectTargetIp: ""
    property string pendingConnectIp: ""
    property bool pythonDepsChecking: false

    signal deviceSelected(string ip, string name)
    signal deviceDeleted(string ip)
    signal devicesLoaded(var validIps)

    // ── Kết nối UI với API của StandardSideBar ──
    isFilterActive: standardDropdown.visible
    onSearchTextChanged: searchDebounceTimer.restart()

    onAddClicked: {
        if (!Theme.windowLock) {
            Theme.windowLock = true
            panelSideBar.openNewDeviceWindow()
        }
    }
    onRefreshClicked: panelSideBar.reloadDevices()
    onFilterClicked: standardDropdown.toggle()

    // ── LOGIC XỬ LÝ (GIỮ NGUYÊN) ────────────────────────────────────────
    function applyFilters() {
        let connected = []
        let waiting = []
        let disconnected = []

        const searchStr = panelSideBar.searchText.toLowerCase()
        const activeStatus = standardDropdown.activeStatusFilters
        const activeType = standardDropdown.activeTypeFilters

        for (let i = 0; i < allDevices.length; i++) {
            const d = allDevices[i]

            const matchStatus = (activeStatus.length === 0 || activeStatus.indexOf(d.status) !== -1)
            const matchType   = (activeType.length === 0   || activeType.indexOf(d.type)   !== -1)
            const matchSearch = (searchStr === "" ||
                                 d.name.toLowerCase().indexOf(searchStr) !== -1 ||
                                 d.ip.indexOf(searchStr) !== -1)

            if (matchStatus && matchType && matchSearch) {
                if (d.status === "connected") connected.push(d)
                else if (d.status === "waiting") waiting.push(d)
                else if (d.status === "disconnected") disconnected.push(d)
            }
        }

        connectedSection.devices = connected
        waitingSection.devices = waiting
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
        if (Theme.windowLock && !newDeviceLoader.item.visible) Theme.windowLock = false
        newDeviceLoader.item.resetAndOpen(false, null)
    }

    function openBatchDeviceWindow() {
        batchDeviceLoader.active = true
        if (Theme.windowLock && !batchDeviceLoader.item.visible) Theme.windowLock = false
        batchDeviceLoader.item.resetAndOpen()
    }

    function openAddYangcfgWindow(hostIp) {
        addYangcfgLoader.active = true
        if (Theme.windowLock && !addYangcfgLoader.item.visible) Theme.windowLock = false
        if (!Theme.windowLock) {
            Theme.windowLock = true
            addYangcfgLoader.item.resetAndOpen(hostIp)
        }
    }

    function handleEditDevice(ip) {
        const deviceData = dbManager.getDeviceByHost(ip)
        if (!deviceData || !deviceData.ip) return

        newDeviceLoader.active = true
        if (Theme.windowLock && !newDeviceLoader.item.visible) Theme.windowLock = false
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
                statusBar.showMessage("Device is waiting. Configuration is disabled.", "warning")
            return
        }

        panelSideBar.selectedSection = section
        panelSideBar.selectedIndex   = idx
        panelSideBar.deviceSelected(dev.ip, dev.name)
    }

    function selectDeviceByIp(ip) {
        if (allDevices.length === 0) reloadDevices()

        const sections = [connectedSection.devices, waitingSection.devices, disconnectedSection.devices]
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
        if (!panelSideBar.pythonDepsChecking) {
            pythonDepsCheckTimer.restart()
        }
    }

    // ── NỘI DUNG CHÍNH (Sẽ chui vào ScrollView của StandardSideBar) ──
    DeviceSection {
        id: connectedSection
        width: parent.width
        sectionTitle: "Connected"
        expanded: true
        selectedIndex: panelSideBar.selectedSection === 0 ? panelSideBar.selectedIndex : -1
        displayFormat: panelSideBar.displayFormat
        onDeviceClicked:      (idx) => { panelSideBar.handleDeviceClicked(0, idx) }
        onDeviceRightClicked: (ip, status, mx, my) => deviceContextMenu.openAt(mx, my, ip, status)
    }

    DeviceSection {
        id: waitingSection
        width: parent.width
        sectionTitle: "Waiting"
        expanded: true
        selectedIndex: panelSideBar.selectedSection === 1 ? panelSideBar.selectedIndex : -1
        displayFormat: panelSideBar.displayFormat
        onDeviceClicked:      (idx) => { panelSideBar.handleDeviceClicked(1, idx) }
        onDeviceRightClicked: (ip, status, mx, my) => deviceContextMenu.openAt(mx, my, ip, status)
    }

    DeviceSection {
        id: disconnectedSection
        width: parent.width
        sectionTitle: "Disconnected"
        expanded: false
        selectedIndex: panelSideBar.selectedSection === 2 ? panelSideBar.selectedIndex : -1
        displayFormat: panelSideBar.displayFormat
        onDeviceClicked:      (idx) => { panelSideBar.handleDeviceClicked(2, idx) }
        onDeviceRightClicked: (ip, status, mx, my) => deviceContextMenu.openAt(mx, my, ip, status)
    }

    // ── POPUPS, LOADERS & TIMERS ─────────────────────────────────────
    StandardDropdown {
        id: standardDropdown
        anchors.top: parent.top
        anchors.topMargin: 36
        anchors.right: parent.right
        anchors.rightMargin: 4
        z: 10
        onFiltersChanged: panelSideBar.applyFilters()
    }

    DeviceContextMenu {
        id: deviceContextMenu
        parent: Overlay.overlay
        connectRunning: panelSideBar.isConnectRunning
        runningIp: panelSideBar.connectTargetIp

        onPingRequested: (ip) => cli.pingHost(ip)
        onAddYangcfgRequested: (ip) => panelSideBar.openAddYangcfgWindow(ip)
        onEditRequested:   (ip) => panelSideBar.handleEditDevice(ip)
        onDeleteRequested: (ip) => panelSideBar.handleDeleteDevice(ip)

        onUpAdminRequested: (ip) => {
            if (dbManager.updateDeviceSuccess(ip, 1)) {
                panelSideBar.reloadDevices()
                if (typeof statusBar !== "undefined") statusBar.showMessage("Updated " + ip + " to connected (admin).", "success")
            } else {
                if (typeof statusBar !== "undefined") statusBar.showMessage("Failed to update " + ip + " to connected.", "error")
            }
        }
        onDownAdminRequested: (ip) => {
            if (dbManager.updateDeviceSuccess(ip, 0)) {
                panelSideBar.reloadDevices()
                if (typeof statusBar !== "undefined") statusBar.showMessage("Updated " + ip + " to waiting (admin).", "success")
            } else {
                if (typeof statusBar !== "undefined") statusBar.showMessage("Failed to update " + ip + " to waiting.", "error")
            }
        }
        onConnecRequested: (_ip) => {
            if (panelSideBar.isConnectRunning) {
                if (typeof statusBar !== "undefined") statusBar.showMessage("A connect task is already running for " + panelSideBar.connectTargetIp, "warning")
                return
            }
            panelSideBar.isConnectRunning = true
            panelSideBar.connectTargetIp = _ip
            panelSideBar.pendingConnectIp = _ip
            if (typeof statusBar !== "undefined") statusBar.showMessage("Connecting " + _ip + "...", "warning")
            connectRunTimer.restart()
        }
    }

    Timer {
        id: connectRunTimer
        interval: 1
        repeat: false
        onTriggered: {
            const targetIp = panelSideBar.pendingConnectIp
            const result = cli.connectHostAndSync(targetIp)
            panelSideBar.reloadDevices()

            if (typeof statusBar !== "undefined") {
                const msg = result.message ? String(result.message) : ("Connect finished for " + targetIp)
                statusBar.showMessage(msg, result.ok ? "success" : "warning")
            }

            panelSideBar.pendingConnectIp = ""
            panelSideBar.connectTargetIp = ""
            panelSideBar.isConnectRunning = false
        }
    }

    Timer {
        id: pythonDepsCheckTimer
        interval: 1
        repeat: false
        onTriggered: {
            if (panelSideBar.pythonDepsChecking) return
            panelSideBar.pythonDepsChecking = true

            if (typeof statusBar !== "undefined")
                statusBar.showMessage("Checking Python runtime and login packages...", "warning")

            const result = cli.ensurePythonLoginDeps()

            if (typeof statusBar !== "undefined") {
                const msg = result.message ? String(result.message) : "Python dependency check finished."
                statusBar.showMessage(msg, result.ok ? "success" : "error")
            }
            panelSideBar.pythonDepsChecking = false
        }
    }

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
                        if (dbManager.deleteDevice(targetIp)) {
                            panelSideBar.reloadDevices()
                            panelSideBar.deviceDeleted(targetIp)
                            if (typeof statusBar !== "undefined") statusBar.showMessage("Device " + targetIp + " deleted.", "success")
                        } else {
                            if (typeof statusBar !== "undefined") statusBar.showMessage("Failed to delete " + targetIp, "error")
                        }
                        targetIp = ""
                    }
                }
            }
        }
    }

    Timer {
        id: searchDebounceTimer
        interval: 300
        repeat: false
        onTriggered: panelSideBar.applyFilters()
    }

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

    Loader {
        id: newDeviceLoader
        active: false
        sourceComponent: Component {
            NewDevice {
                onDeviceAdded: function(newDev) {
                    panelSideBar.reloadDevices()
                    const added = panelSideBar.allDevices.find(function(d) { return d.ip === newDev.ip })
                    if (added && added.status === "waiting") {
                        if (typeof statusBar !== "undefined") statusBar.showMessage("Device added in waiting state. Configuration is disabled until connected.", "warning")
                        return
                    }
                    panelSideBar.deviceSelected(newDev.ip, newDev.name)
                }
                onDeviceEdited: function(originalIp, dev) { panelSideBar.reloadDevices() }
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
                    if (typeof statusBar !== "undefined") statusBar.showMessage("Added " + addedList.length + " devices from batch input.", "success")
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
                    if (typeof statusBar !== "undefined") statusBar.showMessage("Yangcfg added for " + hostIp, "success")
                }
            }
        }
    }

    Component.onCompleted: {
        panelSideBar.reloadDevices()
        pythonDepsCheckTimer.restart()
    }
}