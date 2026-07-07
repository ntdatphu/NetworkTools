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

    // ── Signals bắn ra ngoài khi người dùng chọn ──
    signal editRequested(string ip)
    signal deleteRequested(string ip)
    signal pingRequested(string ip)
    signal addYangcfgRequested(string ip)
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
    width: Theme.contextMenuWidth
    height: menuColumn.implicitHeight + 8
    z: 999  // Nổi trên tất cả

    color: Theme.panelSideBarSurface
    border.color: Theme.panelSideBarBorderColor
    border.width: Theme.borderWidth
    radius: 6

    // Đổ bóng nhẹ bằng cách vẽ 1 rectangle tối phía sau
    Rectangle {
        anchors.fill: parent
        anchors.margins: -1
        radius: parent.radius + 1
        color: "transparent"
        border.color: Theme.shadowColorLight
        border.width: 2
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
        anchors.bottomMargin: 4
        spacing: 2

        ContextMenuItem {
            text: "Edit"
            iconSource: AppAssets.resource("resources/sidebar/edit.svg")
            onTriggered: {
                contextMenu.editRequested(contextMenu.targetIp)
                contextMenu.close()
            }
        }

        ContextMenuDivider {}

        ContextMenuItem {
            text: "Ping"
            enabled: contextMenu.canPing
            reserveIconSpace: true
            onTriggered: {
                contextMenu.pingRequested(contextMenu.targetIp)
                contextMenu.close()
            }
        }

        ContextMenuItem {
            visible: contextMenu.isConnected
            text: "Add Yangcfg"
            onTriggered: {
                contextMenu.addYangcfgRequested(contextMenu.targetIp)
                contextMenu.close()
            }
        }

        ContextMenuDivider {
            visible: contextMenu.isConnected
        }

        ContextMenuItem {
            visible: contextMenu.isConnected
            text: "Down (Admin)"
            onTriggered: {
                contextMenu.downAdminRequested(contextMenu.targetIp)
                contextMenu.close()
            }
        }

        ContextMenuDivider {
            visible: contextMenu.isWaiting
        }

        ContextMenuItem {
            visible: contextMenu.isWaiting
            text: "Up (Admin)"
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
            onTriggered: {
                contextMenu.connecRequested(contextMenu.targetIp)
                contextMenu.close()
            }
        }

        ContextMenuItem {
            text: "Delete"
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
