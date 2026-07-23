pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls.Basic
import QtQuick.Effects
import UI

StatefulWindow {
    id: root
    visible: true
    title: "NetworkTools"

    // =====================================================================
    // 1. PROPERTIES (Trạng thái và Cờ điều khiển)
    // =====================================================================
    property bool sidebarVisible: true
    property int unreadNotifications: 0
    property bool isDoNotDisturb: false
    readonly property int notificationHistoryCount: notificationHistoryModel.count
    property string activeSettingKey: "theme"
    property int cliTaskToastId: -1
    property int dbTaskToastId: -1
    property string activeDatabaseTable: ""

    // VS Code SidebarPart uses a 170 px minimum and snap=true. Its SplitView
    // collapses/restores after crossing half that minimum instead of rendering
    // unusably narrow intermediate widths.
    property real savedSidebarWidth: Math.max(Theme.sideBarWidth, minSidebarWidth)
    property real sidebarWidth: savedSidebarWidth
    readonly property real minSidebarWidth: 170
    readonly property real maxSidebarWidth: 600
    readonly property real sidebarSnapThreshold: minSidebarWidth / 2
    property string selectedSyslogHost: ""
    property bool syslogWorkspaceLoaded: false

    readonly property bool isDeviceMode: activityBar.appMode === "devices"
    readonly property bool isSftpMode: activityBar.appMode === "sftp"
    readonly property bool isSyslogMode: activityBar.appMode === "syslog"
    readonly property bool isIndependentMode: false
    readonly property int visibleStatusBarHeight: StatusBarState.isVisible ? Theme.statusBarHeight : 0
    readonly property bool textInputHasFocus: root.activeFocusItem !== null
                                              && (root.activeFocusItem instanceof TextInput
                                                  || root.activeFocusItem instanceof TextEdit)

    onIsSyslogModeChanged: {
        if (root.isSyslogMode)
            root.syslogWorkspaceLoaded = true
    }

    function attachPersistentSettingsBackends() {
        ThemeState.backend = typeof themeSettings !== "undefined" ? themeSettings : null
        StatusBarState.backend = typeof statusBarSettings !== "undefined" ? statusBarSettings : null
    }

    function clampSidebarWidth(width) {
        return Math.min(maxSidebarWidth, Math.max(minSidebarWidth, Number(width)))
    }

    function showSidebar() {
        if (isIndependentMode)
            return
        sidebarWidth = clampSidebarWidth(savedSidebarWidth)
        sidebarVisible = true
    }

    function hideSidebar(rememberCurrentWidth) {
        if (rememberCurrentWidth !== false && sidebarVisible) {
            savedSidebarWidth = clampSidebarWidth(sidebarWidth)
        }
        sidebarVisible = false
        sidebarWidth = savedSidebarWidth
    }

    function toggleSidebar() {
        if (sidebarVisible)
            hideSidebar(true)
        else
            showSidebar()
    }

    function applySidebarDragWidth(desiredWidth) {
        const desired = Number(desiredWidth)
        if (!isFinite(desired))
            return

        if (desired < sidebarSnapThreshold) {
            hideSidebar(false)
            return
        }

        sidebarWidth = clampSidebarWidth(desired)
        sidebarVisible = true
    }

    function finishSidebarResize(desiredWidth) {
        if (sidebarVisible) {
            const desired = Number(desiredWidth)
            savedSidebarWidth = isFinite(desired)
                ? clampSidebarWidth(desired)
                : clampSidebarWidth(sidebarWidth)
            sidebarWidth = savedSidebarWidth
        } else {
            sidebarWidth = savedSidebarWidth
        }
    }

    function setDoNotDisturb(enabled) {
        const nextState = enabled === true
        if (root.isDoNotDisturb === nextState)
            return
        root.isDoNotDisturb = nextState
        if (nextState)
            root.dismissVisibleToasts()
    }

    function dismissVisibleToasts() {
        toastManager.clearToasts()
        // Cleared loading toasts no longer have a valid uid to update.
        root.cliTaskToastId = -1
        root.dbTaskToastId = -1
    }

    function canShowToast() {
        return !root.isDoNotDisturb && !notificationPanel.visible
    }

    function recordNotification(msg, type, showToast) {
        const message = String(msg || "")
        if (message === "")
            return
        const normalizedType = String(type !== undefined ? type : "info").toLowerCase()
        const timestamp = new Date().toLocaleTimeString(Qt.locale(), "HH:mm:ss")
        notificationHistoryModel.insert(0, {
            "msgText": message,
            "msgType": normalizedType,
            "timestamp": timestamp
        })
        if (!notificationPanel.visible)
            root.unreadNotifications++
        if (showToast !== false && root.canShowToast()) {
            toastManager.showToast(message, normalizedType)
        }
    }

    function taskToastId(source) {
        return source === "db" ? root.dbTaskToastId : root.cliTaskToastId
    }

    function setTaskToastId(source, uid) {
        if (source === "db")
            root.dbTaskToastId = uid
        else
            root.cliTaskToastId = uid
    }

    function handleTaskStarted(source, message) {
        recordNotification(message, "loading", false)
        if (root.canShowToast())
            setTaskToastId(source, toastManager.showTask(message))
    }

    function handleTaskProgress(source, message) {
        recordNotification(message, "loading", false)
        const uid = taskToastId(source)
        if (root.canShowToast() && (uid < 0 || !toastManager.updateToast(uid, message, "loading")))
            setTaskToastId(source, toastManager.showTask(message))
    }

    function handleTaskFinished(source, ok, message) {
        const type = ok ? "success" : "error"
        recordNotification(message, type, false)
        if (root.canShowToast())
            toastManager.finishTask(taskToastId(source), message, ok)
        setTaskToastId(source, -1)
    }

    function openDeviceCli(host) {
        const targetHost = String(host || "").trim()
        if (targetHost === "") {
            statusBar.showMessage("Select a device before opening CLI.", "warning")
            return false
        }
        if (typeof externalTools === "undefined" || externalTools === null) {
            statusBar.showMessage("External Tools manager is not available.", "error")
            return false
        }

        const result = externalTools.openDeviceCli(targetHost)
        const ok = result && result.ok === true
        const message = result && result.message
                      ? String(result.message)
                      : (ok
                         ? "SSH Client launched for " + targetHost + "."
                         : "Failed to launch an SSH Client for " + targetHost + ".")
        statusBar.showMessage(message, ok ? "success" : "error")
        return ok
    }

    readonly property bool activeHostConfigEnabled: {
        if (deviceTabs.activeUid === "") return false
        for (let i = 0; i < panelSideBar.allDevices.length; i++) {
            if (panelSideBar.allDevices[i].ip === deviceTabs.activeUid) {
                return panelSideBar.allDevices[i].status !== "waiting"
            }
        }
        return true
    }

    // =====================================================================
    // 2. NON-VISUAL COMPONENTS (Models, Shortcuts, Dialogs, Toasts)
    // =====================================================================
    ListModel {
        id: notificationHistoryModel
    }

    CommandRegistry {
        id: commandRegistry
        objectName: "appCommandRegistry"
        commandsEnabled: !UiState.windowLock
        inputFocusActive: root.textInputHasFocus
        reloadAvailable: contentArea.reloadCommandEnabled
        databaseAvailable: activityBar.canActivateDatabase

        reloadHandler: function() {
            if (root.isSftpMode && sftpWorkspaceLoader.item)
                return sftpWorkspaceLoader.item.refreshActive()
            return contentArea.triggerReloadCommand()
        }
        devicesHandler: function() { return activityBar.activateDevices() }
        databaseHandler: function() { return activityBar.activateDatabase(false) }
        settingsHandler: function() { return activityBar.activateSettings() }
    }

    Shortcut {
        sequence: "Ctrl+Alt+T"
        context: Qt.ApplicationShortcut
        enabled: root.isDeviceMode && deviceTabs.activeUid !== "" && !UiState.windowLock
        onActivated: root.openDeviceCli(deviceTabs.activeUid)
    }

    Shortcut {
        sequence: "Ctrl+B"
        enabled: !root.isIndependentMode
        onActivated: root.toggleSidebar()
    }

    StandardDialog {
        id: aboutDialog
        title: "About NetworkTools"
        subtitle: "Desktop network operations workspace"
        preferredWidth: 460
        implicitHeight: 290
        closeTooltip: "Close About NetworkTools"

        contentItem: Label {
            text: "NetworkTools v1.0\n\nDeveloped by Team 3TM\nPTIT - Ho Chi Minh City\n\nhttps://github.com/ntdatphu/NetworkTools/"
            color: Theme.textPrimary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeNormal
            wrapMode: Text.WordWrap
        }

        footer: Rectangle {
            implicitHeight: 58
            color: "transparent"
            StandardButton {
                anchors.right: parent.right
                anchors.rightMargin: Theme.spacing16
                anchors.verticalCenter: parent.verticalCenter
                text: "Close"
                type: "Primary"
                onClicked: aboutDialog.accept()
            }
        }
    }

    ToastManager {
        id: toastManager
        objectName: "mainToastManager"
    }

    Component.onCompleted: attachPersistentSettingsBackends()

    NotificationPanel {
        id: notificationPanel
        x: root.width - width - 12
        y: root.height - height - root.visibleStatusBarHeight - 8
        model: notificationHistoryModel
        doNotDisturb: root.isDoNotDisturb

        onAboutToShow: {
            root.unreadNotifications = 0
            root.dismissVisibleToasts()
        }
        onClearAllRequested: {
            notificationHistoryModel.clear()
            root.unreadNotifications = 0
        }
        onToggleDndRequested: root.setDoNotDisturb(!root.isDoNotDisturb)
    }

    Connections {
        target: typeof cli !== "undefined" ? cli : null
        function onTaskStarted(message) { root.handleTaskStarted("cli", message) }
        function onTaskProgress(message) { root.handleTaskProgress("cli", message) }
        function onTaskFinished(ok, message) { root.handleTaskFinished("cli", ok, message) }
    }

    Connections {
        target: typeof dbManager !== "undefined" ? dbManager : null
        function onTaskStarted(message) { root.handleTaskStarted("db", message) }
        function onTaskProgress(message) { root.handleTaskProgress("db", message) }
        function onTaskFinished(ok, message) { root.handleTaskFinished("db", ok, message) }
    }

    // =====================================================================
    // 3. MAIN UI LAYOUT
    // =====================================================================
    ColumnLayout {
        id: mainWorkspace
        anchors.fill: parent
        spacing: 0
        layer.enabled: UiState.windowLock
        layer.smooth: true
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: 0.28
            blurMax: 32
            saturation: -0.10
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            ActivityBar {
                id: activityBar
                Layout.preferredWidth: Theme.activityBarWidth
                Layout.fillHeight: true
                onToggleSidebarRequested: root.toggleSidebar()
                onShowSidebarRequested: root.showSidebar()
                onSftpOpenMessage: function(message, type) {
                    statusBar.showMessage(message, type)
                }
                onDatabaseOpenMessage: function(message, type) {
                    if (message !== "")
                        statusBar.showMessage(message, type)
                }

            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: !root.isIndependentMode

                PanelSideBar {
                    id: panelSideBar
                    objectName: "mainPanelSideBar"
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: root.sidebarVisible ? root.sidebarWidth : 0

                    // Keep the component alive at width 0 while collapsed so
                    // its view state survives snap and Ctrl+B toggles.
                    visible: true
                    enabled: root.sidebarVisible
                    opacity: root.sidebarVisible ? 1.0 : 0.0
                    clip: true
                    Accessible.ignored: !root.sidebarVisible

                    appMode: activityBar.appMode
                    hasActiveTabs: deviceTabs.tabCount > 0

                    onDevicesLoaded: function(devices) {
                        const rows = devices || []
                        const validIps = rows.map(function(d) { return d && d.ip ? d.ip : d })
                        deviceTabs.initializeTabs(validIps)
                        deviceTabs.updateDeviceMetadata(rows)
                    }
                    onDeviceSelected: (ip, name, deviceType, status) => deviceTabs.openTab(ip, name, deviceType, status)
                    onDeviceDeleted: (ip) => deviceTabs.closeTabByUid(ip)
                    onSettingSelected: function(key) {
                        root.activeSettingKey = key
                    }
                    onDatabaseTableSelected: function(tableName) {
                        root.activeDatabaseTable = tableName
                    }
                    onSyslogHostSelected: host => root.selectedSyslogHost = host
                    onSyslogOperationFinished: function(ok, message) {
                        statusBar.showMessage(message, ok ? "success" : "error")
                    }
                }

                Rectangle {
                    id: sidebarDivider
                    x: root.sidebarVisible ? root.sidebarWidth : 0
                    width: root.sidebarVisible ? Theme.splitHandleWidth : 0
                    height: parent.height
                    visible: root.sidebarVisible
                    color: Theme.contentBackground

                    Rectangle {
                        anchors.left: parent.left
                        width: 1
                        height: parent.height
                        color: Theme.borderColor
                    }

                    Rectangle {
                        anchors.left: parent.left
                        width: 2
                        height: parent.height
                        color: Theme.statusBarBackground
                        visible: sidebarResizeArea.containsMouse
                                 || sidebarResizeArea.pressed
                    }
                }

                ColumnLayout {
                    anchors.left: sidebarDivider.right
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    spacing: 0

                    DeviceTabs {
                        id: deviceTabs
                        Layout.fillWidth: true
                        Layout.preferredHeight: (tabCount > 0 && root.isDeviceMode) ? Theme.tabBarHeight : 0
                        visible: Layout.preferredHeight > 0
                        clip: true
                        activeContentLoading: contentArea.activeViewLoading

                        Behavior on Layout.preferredHeight {
                            NumberAnimation { duration: Theme.animationDurationSlow; easing.type: Easing.OutQuad }
                        }

                        onTabCountChanged: {
                            if (tabCount === 0) {
                                panelSideBar.selectedSection = -1
                                panelSideBar.selectedIndex = -1
                            }
                        }
                        onOpenNewDeviceRequested: {
                            if (!UiState.windowLock) {
                                UiState.windowLock = true
                                panelSideBar.openNewDeviceWindow()
                            }
                        }
                        onActiveTabChanged: function(uid) {
                            panelSideBar.selectDeviceByIp(uid)
                        }
                    }

                    FeatureBar {
                        id: featureBar
                        Layout.fillWidth: true
                        Layout.preferredHeight: Theme.featureBarHeight
                        visible: deviceTabs.tabCount > 0 && root.isDeviceMode
                        enabled: root.activeHostConfigEnabled
                        opacity: root.activeHostConfigEnabled ? 1.0 : 0.45

                        Behavior on Layout.preferredHeight { NumberAnimation { duration: Theme.animationDurationSlow; easing.type: Easing.OutQuad } }

                        activeMain: deviceTabs.currentFMain
                        activeText: deviceTabs.currentFText
                        deviceType: deviceTabs.activeDeviceType

                        onUserChangedFeature: function(mIdx, tIdx) {
                            deviceTabs.setFeatureForActiveTab(mIdx, tIdx)
                            Qt.callLater(function() {
                                contentArea.requestActivationReload("feature-bar")
                            })
                        }
                        onCliOpenRequested: root.openDeviceCli(deviceTabs.activeUid)
                    }

                    ContentArea {
                        id: contentArea
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: !root.isSyslogMode && !root.isSftpMode

                        tabCount: deviceTabs.tabCount
                        activeMainFeature: deviceTabs.currentFMain
                        activeTextFeature: deviceTabs.currentFText
                        currentHostIp: deviceTabs.activeUid
                        deviceRole: deviceTabs.activeDeviceType
                        appMode: activityBar.appMode
                        hostConfigEnabled: root.activeHostConfigEnabled
                        activeSettingKey: root.activeSettingKey
                        activeDatabaseTable: root.activeDatabaseTable
                    }

                    Loader {
                        id: syslogWorkspaceLoader
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        active: root.syslogWorkspaceLoaded
                        asynchronous: true
                        visible: root.isSyslogMode
                        sourceComponent: Component {
                            SyslogWorkspace {
                                selectedHost: root.selectedSyslogHost
                                onResetHostRequested: {
                                    root.selectedSyslogHost = ""
                                    panelSideBar.selectSyslogHost("")
                                }
                                onOperationMessage: function(ok, message) {
                                    statusBar.showMessage(message, ok ? "success" : "error")
                                }
                            }
                        }
                    }

                    Loader {
                        id: sftpWorkspaceLoader
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        active: root.isSftpMode
                        visible: active
                        sourceComponent: Component {
                            SftpView {
                                backend: typeof sftpController !== "undefined"
                                         ? sftpController : null
                            }
                        }
                    }
                }
            }
        }

        StatusBar {
            id: statusBar
            Layout.fillWidth: true
            Layout.preferredHeight: root.visibleStatusBarHeight
            visible: StatusBarState.isVisible

            unreadCount: root.unreadNotifications
            isDND: root.isDoNotDisturb
            isNotificationOpen: notificationPanel.visible
            pythonStatusText: panelSideBar.pythonDepsStatusText
            pythonStatusType: panelSideBar.pythonDepsStatus
            pythonStatusDetail: panelSideBar.pythonDepsStatusDetail
            pythonStatusBusy: panelSideBar.pythonDepsChecking

            onBellClicked: {
                if (notificationPanel.visible)
                    notificationPanel.close()
                else
                    notificationPanel.open()
            }
            onPythonStatusClicked: panelSideBar.triggerPythonCheck()

            function showMessage(msg, type) {
                root.recordNotification(msg, type !== undefined ? type : "info", true)
            }
        }
    }

    // A persistent grab area spans both visible and collapsed states. This
    // lets one drag gesture cross the snap threshold in either direction,
    // matching VS Code's SplitView behavior.
    MouseArea {
        id: sidebarResizeArea
        objectName: "sidebarResizeArea"
        x: activityBar.x + activityBar.width
           + (root.sidebarVisible ? root.sidebarWidth : 0) - width / 2
        y: activityBar.y
        width: 8
        height: activityBar.height
        z: 700
        visible: !root.isIndependentMode
        enabled: visible && !UiState.windowLock
        hoverEnabled: true
        cursorShape: Qt.SplitHCursor

        property real dragStartPointerX: 0
        property real dragStartSidebarWidth: 0
        property real dragDesiredSidebarWidth: 0

        function pointerSceneX(mouse) {
            const point = sidebarResizeArea.mapToItem(null, mouse.x, mouse.y)
            return point.x
        }

        onPressed: function(mouse) {
            dragStartPointerX = pointerSceneX(mouse)
            dragStartSidebarWidth = root.sidebarVisible ? root.sidebarWidth : 0
            dragDesiredSidebarWidth = dragStartSidebarWidth
            if (root.sidebarVisible)
                root.savedSidebarWidth = root.clampSidebarWidth(root.sidebarWidth)
        }

        onPositionChanged: function(mouse) {
            if (!pressed)
                return
            dragDesiredSidebarWidth = dragStartSidebarWidth
                                      + pointerSceneX(mouse) - dragStartPointerX
            root.applySidebarDragWidth(dragDesiredSidebarWidth)
        }

        onReleased: root.finishSidebarResize(dragDesiredSidebarWidth)
        onCanceled: root.finishSidebarResize(dragDesiredSidebarWidth)

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 2
            height: parent.height
            color: Theme.statusBarBackground
            visible: sidebarResizeArea.containsMouse || sidebarResizeArea.pressed
        }
    }

    Rectangle {
        id: modalWindowScrim
        anchors.fill: parent
        z: 800
        visible: UiState.windowLock && !root.active
        color: Theme.dialogOverlay
        opacity: visible ? 0.46 : 0.0

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.animationDurationFast
                easing.type: Easing.OutCubic
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }
    }
}
