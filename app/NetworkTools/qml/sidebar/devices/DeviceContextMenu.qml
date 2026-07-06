pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import NetworkTools

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

        // ── Item: Edit ──
        Rectangle {
            id: editItem
            width: parent.width
            height: 32

            color: editHover.hovered ? Theme.panelSideBarItemHover : "transparent"
            radius: 4

            // Canh lề trái đồng đều
            anchors.leftMargin: 4
            anchors.rightMargin: 4

            Row {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 12
                spacing: 10

                // Icon bút chì
                Button {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 14; height: 14; padding: 0
                    icon.source: AppAssets.resource("resources/sidebar/edit.svg")
                    icon.width: 14; icon.height: 14
                    icon.color: editHover.hovered ? Theme.panelSideBarTextPrimary : Theme.panelSideBarTextSecondary
                    background: Item {}
                    enabled: false
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Edit"
                    font.pixelSize: Theme.fontSizeNormal
                    font.family: Theme.fontFamily
                    color: editHover.hovered ? Theme.panelSideBarTextPrimary : Theme.panelSideBarTextSecondary
                }
            }

            HoverHandler { id: editHover }
            TapHandler {
                onTapped: {
                    contextMenu.editRequested(contextMenu.targetIp)
                    contextMenu.close()
                }
            }
        }

        // ── Divider ──
        Rectangle {

            width: parent.width - 16
            height: 1
            anchors.horizontalCenter: parent.horizontalCenter
            color: Theme.panelSideBarBorderColor
        }

        Rectangle {
            id: pingItem
            width: parent.width
            height: 32
            opacity: contextMenu.canPing ? 1.0 : 0.45

            color: pingHover.hovered ? Theme.panelSideBarItemHover : "transparent"
            radius: 4

            Row {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 12
                spacing: 10

                Button {
                    width: 14; height: 14; padding: 0
                    // icon.source: AppAssets.resource("resources/sidebar/ping.svg") // icon tùy bạn
                    icon.width: 14; icon.height: 14
                    icon.color: pingHover.hovered ? Theme.panelSideBarTextPrimary : Theme.panelSideBarTextSecondary
                    background: Item {}
                    enabled: false
                }

                Text {
                    text: "Ping"
                    font.pixelSize: Theme.fontSizeNormal
                    font.family: Theme.fontFamily
                    color: pingHover.hovered ? Theme.panelSideBarTextPrimary : Theme.panelSideBarTextSecondary
                }
            }

            HoverHandler { id: pingHover }

            TapHandler {
                enabled: contextMenu.canPing
                onTapped: {
                    contextMenu.pingRequested(contextMenu.targetIp)
                    contextMenu.close()
                }
            }
        }

        Rectangle {
            id: addYangcfgItem
            visible: contextMenu.isConnected
            width: parent.width
            height: 32
            color: addYangcfgHover.hovered ? Theme.panelSideBarItemHover : "transparent"
            radius: 4

            Row {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 12
                spacing: 10

                Text {
                    text: "Add Yangcfg"
                    font.pixelSize: Theme.fontSizeNormal
                    font.family: Theme.fontFamily
                    color: addYangcfgHover.hovered ? Theme.panelSideBarTextPrimary : Theme.panelSideBarTextSecondary
                }
            }

            HoverHandler { id: addYangcfgHover }
            TapHandler {
                onTapped: {
                    contextMenu.addYangcfgRequested(contextMenu.targetIp)
                    contextMenu.close()
                }
            }
        }

        Rectangle {
            visible: contextMenu.isConnected
            width: parent.width - 16
            height: 1
            anchors.horizontalCenter: parent.horizontalCenter
            color: Theme.panelSideBarBorderColor
        }

        Rectangle {
            id: downAdminItem
            visible: contextMenu.isConnected
            width: parent.width
            height: 32
            color: downAdminHover.hovered ? Theme.panelSideBarItemHover : "transparent"
            radius: 4

            Row {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 12
                spacing: 10

                Text {
                    text: "Down (Admin)"
                    font.pixelSize: Theme.fontSizeNormal
                    font.family: Theme.fontFamily
                    color: downAdminHover.hovered ? Theme.panelSideBarTextPrimary : Theme.panelSideBarTextSecondary
                }
            }

            HoverHandler { id: downAdminHover }
            TapHandler {
                onTapped: {
                    contextMenu.downAdminRequested(contextMenu.targetIp)
                    contextMenu.close()
                }
            }
        }

        Rectangle {
            visible: contextMenu.isWaiting
            width: parent.width - 16
            height: 1
            anchors.horizontalCenter: parent.horizontalCenter
            color: Theme.panelSideBarBorderColor
        }

        Rectangle {
            id: upAdminItem
            visible: contextMenu.isWaiting
            width: parent.width
            height: 32
            color: upAdminHover.hovered ? Theme.panelSideBarItemHover : "transparent"
            radius: 4

            Row {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 12
                spacing: 10

                Text {
                    text: "Up (Admin)"
                    font.pixelSize: Theme.fontSizeNormal
                    font.family: Theme.fontFamily
                    color: upAdminHover.hovered ? Theme.panelSideBarTextPrimary : Theme.panelSideBarTextSecondary
                }
            }

            HoverHandler { id: upAdminHover }
            TapHandler {
                onTapped: {
                    contextMenu.upAdminRequested(contextMenu.targetIp)
                    contextMenu.close()
                }
            }
        }

        Rectangle {
            id: connecItem
            visible: contextMenu.isWaiting
            width: parent.width
            height: 32
            opacity: contextMenu.connectRunning ? 0.5 : 1.0
            color: connecHover.hovered ? Theme.panelSideBarItemHover : "transparent"
            radius: 4

            Row {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 12
                spacing: 10

                Text {
                    text: contextMenu.connectRunning
                          ? (contextMenu.runningIp !== "" ? "Connect (Running " + contextMenu.runningIp + ")" : "Connect (Running...)")
                          : "Connect"
                    font.pixelSize: Theme.fontSizeNormal
                    font.family: Theme.fontFamily
                    color: connecHover.hovered ? Theme.panelSideBarTextPrimary : Theme.panelSideBarTextSecondary
                }
            }

            HoverHandler { id: connecHover }
            TapHandler {
                enabled: !contextMenu.connectRunning
                onTapped: {
                    contextMenu.connecRequested(contextMenu.targetIp)
                    contextMenu.close()
                }
            }
        }

        // ── Item: Delete ──
        Rectangle {
            id: deleteItem
            width: parent.width
            height: 32
            color: deleteHover.hovered ? Theme.alertErrorSubtle : "transparent"
            radius: 4

            Row {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 12
                spacing: 10

                // Icon thùng rác
                Button {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 14; height: 14; padding: 0
                    icon.source: AppAssets.resource("resources/sidebar/delete.svg")
                    icon.width: 14; icon.height: 14
                    icon.color: deleteHover.hovered ? Theme.alertError : Theme.panelSideBarTextSecondary
                    background: Item {}
                    enabled: false
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Delete"
                    font.pixelSize: Theme.fontSizeNormal
                    font.family: Theme.fontFamily
                    color: deleteHover.hovered ? Theme.alertError : Theme.panelSideBarTextSecondary
                }
            }

            HoverHandler { id: deleteHover }
            TapHandler {
                onTapped: {
                    contextMenu.deleteRequested(contextMenu.targetIp)
                    contextMenu.close()
                }
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
