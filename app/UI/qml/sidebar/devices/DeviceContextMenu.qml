pragma ComponentBehavior: Bound

import QtQuick
import UI

Rectangle {
    id: contextMenu

    // ── Thông tin thiết bị đang được right-click ──
    property string targetIp: ""
    property string targetStatus: ""
    property bool connectRunning: false
    property string runningIp: ""
    readonly property bool canPing: targetStatus === "connected"
    readonly property bool isWaiting: targetStatus === "waiting"
    readonly property bool isConnected: targetStatus === "connected"
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
    signal upAdminRequested(string ip)
    signal downAdminRequested(string ip)
    signal connecRequested(string ip)

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
            iconSource: AppAssets.resource("resources/sidebar/edit.svg")
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
            text: "Down (Admin)"
            shortcutText: "Ctrl+Alt+Down"
            onTriggered: {
                contextMenu.downAdminRequested(contextMenu.targetIp)
                contextMenu.close()
            }
        }

        ContextMenuItem {
            visible: contextMenu.isWaiting
            text: "Up (Admin)"
            shortcutText: "Ctrl+Alt+Up"
            onTriggered: {
                contextMenu.upAdminRequested(contextMenu.targetIp)
                contextMenu.close()
            }
        }

        ContextMenuItem {
            visible: contextMenu.isWaiting
            enabled: !contextMenu.connectRunning
            text: contextMenu.connectRunning
                  ? (contextMenu.runningIp !== "" ? "Connect (Running " + contextMenu.runningIp + ")" : "Connect (Running...)")
                  : "Connect"
            shortcutText: "Ctrl+Alt+C"
            onTriggered: {
                contextMenu.connecRequested(contextMenu.targetIp)
                contextMenu.close()
            }
        }

        ContextMenuDivider {
            lineColor: contextMenu.menuDividerColor
        }

        ContextMenuItem {
            text: "Delete"
            shortcutText: "Del"
            iconSource: AppAssets.resource("resources/sidebar/delete.svg")
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
