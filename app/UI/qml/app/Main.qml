pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls.Basic
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

    // CỐT LÕI UX: Lưu lại kích thước cuối cùng để khi mở lại (Ctrl+B) nó không bị mất form
    property real savedSidebarWidth: Theme.sideBarWidth
    property real minSidebarWidth: 150

    readonly property bool isDeviceMode: activityBar.appMode === "devices"
    readonly property int visibleStatusBarHeight: StatusBarState.isVisible ? Theme.statusBarHeight : 0

    function attachPersistentSettingsBackends() {
        ThemeState.backend = typeof themeSettings !== "undefined" ? themeSettings : null
        StatusBarState.backend = typeof statusBarSettings !== "undefined" ? statusBarSettings : null
    }

    function setDoNotDisturb(enabled) {
        const nextState = enabled === true
        if (root.isDoNotDisturb === nextState)
            return
        root.isDoNotDisturb = nextState
        if (nextState) {
            // A loading toast would otherwise remain indefinitely after its
            // progress updates are suppressed by DND.
            toastManager.clearToasts()
            root.cliTaskToastId = -1
            root.dbTaskToastId = -1
        }
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
        if (showToast !== false && !root.isDoNotDisturb) {
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
        if (!root.isDoNotDisturb)
            setTaskToastId(source, toastManager.showTask(message))
    }

    function handleTaskProgress(source, message) {
        recordNotification(message, "loading", false)
        const uid = taskToastId(source)
        if (!root.isDoNotDisturb && (uid < 0 || !toastManager.updateToast(uid, message, "loading")))
            setTaskToastId(source, toastManager.showTask(message))
    }

    function handleTaskFinished(source, ok, message) {
        const type = ok ? "success" : "error"
        recordNotification(message, type, false)
        if (!root.isDoNotDisturb)
            toastManager.finishTask(taskToastId(source), message, ok)
        setTaskToastId(source, -1)
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

    Shortcut {
        sequence: "Ctrl+Alt+T"
        context: Qt.ApplicationShortcut
        onActivated: cli.openTerminal()
    }

    Shortcut {
        sequence: "Ctrl+B"
        onActivated: {
            root.sidebarVisible = !root.sidebarVisible
            if (root.sidebarVisible) {
                panelSideBar.SplitView.preferredWidth = root.savedSidebarWidth
            }
        }
    }

    Dialog {
        id: aboutDialog
        title: "About NetworkTools"
        modal: true
        standardButtons: Dialog.Ok
        Label {
            text: "NetworkTools v1.0\n\nDeveloped by Team 3TM\nPTIT - Ho Chi Minh City\n\nhttps://github.com/ntdatphu/NetworkTools/"
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

        onAboutToShow: root.unreadNotifications = 0
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
        anchors.fill: parent
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            ActivityBar {
                id: activityBar
                Layout.preferredWidth: Theme.activityBarWidth
                Layout.fillHeight: true
                onToggleSidebarRequested: {
                    root.sidebarVisible = !root.sidebarVisible
                    if (root.sidebarVisible) panelSideBar.SplitView.preferredWidth = root.savedSidebarWidth
                }
                onShowSidebarRequested: {
                    root.sidebarVisible = true
                    panelSideBar.SplitView.preferredWidth = root.savedSidebarWidth
                }
                onDatabaseOpenMessage: function(message, type) {
                    if (message !== "")
                        statusBar.showMessage(message, type)
                }

                // =========================================================
                // KHU VỰC KÉO MỞ (TỪ TRẠNG THÁI ẨN)
                // =========================================================
                MouseArea {
                    id: activityBarDragArea
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 8
                    cursorShape: Qt.SplitHCursor

                    // SỬA LỖI UX: Vùng kéo thả này CHỈ có mặt khi Sidebar đang bị ẩn.
                    // Nếu đang giữ chuột (pressed) thì giữ cho nó visible để không bị đứt drag.
                    visible: !root.sidebarVisible || pressed

                    property real startX: 0

                    onPressed: function(mouse) {
                        startX = mouse.x
                    }

                    onPositionChanged: function(mouse) {
                        if (pressed) {
                            let delta = mouse.x - startX
                            if (!root.sidebarVisible && delta > 10) {
                                root.sidebarVisible = true
                            }
                            if (root.sidebarVisible) {
                                panelSideBar.SplitView.preferredWidth = Math.min(Math.max(delta, 0), 600)
                            }
                        }
                    }

                    onReleased: {
                        if (root.sidebarVisible) {
                            if (panelSideBar.width < root.minSidebarWidth) {
                                root.sidebarVisible = false
                                panelSideBar.SplitView.preferredWidth = root.savedSidebarWidth
                            } else {
                                root.savedSidebarWidth = panelSideBar.width
                            }
                        }
                    }

                    Rectangle {
                        anchors.right: parent.right
                        width: 2
                        height: parent.height
                        color: Theme.statusBarBackground
                        visible: activityBarDragArea.containsMouse || activityBarDragArea.pressed
                    }
                }
            }

            SplitView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                orientation: Qt.Horizontal

                handle: Rectangle {
                    implicitWidth: Theme.splitHandleWidth
                    color: Theme.contentBackground

                    property bool isPressed: SplitHandle.pressed

                    HoverHandler {
                        id: handleHover
                        cursorShape: Qt.SplitHCursor
                    }

                    // =========================================================
                    // KHU VỰC ĐÓNG (TỪ TRẠNG THÁI MỞ)
                    // =========================================================
                    onIsPressedChanged: {
                        if (!isPressed) { // Khi vừa NHẢ CHUỘT ra
                            if (root.sidebarVisible) {
                                if (panelSideBar.width < root.minSidebarWidth) {
                                    root.sidebarVisible = false
                                    panelSideBar.SplitView.preferredWidth = root.savedSidebarWidth
                                } else {
                                    root.savedSidebarWidth = panelSideBar.width
                                }
                            }
                        }
                    }

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
                        visible: handleHover.hovered || SplitHandle.pressed
                    }
                }

                PanelSideBar {
                    id: panelSideBar
                    SplitView.preferredWidth: root.savedSidebarWidth
                    SplitView.minimumWidth: 0
                    SplitView.maximumWidth: 600

                    visible: root.sidebarVisible
                    clip: true

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
                }

                ColumnLayout {
                    SplitView.fillWidth: true
                    spacing: 0

                    DeviceTabs {
                        id: deviceTabs
                        Layout.fillWidth: true
                        Layout.preferredHeight: (tabCount > 0 && root.isDeviceMode) ? Theme.tabBarHeight : 0
                        visible: Layout.preferredHeight > 0
                        clip: true

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
                        }
                        onCliOpenRequested: {
                            statusBar.showMessage("Opened new Terminal", "info")
                            cli.openTerminal()
                        }
                    }

                    ContentArea {
                        id: contentArea
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        tabCount: deviceTabs.tabCount
                        activeMainFeature: deviceTabs.currentFMain
                        activeTextFeature: deviceTabs.currentFText
                        currentHostIp: deviceTabs.activeUid
                        appMode: activityBar.appMode
                        hostConfigEnabled: root.activeHostConfigEnabled
                        activeSettingKey: root.activeSettingKey
                        activeDatabaseTable: root.activeDatabaseTable
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
                root.unreadNotifications = 0
                notificationPanel.open()
            }
            onPythonStatusClicked: panelSideBar.triggerPythonCheck()

            function showMessage(msg, type) {
                root.recordNotification(msg, type !== undefined ? type : "info", true)
            }
        }
    }
}
