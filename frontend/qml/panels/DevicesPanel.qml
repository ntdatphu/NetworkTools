pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import NetworkTools

Item {
    id: devicesPanel

    // ── PUBLIC API ────────────────────────────────────────────────────────────
    property int selectedSection: -1
    property int selectedIndex: -1
    property string displayFormat: "both"
    property var allDevices: []
    property bool isConnectRunning: false
    property string connectTargetIp: ""
    property string pendingConnectIp: ""
    property bool pythonDepsChecking: false
    property string pythonDepsStatus: "idle"
    property string pythonDepsStatusText: "PYTHON: IDLE"
    property string pythonDepsStatusDetail: "Click to check Python runtime and login packages."

    signal deviceSelected(string ip, string name)
    signal deviceDeleted(string ip)
    signal devicesLoaded(var validIps)

    // ── HÀM XỬ LÝ LÕI ─────────────────────────────────────────────────────────
    function applyFilters() {
        let connected = [], waiting = [], disconnected = []
        const searchStr = searchBar.text.toLowerCase()
        const activeStatus = standardDropdown.activeStatusFilters
        const activeType = standardDropdown.activeTypeFilters

        for (let i = 0; i < allDevices.length; i++) {
            const d = allDevices[i]
            const matchStatus = activeStatus.length === 0 || activeStatus.indexOf(d.status) !== -1
            const matchType = activeType.length === 0 || activeType.indexOf(d.type) !== -1
            const matchSearch = searchStr === "" || d.name.toLowerCase().indexOf(searchStr) !== -1 || d.ip.indexOf(searchStr) !== -1

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
        devicesPanel.allDevices = dbManager.getDevices()
        devicesPanel.applyFilters()
        const validIps = devicesPanel.allDevices.map(function(d) { return d.ip })
        devicesPanel.devicesLoaded(validIps)
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
        let list = (section === 0) ? connectedSection.devices : ((section === 1) ? waitingSection.devices : disconnectedSection.devices)
        const dev = list[idx]
        if (!dev) return
        if (dev.status === "waiting") {
            if (typeof statusBar !== "undefined") statusBar.showMessage("Device is waiting. Configuration is disabled.", "warning")
            return
        }
        devicesPanel.selectedSection = section
        devicesPanel.selectedIndex = idx
        devicesPanel.deviceSelected(dev.ip, dev.name)
    }

    function selectDeviceByIp(ip) {
        if (allDevices.length === 0) reloadDevices()
        const sections = [connectedSection.devices, waitingSection.devices, disconnectedSection.devices]
        for (let s = 0; s < sections.length; s++) {
            for (let i = 0; i < sections[s].length; i++) {
                if (sections[s][i].ip === ip) {
                    devicesPanel.selectedSection = s
                    devicesPanel.selectedIndex = i
                    return
                }
            }
        }
        devicesPanel.selectedSection = -1
        devicesPanel.selectedIndex = -1
    }

    function triggerPythonCheck() {
        if (!devicesPanel.pythonDepsChecking) pythonDepsCheckTimer.restart()
    }

    // ── GIAO DIỆN CHÍNH ───────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        SideBarHeader {
            Layout.fillWidth: true
            isFilterActive: standardDropdown.visible
            onFilterClicked: standardDropdown.toggle()
            onRefreshClicked: devicesPanel.reloadDevices()
            onAddClicked: {
                if (!Theme.windowLock) {
                    Theme.windowLock = true
                    devicesPanel.openNewDeviceWindow()
                }
            }
        }

        SideBarSearch {
            id: searchBar
            Layout.fillWidth: true
            Layout.margins: 8
            onTextChanged: searchDebounceTimer.restart()
        }

        ScrollView {
            id: deviceScrollView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            padding: 0
            leftPadding: 0
            rightPadding: 0
            topPadding: 0
            bottomPadding: 0
            contentWidth: availableWidth
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.policy: ScrollBar.AsNeeded

            Column {
                width: deviceScrollView.availableWidth
                DeviceSection {
                    id: connectedSection; width: parent.width; sectionTitle: "Connected"; expanded: true
                    selectedIndex: devicesPanel.selectedSection === 0 ? devicesPanel.selectedIndex : -1; displayFormat: devicesPanel.displayFormat
                    onDeviceClicked: (idx) => devicesPanel.handleDeviceClicked(0, idx)
                    onDeviceRightClicked: (ip, status, mx, my) => deviceContextMenu.openAt(mx, my, ip, status)
                }
                DeviceSection {
                    id: waitingSection; width: parent.width; sectionTitle: "Waiting"; expanded: true
                    selectedIndex: devicesPanel.selectedSection === 1 ? devicesPanel.selectedIndex : -1; displayFormat: devicesPanel.displayFormat
                    onDeviceClicked: (idx) => devicesPanel.handleDeviceClicked(1, idx)
                    onDeviceRightClicked: (ip, status, mx, my) => deviceContextMenu.openAt(mx, my, ip, status)
                }
                DeviceSection {
                    id: disconnectedSection; width: parent.width; sectionTitle: "Disconnected"; expanded: false
                    selectedIndex: devicesPanel.selectedSection === 2 ? devicesPanel.selectedIndex : -1; displayFormat: devicesPanel.displayFormat
                    onDeviceClicked: (idx) => devicesPanel.handleDeviceClicked(2, idx)
                    onDeviceRightClicked: (ip, status, mx, my) => deviceContextMenu.openAt(mx, my, ip, status)
                }
                Item { width: 1; height: 8 }
            }
        }
    }

    // ── COMPONENT PHỤ TRỢ (Loaders, Menus, Timers) ───────────────────────────
    StandardDropdown { id: standardDropdown; anchors.top: parent.top; anchors.topMargin: 36; anchors.right: parent.right; anchors.rightMargin: 4; z: 10; onFiltersChanged: devicesPanel.applyFilters() }

    DeviceContextMenu {
        id: deviceContextMenu; parent: Overlay.overlay; connectRunning: devicesPanel.isConnectRunning; runningIp: devicesPanel.connectTargetIp
        onPingRequested: (ip) => cli.pingHost(ip)
        onAddYangcfgRequested: (ip) => devicesPanel.openAddYangcfgWindow(ip)
        onEditRequested: (ip) => devicesPanel.handleEditDevice(ip)
        onDeleteRequested: (ip) => devicesPanel.handleDeleteDevice(ip)
        onUpAdminRequested: (ip) => { const ok = dbManager.updateDeviceSuccess(ip, 1); if (typeof statusBar !== "undefined") statusBar.showMessage(ok ? "Updated " + ip + " to connected (admin)." : "Failed to update " + ip + " to connected.", ok ? "success" : "error"); if (ok) devicesPanel.reloadDevices() }
        onDownAdminRequested: (ip) => { const ok = dbManager.updateDeviceSuccess(ip, 0); if (typeof statusBar !== "undefined") statusBar.showMessage(ok ? "Updated " + ip + " to waiting (admin)." : "Failed to update " + ip + " to waiting.", ok ? "success" : "error"); if (ok) devicesPanel.reloadDevices() }
        onConnecRequested: (_ip) => { if (devicesPanel.isConnectRunning) { if (typeof statusBar !== "undefined") statusBar.showMessage("A connect task is already running for " + devicesPanel.connectTargetIp, "warning"); return }
            devicesPanel.isConnectRunning = true; devicesPanel.connectTargetIp = _ip; devicesPanel.pendingConnectIp = _ip; if (typeof statusBar !== "undefined") statusBar.showMessage("Connecting " + _ip + "...", "warning"); connectRunTimer.restart() }
    }

    Timer { id: connectRunTimer; interval: 1; repeat: false; onTriggered: { const targetIp = devicesPanel.pendingConnectIp; const result = cli.connectHostAndSync(targetIp); devicesPanel.reloadDevices(); if (typeof statusBar !== "undefined") statusBar.showMessage(result.message ? String(result.message) : "Connect finished for " + targetIp, result.ok ? "success" : "warning"); devicesPanel.pendingConnectIp = ""; devicesPanel.connectTargetIp = ""; devicesPanel.isConnectRunning = false } }
    Timer {
        id: pythonDepsCheckTimer
        interval: 1
        repeat: false

        onTriggered: {
            if (devicesPanel.pythonDepsChecking)
                return

            devicesPanel.pythonDepsChecking = true
            devicesPanel.pythonDepsStatus = "checking"
            devicesPanel.pythonDepsStatusText = "PYTHON: CHECKING..."
            devicesPanel.pythonDepsStatusDetail = "Checking Python runtime and login packages..."

            const result = cli.ensurePythonLoginDeps()
            const detailMessage = result.message ? String(result.message) : "Python dependency check finished."

            devicesPanel.pythonDepsStatus = result.ok ? "success" : "error"
            devicesPanel.pythonDepsStatusText = result.ok ? "PYTHON: READY" : "PYTHON: NOT READY"
            devicesPanel.pythonDepsStatusDetail = detailMessage
            devicesPanel.pythonDepsChecking = false
        }
    }
    Timer { id: searchDebounceTimer; interval: 300; repeat: false; onTriggered: devicesPanel.applyFilters() }

    Shortcut { sequence: "Ctrl+N"; onActivated: { if (!Theme.windowLock) { Theme.windowLock = true; devicesPanel.openNewDeviceWindow() } } }
    Shortcut { sequence: "Ctrl+Shift+N"; onActivated: { if (!Theme.windowLock) { Theme.windowLock = true; devicesPanel.openBatchDeviceWindow() } } }

    Loader { id: deleteConfirmLoader; active: false; sourceComponent: Component { CustomAlert { property string targetIp: ""; titleText: "Confirm Delete"; messageText: "Are you sure you want to delete\n" + targetIp + "?"; isError: true; onAccepted: { if (targetIp !== "") { const ok = dbManager.deleteDevice(targetIp); if (ok) { devicesPanel.reloadDevices(); devicesPanel.deviceDeleted(targetIp) } if (typeof statusBar !== "undefined") statusBar.showMessage(ok ? "Device " + targetIp + " deleted." : "Failed to delete " + targetIp, ok ? "success" : "error"); targetIp = "" } } } } }
    Loader { id: newDeviceLoader; active: false; sourceComponent: Component { NewDevice { onDeviceAdded: function(newDev) { devicesPanel.reloadDevices(); const added = devicesPanel.allDevices.find(function(d) { return d.ip === newDev.ip }); if (added && added.status === "waiting") { if (typeof statusBar !== "undefined") statusBar.showMessage("Device added in waiting state. Configuration is disabled until connected.", "warning"); return } devicesPanel.deviceSelected(newDev.ip, newDev.name) }; onDeviceEdited: function(originalIp, dev) { devicesPanel.reloadDevices() } } } }
    Loader { id: batchDeviceLoader; active: false; sourceComponent: Component { BatchNewDevice { onDevicesAdded: function(addedList) { devicesPanel.reloadDevices(); if (typeof statusBar !== "undefined") statusBar.showMessage("Added " + addedList.length + " devices from batch input.", "success") } } } }
    Loader { id: addYangcfgLoader; active: false; sourceComponent: Component { AddYangcfg { onYangcfgAdded: function(hostIp) { if (typeof statusBar !== "undefined") statusBar.showMessage("Yangcfg added for " + hostIp, "success") } } } }

    Component.onCompleted: { devicesPanel.reloadDevices(); pythonDepsCheckTimer.restart() }
}
