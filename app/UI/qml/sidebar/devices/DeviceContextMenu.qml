pragma ComponentBehavior: Bound

import QtQuick
import UI

Rectangle {
    id: contextMenu

    // ── Thông tin thiết bị đang được right-click ──
    property string targetIp: ""
    property string targetStatus: ""
    property bool connectRunning: false
    property bool runningConfigRunning: false
    property string runningIp: ""
    property string runningConfigIp: ""
    readonly property bool canPing: targetStatus === "connected"
    readonly property bool isWaiting: targetStatus === "waiting"
    readonly property bool isConnected: targetStatus === "connected"
    readonly property bool isDisconnected: targetStatus === "disconnected"
    readonly property int menuWidth: 300
    readonly property color menuBorderColor: Theme.isHighContrast
                                             ? Theme.panelSideBarBorderColor
                                             : (Theme.isDarkMode ? Qt.rgba(1, 1, 1, 0.12)
                                                                 : Qt.rgba(31 / 255, 35 / 255, 40 / 255, 0.12))
    readonly property color menuDividerColor: Theme.isHighContrast
                                              ? Theme.panelSideBarBorderColor
                                              : (Theme.isDarkMode ? Qt.rgba(1, 1, 1, 0.14)
                                                                  : Qt.rgba(31 / 255, 35 / 255, 40 / 255, 0.14))
    readonly property color menuShadowColor: Theme.isDarkMode ? Qt.rgba(0, 0, 0, 0.24)
                                                              : Qt.rgba(31 / 255, 35 / 255, 40 / 255, 0.06)

    // ── Signals bắn ra ngoài khi người dùng chọn ──
    signal editRequested(string ip)
    signal deleteRequested(string ip)
    signal pingRequested(string ip)
    signal runningConfigRequested(string ip)
    signal upDevRequested(string ip)
    signal downDevRequested(string ip)
    signal connecRequested(string ip)
    signal reconnectRequested(string ip)
    signal cliRequested(string ip)

    // ── Hàm mở menu tại tọa độ cửa sổ ──
    function openAt(x, y, ip, status) {
        targetIp = ip
        targetStatus = status || ""

        // Ngăn menu bị tràn ra ngoài cạnh phải / dưới màn hình
        const win = Window.window
        if (win) {
            contextMenu.x = Math.min(x, win.width  - contextMenu.width  - 4)
            contextMenu.y = Math.min(y, win.height - contextMenu.height - 4)
        } else {
            contextMenu.x = x
            contextMenu.y = y
        }

        visible = true
    }

    function close() {
        visible = false
        targetIp = ""
        targetStatus = ""
    }

    // ── Giao diện ──
    visible: false
    width: menuWidth
    height: menuColumn.implicitHeight + 8
    z: 999  // Nổi trên tất cả

    color: Theme.panelSideBarSurface
    border.color: menuBorderColor
    border.width: Theme.borderWidth
    radius: 6

    // Đổ bóng nhẹ bằng một viền ngoài rất mờ để không tạo cảm giác hai lớp border.
    Rectangle {
        anchors.fill: parent
        anchors.margins: -2
        radius: parent.radius + 2
        color: "transparent"
        border.color: contextMenu.menuShadowColor
        border.width: Theme.borderWidth
        z: -1
    }

    // Đóng menu khi click ra ngoài
    Item {
        id: outsideClickCatcher
        parent: Window.window ? Window.window.contentItem : null
        anchors.fill: parent
        visible: contextMenu.visible
        z: 998

        TapHandler {
            onTapped: contextMenu.close()
        }
    }
    // lựa chọn khii chột phải
    Column {
        id: menuColumn
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 4
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        anchors.bottomMargin: 4
        spacing: 0

        ContextMenuItem {
            text: "Edit"
            shortcutText: "F2"
            iconSource: AppAssets.actionEdit
            onTriggered: {
                contextMenu.editRequested(contextMenu.targetIp)
                contextMenu.close()
            }
        }

        ContextMenuDivider {
            lineColor: contextMenu.menuDividerColor
        }

        ContextMenuItem {
            text: "Ping"
            enabled: contextMenu.canPing
            reserveIconSpace: true
            shortcutText: "Ctrl+Alt+P"
            onTriggered: {
                contextMenu.pingRequested(contextMenu.targetIp)
                contextMenu.close()
            }
        }

        ContextMenuItem {
            visible: contextMenu.isConnected
            enabled: !contextMenu.runningConfigRunning
            text: contextMenu.runningConfigRunning
                  ? (contextMenu.runningConfigIp !== "" ? "Get running-config (Running %1)".arg(contextMenu.runningConfigIp) : "Get running-config (Running...)")
                  : "Get running-config"
            iconSource: AppAssets.actionBackup
            reserveIconSpace: true
            onTriggered: {
                contextMenu.runningConfigRequested(contextMenu.targetIp)
                contextMenu.close()
            }
        }

        ContextMenuItem {
            visible: contextMenu.isConnected
            text: "Down (Dev)"
            shortcutText: "Ctrl+Alt+Down"
            iconSource: AppAssets.actionMonitorStop
            onTriggered: {
                contextMenu.downDevRequested(contextMenu.targetIp)
                contextMenu.close()
            }
        }

        ContextMenuItem {
            visible: contextMenu.isWaiting
            text: "Up (Dev)"
            shortcutText: "Ctrl+Alt+Up"
            iconSource: AppAssets.actionMonitorStart
            onTriggered: {
                contextMenu.upDevRequested(contextMenu.targetIp)
                contextMenu.close()
            }
        }

        ContextMenuItem {
            visible: contextMenu.isWaiting
            enabled: !contextMenu.connectRunning
            text: contextMenu.connectRunning
                  ? (contextMenu.runningIp !== "" ? "Connect (Running %1)".arg(contextMenu.runningIp) : "Connect (Running...)")
                  : "Connect"
            shortcutText: "Ctrl+Alt+C"
            onTriggered: {
                contextMenu.connecRequested(contextMenu.targetIp)
                contextMenu.close()
            }
        }

        ContextMenuItem {
            visible: contextMenu.isDisconnected
            text: "Reconnect"
            shortcutText: "Ctrl+Alt+R"
            iconSource: AppAssets.actionMonitorStart
            onTriggered: {
                contextMenu.reconnectRequested(contextMenu.targetIp)
                contextMenu.close()
            }
        }

        ContextMenuDivider {
            lineColor: contextMenu.menuDividerColor
        }

        ContextMenuItem {
            text: "CLI / SSH Client"
            shortcutText: "Ctrl+Alt+T"
            iconSource: AppAssets.navigationTerminal
            onTriggered: {
                contextMenu.cliRequested(contextMenu.targetIp)
                contextMenu.close()
            }
        }

        ContextMenuDivider {
            lineColor: contextMenu.menuDividerColor
        }

        ContextMenuItem {
            text: "Delete"
            shortcutText: "Del"
            iconSource: AppAssets.actionDelete
            danger: true
            onTriggered: {
                contextMenu.deleteRequested(contextMenu.targetIp)
                contextMenu.close()
            }
        }
    }

    // Animation mở ra mượt mà
    NumberAnimation on opacity {
        id: fadeIn
        running: contextMenu.visible
        from: 0.0; to: 1.0
        duration: Theme.animationDurationFast
        easing.type: Easing.OutQuad
    }

    NumberAnimation on scale {
        running: contextMenu.visible
        from: 0.95; to: 1.0
        duration: Theme.animationDurationFast
        easing.type: Easing.OutQuad
    }

    transformOrigin: Item.TopLeft
}
