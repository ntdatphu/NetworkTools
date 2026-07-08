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
    property bool pythonDepsChecking: false
    property string pythonDepsStatus: "idle"
    property string pythonDepsStatusText: qsTr("IDLE")
    property string pythonDepsStatusDetail: qsTr("Click to check Python runtime and login packages.")
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
        notifyOperationResult(result, qsTr("Ping finished for ") + ip + ".")
    }

    function handleUpAdminDevice(ip) {
        const result = dbManager.setDeviceAdminState(ip, 1, 1)
        notifyOperationResult(result, qsTr("Up (Admin) finished for ") + ip + ".")
        if (result && result.ok)
            devicesPanel.reloadDevices()
    }

    function handleDownAdminDevice(ip) {
        const result = dbManager.setDeviceAdminState(ip, 0, 0)
        notifyOperationResult(result, qsTr("Down (Admin) finished for ") + ip + ".")
        if (result && result.ok)
            devicesPanel.reloadDevices()
    }

    function handleConnectDevice(ip) {
        if (devicesPanel.isConnectRunning) {
            showDeviceShortcutMessage("A connect task is already running for " + devicesPanel.connectTargetIp, "warning")
            return
        }
        devicesPanel.isConnectRunning = true
        devicesPanel.connectTargetIp = ip
        devicesPanel.pendingConnectIp = ip
        showDeviceShortcutMessage("Connecting " + ip + "...", "warning")
        connectRunTimer.restart()
    }

    function handleShortcutEdit() {
        const dev = requireShortcutDevice("Edit")
        if (dev)
            devicesPanel.handleEditDevice(dev.ip)
    }

    function handleShortcutPing() {
        const dev = requireShortcutDevice("Ping")
        if (requireShortcutStatus(dev, "Ping", "connected"))
            devicesPanel.handlePingDevice(dev.ip)
    }

    function handleShortcutDownAdmin() {
        const dev = requireShortcutDevice("Down (Admin)")
        if (requireShortcutStatus(dev, "Down (Admin)", "connected"))
            devicesPanel.handleDownAdminDevice(dev.ip)
    }

    function handleShortcutUpAdmin() {
        const dev = requireShortcutDevice("Up (Admin)")
        if (requireShortcutStatus(dev, "Up (Admin)", "waiting"))
            devicesPanel.handleUpAdminDevice(dev.ip)
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
            if (typeof statusBar !== "undefined") statusBar.showMessage(qsTr("Device is waiting. Configuration is disabled."), "warning")
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
                    id: connectedSection; width: parent.width; sectionTitle: qsTr("Connected"); expanded: true
                    selectedIndex: devicesPanel.selectedSection === 0 ? devicesPanel.selectedIndex : -1; displayFormat: devicesPanel.displayFormat
                    onDeviceClicked: (idx) => devicesPanel.handleDeviceClicked(0, idx)
                    onDeviceRightClicked: (ip, status, mx, my) => devicesPanel.handleDeviceRightClicked(0, ip, status, mx, my)
                }
                DeviceSection {
                    id: waitingSection; width: parent.width; sectionTitle: qsTr("Waiting"); expanded: true
                    selectedIndex: devicesPanel.selectedSection === 1 ? devicesPanel.selectedIndex : -1; displayFormat: devicesPanel.displayFormat
                    onDeviceClicked: (idx) => devicesPanel.handleDeviceClicked(1, idx)
                    onDeviceRightClicked: (ip, status, mx, my) => devicesPanel.handleDeviceRightClicked(1, ip, status, mx, my)
                }
                DeviceSection {
                    id: disconnectedSection; width: parent.width; sectionTitle: qsTr("Disconnected"); expanded: false
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
        id: deviceContextMenu; parent: Overlay.overlay; connectRunning: devicesPanel.isConnectRunning; runningIp: devicesPanel.connectTargetIp
        onPingRequested: (ip) => devicesPanel.handlePingDevice(ip)
        onEditRequested: (ip) => devicesPanel.handleEditDevice(ip)
        onDeleteRequested: (ip) => devicesPanel.handleDeleteDevice(ip)
        onUpAdminRequested: (ip) => devicesPanel.handleUpAdminDevice(ip)
        onDownAdminRequested: (ip) => devicesPanel.handleDownAdminDevice(ip)
        onConnecRequested: (_ip) => devicesPanel.handleConnectDevice(_ip)
    }

    Timer {
        id: connectRunTimer
        interval: 1
        repeat: false
        onTriggered: {
            const targetIp = devicesPanel.pendingConnectIp
            const result = cli.connectHostAndSync(targetIp)
            devicesPanel.reloadDevices()
            notifyOperationResult(result, qsTr("Connect finished for ") + targetIp + ".")
            devicesPanel.pendingConnectIp = ""
            devicesPanel.connectTargetIp = ""
            devicesPanel.isConnectRunning = false
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
            devicesPanel.pythonDepsStatusText = qsTr("CHECKING...")
            devicesPanel.pythonDepsStatusDetail = qsTr("Checking Python runtime and login packages...")

            const result = cli.ensurePythonLoginDeps()
            const detailMessage = result.message ? String(result.message) : qsTr("Python dependency check finished.")

            devicesPanel.pythonDepsStatus = result.ok ? "success" : "error"
            devicesPanel.pythonDepsStatusText = result.ok ? qsTr("READY") : qsTr("NOT READY")
            devicesPanel.pythonDepsStatusDetail = detailMessage
            devicesPanel.pythonDepsChecking = false
        }
    }
    Timer { id: searchDebounceTimer; interval: 300; repeat: false; onTriggered: devicesPanel.applyFilters() }

    Shortcut { sequence: "Ctrl+N"; onActivated: { if (!UiState.windowLock) { UiState.windowLock = true; devicesPanel.openNewDeviceWindow() } } }
    Shortcut { sequence: "Ctrl+Shift+N"; onActivated: { if (!UiState.windowLock) { UiState.windowLock = true; devicesPanel.openBatchDeviceWindow() } } }
    Shortcut { sequence: "F2"; enabled: devicesPanel.deviceShortcutEnabled; onActivated: devicesPanel.handleShortcutEdit() }
    Shortcut { sequence: "Ctrl+Alt+P"; enabled: devicesPanel.deviceShortcutEnabled; onActivated: devicesPanel.handleShortcutPing() }
    Shortcut { sequence: "Ctrl+Alt+Down"; enabled: devicesPanel.deviceShortcutEnabled; onActivated: devicesPanel.handleShortcutDownAdmin() }
    Shortcut { sequence: "Ctrl+Alt+Up"; enabled: devicesPanel.deviceShortcutEnabled; onActivated: devicesPanel.handleShortcutUpAdmin() }
    Shortcut { sequence: "Ctrl+Alt+C"; enabled: devicesPanel.deviceShortcutEnabled; onActivated: devicesPanel.handleShortcutConnect() }
    Shortcut { sequence: "Del"; enabled: devicesPanel.deviceShortcutEnabled; onActivated: devicesPanel.handleShortcutDelete() }

    Loader {
        id: deleteConfirmLoader
        active: false
        sourceComponent: Component {
            CustomAlert {
                property string targetIp: ""
                titleText: qsTr("Confirm Delete")
                messageText: qsTr("Are you sure you want to delete\n") + targetIp + "?"
                isError: true

                onAccepted: {
                    if (targetIp !== "") {
                        const result = dbManager.deleteDevice(targetIp)
                        notifyOperationResult(result, qsTr("Delete finished for ") + targetIp + ".")
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
    Loader { id: newDeviceLoader; active: false; sourceComponent: Component { NewDevice { onDeviceAdded: function(newDev) { devicesPanel.reloadDevices(); const added = devicesPanel.allDevices.find(function(d) { return d.ip === newDev.ip }); if (added && added.status === "waiting") { if (typeof statusBar !== "undefined") statusBar.showMessage(qsTr("Device added in waiting state. Configuration is disabled until connected."), "warning"); return } devicesPanel.deviceSelected(newDev.ip, newDev.name, added ? added.type : (newDev.type || "unknown"), added ? added.status : (newDev.status || "connected")) }; onDeviceEdited: function(originalIp, dev) { devicesPanel.reloadDevices() } } } }
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
                        let suffix = hasSkipped ? qsTr(". Skipped: %1.").arg(skipped) : "."
                        if (folderFailed)
                            suffix += qsTr(" Backup folder creation failed.")
                        statusBar.showMessage(qsTr("Added %1%2 devices from batch input%3").arg(addedList.length).arg(totalText).arg(suffix), (hasSkipped || folderFailed) ? "warning" : "success")
                    }
                }
            }
        }
    }

    Component.onCompleted: { devicesPanel.reloadDevices(); pythonDepsCheckTimer.restart() }
}
