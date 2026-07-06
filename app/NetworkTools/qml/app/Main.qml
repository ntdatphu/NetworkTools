pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls.Basic
import NetworkTools

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
    property string activeSettingKey: "theme"
    property string activeLogsAlertsKey: "logs"

    // CỐT LÕI UX: Lưu lại kích thước cuối cùng để khi mở lại (Ctrl+B) nó không bị mất form
    property real savedSidebarWidth: Theme.sideBarWidth
    property real minSidebarWidth: 150

    readonly property bool isDeviceMode: activityBar.appMode === "devices"

    function attachPersistentSettingsBackends() {
        ThemeState.backend = typeof themeSettings !== "undefined" ? themeSettings : null
        StatusBarState.backend = typeof statusBarSettings !== "undefined" ? statusBarSettings : null
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
        title: qsTr("About NetworkTools")
        modal: true
        standardButtons: Dialog.Ok
        Label {
            text: qsTr("NetworkTools v1.0\n\nDeveloped by Team 3TM\nPTIT - Ho Chi Minh City\n\nhttps://github.com/ntdatphu/NetworkTools/")
        }
    }

    ToastManager {
        id: toastManager
    }

    Component.onCompleted: attachPersistentSettingsBackends()

    NotificationPanel {
        id: notificationPanel
        x: root.width - width - 12
        y: root.height - height - Theme.statusBarHeight - 8
        model: notificationHistoryModel

        onAboutToShow: root.unreadNotifications = 0
        onClearAllRequested: notificationHistoryModel.clear()
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

                    onDevicesLoaded: function(validIps) {
                        deviceTabs.initializeTabs(validIps)
                    }
                    onDeviceSelected: (ip, name) => deviceTabs.openTab(ip, name)
                    onDeviceDeleted: (ip) => deviceTabs.closeTabByUid(ip)
                    onSettingSelected: function(key) {
                        root.activeSettingKey = key
                    }
                    onLogsAlertsSelected: function(key) {
                        root.activeLogsAlertsKey = key
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
                        activeLogsAlertsKey: root.activeLogsAlertsKey
                    }
                }
            }
        }

        StatusBar {
            id: statusBar
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.statusBarHeight

            unreadCount: root.unreadNotifications
            isDND: root.isDoNotDisturb
            isNotificationOpen: notificationPanel.visible
            pythonStatusText: panelSideBar.pythonDepsStatusText
            pythonStatusType: panelSideBar.pythonDepsStatus
            pythonStatusDetail: panelSideBar.pythonDepsStatusDetail
            pythonStatusBusy: panelSideBar.pythonDepsChecking

            onBellClicked: notificationPanel.open()
            onPythonStatusClicked: panelSideBar.triggerPythonCheck()

            function showMessage(msg, type) {
                const timestamp = new Date().toLocaleTimeString(Qt.locale(), "HH:mm:ss")
                notificationHistoryModel.insert(0, {
                    "msgText": msg,
                    "msgType": type !== undefined ? type : "info",
                    "timestamp": timestamp
                })
                root.unreadNotifications++
                if (!root.isDoNotDisturb) {
                    toastManager.showToast(msg, type)
                }
            }
        }
    }
}
