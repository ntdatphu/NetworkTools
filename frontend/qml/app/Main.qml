pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls.Basic
import QtCore
import Qt.labs.platform as NativeMenus
import NetworkUI

StatefulWindow {
    id: root
    visible: true
    title: "NetworkTools"

    // ── Trạng thái sidebar ────────────────────────────────────
    property bool sidebarVisible: true

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
            root.sidebarVisible = !root.sidebarVisible
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
        onActivated: root.sidebarVisible = !root.sidebarVisible
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
            }

            Connections {
                target: activityBar
                function onRetryPythonCheckClicked() {
                    panelSideBar.triggerPythonCheck()
                }
            }

            // ── BỘ CHIA GIAO DIỆN CHUYÊN NGHIỆP (THAY THẾ CHỖ NÀY) ──
            SplitView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                orientation: Qt.Horizontal

                // 1. Tùy chỉnh thanh kéo (Handle) chuẩn VS Code
                handle: Rectangle {
                    implicitWidth: 4 // Vùng nhạy chuột rộng 4px

                    // Đổi màu thông minh: Đang kéo -> Màu nhấn. Chỉ trỏ chuột -> Màu viền. Bình thường -> Trong suốt
                    color: SplitHandle.pressed ? Theme.accentColor :
                           SplitHandle.hovered ? Theme.borderColor : "transparent"
                }

                // 2. Bên trái: Sidebar
                PanelSideBar {
                    id: panelSideBar

                    // Dùng thuộc tính của SplitView thay vì Layout
                    SplitView.preferredWidth: Theme.sideBarWidth
                    SplitView.minimumWidth: 200 // Không cho kéo nhỏ hơn 200px
                    SplitView.maximumWidth: 600 // Không cho kéo to hơn 600px

                    visible: root.sidebarVisible && root.isDeviceMode
                    hasActiveTabs: deviceTabs.tabCount > 0

                    onDevicesLoaded: function(validIps) {
                        deviceTabs.initializeTabs(validIps)
                    }

                    onDeviceSelected: (ip, name) => deviceTabs.openTab(ip, name)
                    onDeviceDeleted:  (ip)        => deviceTabs.closeTabByUid(ip)

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
                }

                // 3. Bên phải: Nội dung chính
                ColumnLayout {
                    // Yêu cầu chiếm toàn bộ phần diện tích còn lại
                    SplitView.fillWidth: true
                    spacing: 0

                    DeviceTabs {
                        id: deviceTabs
                        Layout.fillWidth: true
                        Layout.preferredHeight: (tabCount > 0 && root.isDeviceMode) ? Theme.tabBarHeight : 0
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

                        Behavior on opacity { NumberAnimation { duration: Theme.animationDurationMedium; easing.type: Easing.OutQuad } }
                        Behavior on Layout.preferredHeight { NumberAnimation { duration: Theme.animationDurationSlow; easing.type: Easing.OutQuad } }

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

                        tabCount:         deviceTabs.tabCount
                        activeTextFeature: deviceTabs.currentFText
                        currentHostIp:    deviceTabs.activeUid
                        appMode:          activityBar.appMode
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
        title:   qsTr("About NetworkUI")
        text:    qsTr("Network Tools v1.0\n\nDeveloped by Team 3TM\nPTIT — Ho Chi Minh City\n\nhttps://github.com/Cherster0606/NCKH/")
        buttons: NativeMenus.MessageDialog.Ok
    }
}