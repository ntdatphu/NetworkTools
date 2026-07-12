pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import UI

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
    property bool isRunningConfigRunning: false
    property string runningConfigTargetIp: ""
    property string pendingRunningConfigIp: ""
    property bool pythonDepsChecking: false
    property string pythonDepsStatus: "idle"
    property string pythonDepsStatusText: "IDLE"
    property string pythonDepsStatusDetail: "Click to check Python runtime and login packages."
    readonly property bool deviceShortcutEnabled: devicesPanel.visible && !UiState.windowLock && !searchBar.inputActiveFocus

    signal deviceSelected(string ip, string name, string deviceType, string status)
    signal deviceDeleted(string ip)
    signal devicesLoaded(var devices)

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
        devicesPanel.devicesLoaded(devicesPanel.allDevices)
    }

    function openNewDeviceWindow() {
        newDeviceLoader.active = true
        if (UiState.windowLock && !newDeviceLoader.item.visible) UiState.windowLock = false
        newDeviceLoader.item.resetAndOpen(false, null)
    }

    function openBatchDeviceWindow() {
        batchDeviceLoader.active = true
        if (UiState.windowLock && !batchDeviceLoader.item.visible) UiState.windowLock = false
        batchDeviceLoader.item.resetAndOpen()
    }

    function handleEditDevice(ip) {
        const deviceData = dbManager.getDeviceByHost(ip)
        if (!deviceData || !deviceData.ip) return
        newDeviceLoader.active = true
        if (UiState.windowLock && !newDeviceLoader.item.visible) UiState.windowLock = false
        if (!UiState.windowLock) {
            UiState.windowLock = true
            newDeviceLoader.item.resetAndOpen(true, deviceData)
        }
    }

    function handleDeleteDevice(ip) {
        deleteConfirmLoader.active = true
        deleteConfirmLoader.item.targetIp = ip
        deleteConfirmLoader.item.openAlert()
    }

    function devicesForSection(section) {
        if (section === 0) return connectedSection.devices
        if (section === 1) return waitingSection.devices
        if (section === 2) return disconnectedSection.devices
        return []
    }

    function selectedDevice() {
        const list = devicesForSection(devicesPanel.selectedSection)
        if (devicesPanel.selectedIndex < 0 || devicesPanel.selectedIndex >= list.length)
            return null
        return list[devicesPanel.selectedIndex]
    }

    function showDeviceShortcutMessage(message, type) {
        if (typeof statusBar !== "undefined")
            statusBar.showMessage(message, type || "warning")
    }

    function operationSeverity(result) {
        if (result && result.severity)
            return String(result.severity)
        return result && result.ok ? "success" : "error"
    }

    function operationMessage(result, fallbackMessage) {
        if (result && result.message)
            return String(result.message)
        return fallbackMessage
    }

    function notifyOperationResult(result, fallbackMessage) {
        showDeviceShortcutMessage(operationMessage(result, fallbackMessage), operationSeverity(result))
    }

    function requireShortcutDevice(actionName) {
        const dev = selectedDevice()
        if (!dev)
            showDeviceShortcutMessage("Select a device before using " + actionName + ".", "warning")
        return dev
    }

    function requireShortcutStatus(dev, actionName, statusName) {
        if (!dev)
            return false
        if (dev.status !== statusName) {
            showDeviceShortcutMessage(actionName + " is available only for " + statusName + " devices.", "warning")
            return false
        }
        return true
    }

    function handleDeviceRightClicked(section, ip, status, mx, my) {
        const list = devicesForSection(section)
        for (let i = 0; i < list.length; i++) {
            if (list[i].ip === ip) {
                devicesPanel.selectedSection = section
                devicesPanel.selectedIndex = i
                break
            }
        }
        deviceContextMenu.openAt(mx, my, ip, status)
    }

    function handlePingDevice(ip) {
        const result = cli.pingHost(ip)
        notifyOperationResult(result, "Ping finished for " + ip + ".")
    }

    function handleUpDevDevice(ip) {
        const result = dbManager.setDeviceDevState(ip, 1, 1)
        notifyOperationResult(result, "Up (Dev) finished for " + ip + ".")
        if (result && result.ok)
            devicesPanel.reloadDevices()
    }

    function handleDownDevDevice(ip) {
        const result = dbManager.setDeviceDevState(ip, 0, 0)
        notifyOperationResult(result, "Down (Dev) finished for " + ip + ".")
        if (result && result.ok)
            devicesPanel.reloadDevices()
    }

    function handleReconnectDevice(ip) {
        const result = dbManager.resetDeviceToWaiting(ip)
        notifyOperationResult(result, "Reset to Waiting finished for " + ip + ".")
        if (result && result.ok)
            devicesPanel.reloadDevices()
    }

    function handleShortcutReconnect() {
        const dev = requireShortcutDevice("Reconnect")
        if (requireShortcutStatus(dev, "Reconnect", "disconnected"))
            devicesPanel.handleReconnectDevice(dev.ip)
    }

    function handleConnectDevice(ip) {
        if (devicesPanel.isConnectRunning) {
            showDeviceShortcutMessage("A connect task is already running for " + devicesPanel.connectTargetIp, "warning")
            return
        }
        devicesPanel.isConnectRunning = true
        devicesPanel.connectTargetIp = ip
        devicesPanel.pendingConnectIp = ip
        if (typeof cli === "undefined" || !cli.connectHostAndSyncAsync) {
            devicesPanel.pendingConnectIp = ""
            devicesPanel.connectTargetIp = ""
            devicesPanel.isConnectRunning = false
            showDeviceShortcutMessage("Async connect backend is not available.", "error")
            return
        }

        const accepted = cli.connectHostAndSyncAsync(ip)
        if (!accepted) {
            devicesPanel.pendingConnectIp = ""
            devicesPanel.connectTargetIp = ""
            devicesPanel.isConnectRunning = false
            showDeviceShortcutMessage("Connect task could not start for " + ip + ".", "error")
        }
    }

    function handleRunningConfigDevice(ip) {
        if (devicesPanel.isRunningConfigRunning) {
            showDeviceShortcutMessage("A running-config task is already running for " + devicesPanel.runningConfigTargetIp, "warning")
            return
        }
        devicesPanel.isRunningConfigRunning = true
        devicesPanel.runningConfigTargetIp = ip
        devicesPanel.pendingRunningConfigIp = ip
        if (typeof cli === "undefined" || !cli.saveRunningConfigBackupAsync) {
            devicesPanel.pendingRunningConfigIp = ""
            devicesPanel.runningConfigTargetIp = ""
            devicesPanel.isRunningConfigRunning = false
            showDeviceShortcutMessage("Async running-config backend is not available.", "error")
            return
        }

        const accepted = cli.saveRunningConfigBackupAsync(ip)
        if (!accepted) {
            devicesPanel.pendingRunningConfigIp = ""
            devicesPanel.runningConfigTargetIp = ""
            devicesPanel.isRunningConfigRunning = false
            showDeviceShortcutMessage("Running-config task could not start for " + ip + ".", "error")
        }
    }

    function handleShortcutEdit() {
        const dev = requireShortcutDevice("Edit")
        if (dev)
            devicesPanel.handleEditDevice(dev.ip)
    }

    function handleCliDevice(ip) {
        if (!ip) return
        if (typeof externalTools !== "undefined") {
            const res = externalTools.openDeviceCli(ip)
            if (!res.ok) {
                toastManager.showToast("CLI Error: " + (res.message || "Failed to launch SSH Client."), "error")
            } else {
                toastManager.showToast("CLI Launched: " + (res.message || `Connected to ${ip}`), "success")
            }
        } else {
            toastManager.showToast("CLI Error: External Tools manager is not available.", "error")
        }
    }

    function handleShortcutPing() {
        const dev = requireShortcutDevice("Ping")
        if (requireShortcutStatus(dev, "Ping", "connected"))
            devicesPanel.handlePingDevice(dev.ip)
    }

    function handleShortcutDownDev() {
        const dev = requireShortcutDevice("Down (Dev)")
        if (requireShortcutStatus(dev, "Down (Dev)", "connected"))
            devicesPanel.handleDownDevDevice(dev.ip)
    }

    function handleShortcutUpDev() {
        const dev = requireShortcutDevice("Up (Dev)")
        if (requireShortcutStatus(dev, "Up (Dev)", "waiting"))
            devicesPanel.handleUpDevDevice(dev.ip)
    }

    function handleShortcutConnect() {
        const dev = requireShortcutDevice("Connect")
        if (requireShortcutStatus(dev, "Connect", "waiting"))
            devicesPanel.handleConnectDevice(dev.ip)
    }

    function handleShortcutDelete() {
        const dev = requireShortcutDevice("Delete")
        if (dev)
            devicesPanel.handleDeleteDevice(dev.ip)
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
        devicesPanel.deviceSelected(dev.ip, dev.name, dev.type || "unknown", dev.status || "disconnected")
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
            onAddMultipleClicked: {
                if (!UiState.windowLock) {
                    UiState.windowLock = true
                    devicesPanel.openBatchDeviceWindow()
                }
            }
            onAddClicked: {
                if (!UiState.windowLock) {
                    UiState.windowLock = true
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
            contentWidth: width
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.policy: ScrollBar.AsNeeded

            Column {
                width: deviceScrollView.width
                DeviceSection {
                    id: connectedSection; width: parent.width; sectionTitle: "Connected"; expanded: true
                    selectedIndex: devicesPanel.selectedSection === 0 ? devicesPanel.selectedIndex : -1; displayFormat: devicesPanel.displayFormat
                    onDeviceClicked: (idx) => devicesPanel.handleDeviceClicked(0, idx)
                    onDeviceRightClicked: (ip, status, mx, my) => devicesPanel.handleDeviceRightClicked(0, ip, status, mx, my)
                }
                DeviceSection {
                    id: waitingSection; width: parent.width; sectionTitle: "Waiting"; expanded: true
                    selectedIndex: devicesPanel.selectedSection === 1 ? devicesPanel.selectedIndex : -1; displayFormat: devicesPanel.displayFormat
                    onDeviceClicked: (idx) => devicesPanel.handleDeviceClicked(1, idx)
                    onDeviceRightClicked: (ip, status, mx, my) => devicesPanel.handleDeviceRightClicked(1, ip, status, mx, my)
                }
                DeviceSection {
                    id: disconnectedSection; width: parent.width; sectionTitle: "Disconnected"; expanded: false; autoExpand: false
                    selectedIndex: devicesPanel.selectedSection === 2 ? devicesPanel.selectedIndex : -1; displayFormat: devicesPanel.displayFormat
                    onDeviceClicked: (idx) => devicesPanel.handleDeviceClicked(2, idx)
                    onDeviceRightClicked: (ip, status, mx, my) => devicesPanel.handleDeviceRightClicked(2, ip, status, mx, my)
                }
                Item { width: 1; height: 8 }
            }
        }
    }

    // ── COMPONENT PHỤ TRỢ (Loaders, Menus, Timers) ───────────────────────────
    StandardDropdown { id: standardDropdown; anchors.top: parent.top; anchors.topMargin: 36; anchors.right: parent.right; anchors.rightMargin: 4; z: 10; onFiltersChanged: devicesPanel.applyFilters() }

    DeviceContextMenu {
        id: deviceContextMenu; parent: Overlay.overlay; connectRunning: devicesPanel.isConnectRunning; runningIp: devicesPanel.connectTargetIp; runningConfigRunning: devicesPanel.isRunningConfigRunning; runningConfigIp: devicesPanel.runningConfigTargetIp
        onPingRequested: (ip) => devicesPanel.handlePingDevice(ip)
        onRunningConfigRequested: (ip) => devicesPanel.handleRunningConfigDevice(ip)
        onEditRequested: (ip) => devicesPanel.handleEditDevice(ip)
        onDeleteRequested: (ip) => devicesPanel.handleDeleteDevice(ip)
        onUpDevRequested: (ip) => devicesPanel.handleUpDevDevice(ip)
        onDownDevRequested: (ip) => devicesPanel.handleDownDevDevice(ip)
        onConnecRequested: (_ip) => devicesPanel.handleConnectDevice(_ip)
        onReconnectRequested: (ip) => devicesPanel.handleReconnectDevice(ip)
        onCliRequested: (ip) => devicesPanel.handleCliDevice(ip)
    }

    Connections {
        target: typeof cli !== "undefined" ? cli : null
        function onConnectHostFinished(host, ok, message) {
            const targetIp = String(host || "")
            if (targetIp !== devicesPanel.pendingConnectIp)
                return
            devicesPanel.reloadDevices()
            devicesPanel.pendingConnectIp = ""
            devicesPanel.connectTargetIp = ""
            devicesPanel.isConnectRunning = false
        }

        function onRunningConfigFinished(host, ok, message) {
            const targetIp = String(host || "")
            if (targetIp !== devicesPanel.pendingRunningConfigIp)
                return
            devicesPanel.pendingRunningConfigIp = ""
            devicesPanel.runningConfigTargetIp = ""
            devicesPanel.isRunningConfigRunning = false
        }

        function onDeviceSessionClosed(host) {
            devicesPanel.reloadDevices()
        }
    }

    Timer {
        id: pythonDepsCheckTimer
        interval: 1
        repeat: false

        onTriggered: {
            if (devicesPanel.pythonDepsChecking)
                return

            devicesPanel.pythonDepsChecking = true
            devicesPanel.pythonDepsStatus = "checking"
            devicesPanel.pythonDepsStatusText = "CHECKING..."
            devicesPanel.pythonDepsStatusDetail = "Checking Python runtime and login packages..."

            const result = cli.ensurePythonLoginDeps()
            const detailMessage = result.message ? String(result.message) : "Python dependency check finished."

            devicesPanel.pythonDepsStatus = result.ok ? "success" : "error"
            devicesPanel.pythonDepsStatusText = result.ok ? "READY" : "NOT READY"
            devicesPanel.pythonDepsStatusDetail = detailMessage
            devicesPanel.pythonDepsChecking = false
        }
    }
    Timer { id: searchDebounceTimer; interval: 300; repeat: false; onTriggered: devicesPanel.applyFilters() }

    Shortcut { sequence: "Ctrl+N"; onActivated: { if (!UiState.windowLock) { UiState.windowLock = true; devicesPanel.openNewDeviceWindow() } } }
    Shortcut { sequence: "Ctrl+Shift+N"; onActivated: { if (!UiState.windowLock) { UiState.windowLock = true; devicesPanel.openBatchDeviceWindow() } } }
    Shortcut { sequence: "F2"; enabled: devicesPanel.deviceShortcutEnabled; onActivated: devicesPanel.handleShortcutEdit() }
    Shortcut { sequence: "Ctrl+Alt+P"; enabled: devicesPanel.deviceShortcutEnabled; onActivated: devicesPanel.handleShortcutPing() }
    Shortcut { sequence: "Ctrl+Alt+Down"; enabled: devicesPanel.deviceShortcutEnabled; onActivated: devicesPanel.handleShortcutDownDev() }
    Shortcut { sequence: "Ctrl+Alt+Up"; enabled: devicesPanel.deviceShortcutEnabled; onActivated: devicesPanel.handleShortcutUpDev() }
    Shortcut { sequence: "Ctrl+Alt+C"; enabled: devicesPanel.deviceShortcutEnabled; onActivated: devicesPanel.handleShortcutConnect() }
    Shortcut { sequence: "Ctrl+Alt+R"; enabled: devicesPanel.deviceShortcutEnabled; onActivated: devicesPanel.handleShortcutReconnect() }
    Shortcut { sequence: "Del"; enabled: devicesPanel.deviceShortcutEnabled; onActivated: devicesPanel.handleShortcutDelete() }

    Loader {
        id: deleteConfirmLoader
        active: false
        sourceComponent: Component {
            CustomAlert {
                property string targetIp: ""
                titleText: "Confirm Delete"
                messageText: "Are you sure you want to delete\n" + targetIp + "?"
                isError: true

                onAccepted: {
                    if (targetIp !== "") {
                        const result = dbManager.deleteDevice(targetIp)
                        notifyOperationResult(result, "Delete finished for " + targetIp + ".")
                        if (result && result.ok) {
                            devicesPanel.reloadDevices()
                            devicesPanel.deviceDeleted(targetIp)
                        }
                        targetIp = ""
                    }
                }
            }
        }
    }
    Loader { id: newDeviceLoader; active: false; sourceComponent: Component { NewDevice { onDeviceAdded: function(newDev) { devicesPanel.reloadDevices(); const added = devicesPanel.allDevices.find(function(d) { return d.ip === newDev.ip }); if (added && added.status === "waiting") { if (typeof statusBar !== "undefined") statusBar.showMessage("Device added in waiting state. Configuration is disabled until connected.", "warning"); return } devicesPanel.deviceSelected(newDev.ip, newDev.name, added ? added.type : (newDev.type || "unknown"), added ? added.status : (newDev.status || "connected")) }; onDeviceEdited: function(originalIp, dev) { devicesPanel.reloadDevices() } } } }
    Loader {
        id: batchDeviceLoader
        active: false
        sourceComponent: Component {
            BatchNewDevice {
                onDevicesAdded: function(addedList, totalRows, skipped, foldersOk) {
                    devicesPanel.reloadDevices()
                    if (typeof statusBar !== "undefined" && addedList.length > 0) {
                        const hasSkipped = skipped !== undefined && skipped > 0
                        const folderFailed = foldersOk !== undefined && !foldersOk
                        const totalText = totalRows !== undefined && totalRows > 0 ? "/" + totalRows : ""
                        let suffix = hasSkipped ? ". Skipped: %1.".arg(skipped) : "."
                        if (folderFailed)
                            suffix += " Backup folder creation failed."
                        statusBar.showMessage("Added %1%2 devices from batch input%3".arg(addedList.length).arg(totalText).arg(suffix), (hasSkipped || folderFailed) ? "warning" : "success")
                    }
                }
            }
        }
    }

    Component.onCompleted: { devicesPanel.reloadDevices(); pythonDepsCheckTimer.restart() }
}
