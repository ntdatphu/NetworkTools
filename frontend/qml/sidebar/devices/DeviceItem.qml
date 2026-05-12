pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import NetworkTools

Rectangle {
    id: deviceItem

    required property int index
    required property var modelData

    property string deviceName: ""
    property string deviceIp:   ""
    property string deviceType: ""
    property bool isSelected:   false
    property string displayFormat: "name"
    property string status: "connected"

    readonly property bool blockedByStatus: status === "waiting"

    // ── Logic hiển thị text ───────────────────────────────────────────────────
    property string displayText: {
        const safeName = deviceName.trim() !== "" ? deviceName : deviceIp
        if (displayFormat === "ip")   return deviceIp
        if (displayFormat === "both") return safeName + " (" + deviceIp + ")"
        return safeName
    }

    // ── Logic icon ────────────────────────────────────────────────────────────
    // "unknown" hoặc "" → không có icon → hiển thị dot
    property string iconSource: {
        if (deviceType === "router")
            return "qrc:/qt/qml/NetworkTools/resources/sidebar/router.svg"
        if (deviceType === "sw2" || deviceType === "sw3")
            return "qrc:/qt/qml/NetworkTools/resources/sidebar/switch.svg"
        return ""   // unknown / chưa xác định → dot
    }

    // ── Logic màu status ──────────────────────────────────────────────────────
    property color statusColor: {
        if (status === "connected")    return Theme.statusConnected
        if (status === "waiting")      return Theme.statusWaiting
        return Theme.statusDisconnected
    }

    // ── Màu dot riêng cho unknown ─────────────────────────────────────────────
    // Unknown device dùng màu muted hơn để phân biệt với disconnected
    property color dotColor: {
        if (deviceType === "" || deviceType === "unknown")
            return Theme.textDisabled      // Xám nhạt — chưa xác định
        return statusColor
    }

    ToolTip.visible: itemHover.hovered
    ToolTip.text:    deviceIp + (deviceType !== "" && deviceType !== "unknown"
                                     ? "  ·  " + deviceType
                                     : "  ·  unknown")
    ToolTip.delay:   400

    width:   parent.width
    height:  Theme.listItemHeight
    opacity: blockedByStatus ? 0.45 : 1.0

    Behavior on opacity {
        NumberAnimation { duration: Theme.animationDurationMedium }
    }

    color: isSelected        ? Theme.sideBarItemSelected :
           itemHover.hovered ? Theme.sideBarItemHover    : "transparent"

    signal clicked()
    signal rightClicked(string ip, int mouseX, int mouseY)

    // ── Active border bên trái ────────────────────────────────────────────────
    Rectangle {
        width:  3
        height: parent.height
        anchors.left: parent.left
        color:   Theme.accentColor
        opacity: isSelected ? 1.0 : 0.0
        Behavior on opacity {
            NumberAnimation { duration: Theme.animationDurationMedium }
        }
    }

    // ── Icon / Status dot ─────────────────────────────────────────────────────
    Item {
        id: iconContainer
        anchors.left:           parent.left
        anchors.leftMargin:     16
        anchors.verticalCenter: parent.verticalCenter
        width:  16
        height: 16

        // Icon SVG — chỉ hiện khi có iconSource
        Button {
            visible:          deviceItem.iconSource !== ""
            anchors.centerIn: parent
            width:  16; height: 16
            padding: 0
            icon.source: deviceItem.iconSource
            icon.width:  16; icon.height: 16
            icon.color:  deviceItem.statusColor
            background:  Item {}
            enabled:     false
        }

        // Dot — hiện khi không có icon (unknown/rỗng)
        Rectangle {
            visible:          deviceItem.iconSource === ""
            anchors.centerIn: parent
            width:  8; height: 8
            radius: 4
            color:  deviceItem.dotColor

            Behavior on color {
                ColorAnimation { duration: Theme.animationDurationMedium }
            }

            // Dot của unknown có thêm border nhạt để phân biệt
            border.color: deviceItem.deviceType === ""
                          || deviceItem.deviceType === "unknown"
                              ? Theme.borderColor
                              : "transparent"
            border.width: 1
        }
    }

    // ── Text ─────────────────────────────────────────────────────────────────
    Text {
        anchors.left:           iconContainer.right
        anchors.leftMargin:     10
        anchors.verticalCenter: parent.verticalCenter
        anchors.right:          parent.right
        anchors.rightMargin:    8

        text:           deviceItem.displayText
        color:          isSelected ? Theme.textPrimary : Theme.textSecondary
        font.pixelSize: Theme.fontSizeNormal
        font.family:    Theme.fontFamily
        elide:          Text.ElideRight
    }

    HoverHandler { id: itemHover }

    TapHandler {
        enabled:         !deviceItem.blockedByStatus
        acceptedButtons: Qt.LeftButton
        onTapped:        deviceItem.clicked()
    }

    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: (eventPoint) => {
            const globalPos = deviceItem.mapToItem(
                null,
                eventPoint.position.x,
                eventPoint.position.y
            )
            deviceItem.rightClicked(deviceIp, globalPos.x, globalPos.y)
        }
    }
}