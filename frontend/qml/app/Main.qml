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

    // =====================================================================
    // 1. PROPERTIES (Trạng thái và Cờ điều khiển)
    // =====================================================================
    property bool sidebarVisible: true
    property int unreadNotifications: 0
    property bool isDoNotDisturb: false
    readonly property bool isDeviceMode: activityBar.appMode === "devices"

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
        onActivated: root.sidebarVisible = !root.sidebarVisible
    }

    NativeMenus.MessageDialog {
        id: aboutDialog
        title: qsTr("About NetworkTools")
        text: qsTr("NetworkTools v1.0\n\nDeveloped by Team 3TM\nPTIT — Ho Chi Minh City\n\nhttps://github.com/ntdatphu/NetworkTools/")
        buttons: NativeMenus.MessageDialog.Ok
    }

    ToastManager {
        id: toastManager
    }

    NotificationPanel {
        id: notificationPanel
        x: root.width - width - 12
        y: root.height - height - Theme.statusBarHeight - 8
        model: notificationHistoryModel

        onAboutToShow: root.unreadNotifications = 0
        onClearAllRequested: notificationHistoryModel.clear()
    }

    // =====================================================================
    // 3. MENU BAR
    // =====================================================================
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
        onToggleSidebarRequested: root.sidebarVisible = !root.sidebarVisible
        onOpenTerminalRequested: cli.openTerminal()
        onShowAboutRequested: aboutDialog.open()
    }

    // =====================================================================
    // 4. MAIN UI LAYOUT
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
                isPythonCheckRunning: panelSideBar.pythonDepsChecking

                onRetryPythonCheckClicked: panelSideBar.triggerPythonCheck()
                onToggleSidebarRequested: root.sidebarVisible = !root.sidebarVisible
                onShowSidebarRequested: root.sidebarVisible = true

                MouseArea {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 12
                    cursorShape: Qt.SplitHCursor
                    enabled: !root.sidebarVisible
                    hoverEnabled: !root.sidebarVisible

                    property real startX: 0

                    onPressed: function(mouse) {
                        startX = mouse.x
                    }

                    onPositionChanged: function(mouse) {
                        if (pressed) {
                            let delta = mouse.x - startX
                            if (delta > 20) { // Yêu cầu kéo ra 1 khoảng để tránh trigger nhầm
                                root.sidebarVisible = true
                                panelSideBar.SplitView.preferredWidth = Math.max(delta, Theme.sideBarWidth)
                            }
                        }
                    }

                    // Viền sáng lên khi hover, đồng nhất UI với handle của SplitView
                    Rectangle {
                        anchors.right: parent.right
                        width: 2
                        height: parent.height
                        color: Theme.statusBarBackground
                        opacity: parent.containsMouse ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 100 } }
                    }
                }
            }

            SplitView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                orientation: Qt.Horizontal

                handle: Rectangle {
                    implicitWidth: 6
                    color: Theme.sideBarBackground

                    // ÉP BUỘC CẢM BIẾN HOVER VÀ ĐỔI HÌNH CON TRỎ CHUỘT
                    HoverHandler {
                        id: handleHover
                        cursorShape: Qt.SplitHCursor
                    }

                    // VIỀN MẶC ĐỊNH LÚC BÌNH THƯỜNG
                    Rectangle {
                        anchors.right: parent.right
                        width: 1
                        height: parent.height
                        color: Theme.borderColor
                    }

                    // VIỀN SÁNG LÊN KHI HOVER HOẶC KÉO THẢ
                    Rectangle {
                        anchors.right: parent.right
                        width: 2
                        height: parent.height
                        color: Theme.statusBarBackground
                        opacity: handleHover.hovered || SplitHandle.pressed ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 100 } }
                    }
                }

                PanelSideBar {
                    id: panelSideBar
                    SplitView.preferredWidth: Theme.sideBarWidth
                    SplitView.minimumWidth: 0
                    clip: true
                    onWidthChanged: {
                        if (root.sidebarVisible && width > 0 && width < 200) {
                            root.sidebarVisible = false

                            // Trả lại kích thước chuẩn để lần sau click mở lên Sidebar không bị teo nhỏ
                            SplitView.preferredWidth = Theme.sideBarWidth
                        }
                    }
                    SplitView.maximumWidth: 600

                    visible: root.sidebarVisible
                    appMode: activityBar.appMode
                    hasActiveTabs: deviceTabs.tabCount > 0

                    onDevicesLoaded: function(validIps) {
                        deviceTabs.initializeTabs(validIps)
                    }
                    onDeviceSelected: (ip, name) => deviceTabs.openTab(ip, name)
                    onDeviceDeleted: (ip) => deviceTabs.closeTabByUid(ip)
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

                        // Đưa các logic trước đây nằm trong Connections về đúng Component của nó
                        onTabCountChanged: {
                            if (tabCount === 0) {
                                panelSideBar.selectedSection = -1
                                panelSideBar.selectedIndex = -1
                            }
                        }
                        onOpenNewDeviceRequested: {
                            if (!Theme.windowLock) {
                                Theme.windowLock = true
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

                        tabCount: deviceTabs.tabCount
                        activeTextFeature: deviceTabs.currentFText
                        currentHostIp: deviceTabs.activeUid
                        appMode: activityBar.appMode
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

            onBellClicked: notificationPanel.open()

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