pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls.Basic
import QtCore
import Qt.labs.platform as NativeMenus
import NetworkTools

StatefulWindow {
    id: root
    visible: true
    title: "NetworkTools"

    // ── Trạng thái sidebar ────────────────────────────────────
    property bool sidebarVisible: true

    // Lưu lại width trước khi collapse để restore đúng vị trí
    property int lastSidebarWidth: Theme.sideBarWidth

    // ── Quản lý thông báo toàn cục ────────────────────────────
    property int unreadNotifications: 0
    property bool isDoNotDisturb: false

    readonly property bool isDeviceMode: activityBar.appMode === "devices"

    ListModel {
        id: notificationHistoryModel
    }

    readonly property bool activeHostConfigEnabled: {
        if (deviceTabs.activeUid === "")
            return false

        for (let i = 0; i < panelSideBar.allDevices.length; i++) {
            const dev = panelSideBar.allDevices[i]
            if (dev.ip === deviceTabs.activeUid)
                return dev.status !== "waiting"
        }

        return true
    }

    // ── Hàm toggle sidebar ────────────────────────────────────
    function toggleSidebar() {
        if (sidebarVisible) {
            // Lưu width hiện tại trước khi ẩn
            if (mainSplitView.width > 0) {
                lastSidebarWidth = Math.max(
                    Theme.sideBarMinWidth,
                    panelSideBar.width
                )
            }
            sidebarVisible = false
        } else {
            sidebarVisible = true
            // Restore về width đã lưu
            Qt.callLater(function() {
                panelSideBar.SplitView.preferredWidth = lastSidebarWidth
            })
        }
    }

    // ── Native Menu Bar ───────────────────────────────────────
    AppMenuBar {
        id: appMenuBar

        sidebarVisible: root.sidebarVisible

        onNewDeviceRequested: {
            if (!Theme.windowLock) {
                Theme.windowLock = true
                panelSideBar.openNewDeviceWindow()
            }
        }

        onNewDeviceBatchRequested: {
            if (!Theme.windowLock) {
                Theme.windowLock = true
                panelSideBar.openBatchDeviceWindow()
            }
        }

        onRefreshDevicesRequested: {
            panelSideBar.reloadDevices()
            statusBar.showMessage("Device list refreshed.", "info")
        }

        onToggleSidebarRequested: {
            root.toggleSidebar()
        }

        onOpenTerminalRequested: {
            cli.openTerminal()
        }

        onShowAboutRequested: {
            aboutDialog.open()
        }
    }

    Shortcut {
        sequence: "Ctrl+Alt+T"
        context: Qt.ApplicationShortcut
        onActivated: cli.openTerminal()
    }

    Shortcut {
        sequence: "Ctrl+B"
        onActivated: root.toggleSidebar()
    }

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
                isPythonCheckRunning: panelSideBar.pythonDepsChecking

                // ── Toggle sidebar khi click item đang active ──
                onToggleSidebarRequested: root.toggleSidebar()
            }

            Connections {
                target: activityBar
                function onRetryPythonCheckClicked() {
                    panelSideBar.triggerPythonCheck()
                }
            }

            // ── SplitView với CollapseHandle ──────────────────
            SplitView {
                id: mainSplitView
                Layout.fillWidth: true
                Layout.fillHeight: true
                orientation: Qt.Horizontal

                // ── Handle dùng CollapseHandle thay vì Rectangle ──
                handle: CollapseHandle {
                    collapsed: !root.sidebarVisible && root.isDeviceMode
                    collapseDirection: "left"
                    vertical: true
                    onExpandRequested: root.toggleSidebar()
                }

                // ── Bên trái: Sidebar ─────────────────────────
                PanelSideBar {
                    id: panelSideBar

                    SplitView.preferredWidth: root.sidebarVisible
                                                  ? root.lastSidebarWidth
                                                  : 0
                    SplitView.minimumWidth:   root.sidebarVisible
                                                  ? Theme.sideBarMinWidth
                                                  : 0
                    SplitView.maximumWidth:   600

                    // Ẩn/hiện theo sidebarVisible và chỉ hiện ở device mode
                    visible: root.sidebarVisible && root.isDeviceMode

                    hasActiveTabs: deviceTabs.tabCount > 0

                    // Theo dõi khi người dùng kéo sidebar
                    // Nếu kéo nhỏ hơn collapseWidth → collapse luôn
                    onWidthChanged: {
                        if (root.sidebarVisible
                                && width > 0
                                && width < Theme.sideBarCollapseWidth) {
                            root.lastSidebarWidth = Theme.sideBarMinWidth
                            root.sidebarVisible = false
                        } else if (width >= Theme.sideBarMinWidth) {
                            // Lưu width hợp lệ gần nhất
                            root.lastSidebarWidth = width
                        }
                    }

                    onDevicesLoaded: function(validIps) {
                        deviceTabs.initializeTabs(validIps)
                    }

                    onDeviceSelected: (ip, name) => deviceTabs.openTab(ip, name)
                    onDeviceDeleted:  (ip)        => deviceTabs.closeTabByUid(ip)

                    onOpenEditorSelected: function(uid) {
                        deviceTabs.openTabByUid(uid)
                    }

                    onOpenEditorCloseRequested: function(uid) {
                        deviceTabs.closeTabByUid(uid)
                    }

                    Connections {
                        target: deviceTabs

                        function onTabCountChanged() {
                            if (deviceTabs.tabCount === 0) {
                                panelSideBar.selectedSection = -1
                                panelSideBar.selectedIndex   = -1
                            }
                        }

                        function onOpenNewDeviceRequested() {
                            if (!Theme.windowLock) {
                                Theme.windowLock = true
                                panelSideBar.openNewDeviceWindow()
                            }
                        }

                        function onActiveTabChanged(uid) {
                            panelSideBar.selectDeviceByIp(uid)
                        }
                    }

                    // Binding snapshot — tự cập nhật khi tabModel thay đổi
                    openEditorItems: deviceTabs.tabCount >= 0
                                         ? deviceTabs.buildOpenEditorSnapshot()
                                         : []
                }

                // ── Bên phải: Nội dung chính ──────────────────
                ColumnLayout {
                    SplitView.fillWidth: true
                    spacing: 0

                    DeviceTabs {
                        id: deviceTabs
                        Layout.fillWidth: true
                        Layout.preferredHeight: (tabCount > 0 && root.isDeviceMode)
                                                    ? Theme.tabBarHeight
                                                    : 0
                        visible: Layout.preferredHeight > 0
                        clip: true

                        Behavior on Layout.preferredHeight {
                            NumberAnimation {
                                duration: Theme.animationDurationSlow
                                easing.type: Easing.OutQuad
                            }
                        }
                    }

                    FeatureBar {
                        id: featureBar
                        Layout.fillWidth: true
                        Layout.preferredHeight: Theme.featureBarHeight
                        visible: deviceTabs.tabCount > 0 && root.isDeviceMode
                        enabled: root.activeHostConfigEnabled
                        opacity: root.activeHostConfigEnabled ? 1.0 : 0.45

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.animationDurationMedium
                                easing.type: Easing.OutQuad
                            }
                        }

                        Behavior on Layout.preferredHeight {
                            NumberAnimation {
                                duration: Theme.animationDurationSlow
                                easing.type: Easing.OutQuad
                            }
                        }

                        activeMain: deviceTabs.currentFMain
                        activeText: deviceTabs.currentFText

                        onUserChangedFeature: function(mIdx, tIdx) {
                            deviceTabs.setFeatureForActiveTab(mIdx, tIdx)
                        }
                    }

                    ContentArea {
                        id: contentArea
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        tabCount:          deviceTabs.tabCount
                        activeTextFeature: deviceTabs.currentFText
                        currentHostIp:     deviceTabs.activeUid
                        appMode:           activityBar.appMode
                        hostConfigEnabled: root.activeHostConfigEnabled
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

            onBellClicked: {
                notificationPanel.open()
            }

            function showMessage(msg, type) {
                const timestamp = new Date().toLocaleTimeString(
                    Qt.locale(), "HH:mm:ss"
                )

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

    ToastManager {
        id: toastManager
    }

    NotificationPanel {
        id: notificationPanel

        x: root.width - width - 12
        y: root.height - height - Theme.statusBarHeight - 8

        model: notificationHistoryModel

        onAboutToShow: {
            root.unreadNotifications = 0
        }

        onClearAllRequested: {
            notificationHistoryModel.clear()
        }
    }

    // ── About Dialog ──────────────────────────────────────────
    NativeMenus.MessageDialog {
        id: aboutDialog
        title:   qsTr("About NetworkTools")
        text:    qsTr("NetworkTools v1.0\n\nDeveloped by Team 3TM\nPTIT — Ho Chi Minh City\n\nhttps://github.com/Cherster0606/NCKH/")
        buttons: NativeMenus.MessageDialog.Ok
    }
}