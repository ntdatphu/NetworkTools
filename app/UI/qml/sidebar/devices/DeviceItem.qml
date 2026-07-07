pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import UI

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
    function isDomainLike(value) {
        const text = String(value || "").trim()
        return /^(?=.{1,253}$)(?!-)(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,}$/i.test(text)
    }

    function preferredHostLabel() {
        const name = String(deviceName || "").trim()
        const ip = String(deviceIp || "").trim()

        if (isDomainLike(name))
            return name
        if (isDomainLike(ip))
            return ip
        return ip !== "" ? ip : name
    }

    property string displayText: {
        if (displayFormat === "ip")
            return deviceIp
        return preferredHostLabel()
    }

    // ── Logic icon ────────────────────────────────────────────────────────────
    // "unknown" hoặc "" → không có icon → hiển thị dot
    property string iconSource: {
        if (deviceType === "router")
            return AppAssets.resource("resources/sidebar/router.svg")
        if (deviceType === "sw2" || deviceType === "sw3")
            return AppAssets.resource("resources/sidebar/switch.svg")
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
    property color dotColor: statusColor

    ToolTip.visible: itemHover.hovered
    ToolTip.text:    deviceIp + (deviceType !== "" && deviceType !== "unknown"
                                     ? "  ·  " + deviceType
                                     : "  ·  unknown")
    ToolTip.delay:   400

    width:   parent.width
    height:  Theme.listItemHeight
    opacity: blockedByStatus ? 0.45 : 1.0

    color: isSelected        ? Theme.panelSideBarItemSelected :
           itemHover.hovered ? Theme.panelSideBarItemHover    : "transparent"

    signal clicked()
    signal rightClicked(string ip, int mouseX, int mouseY)

    // ── Active border bên trái ────────────────────────────────────────────────
    Rectangle {
        width:  3
        height: parent.height
        anchors.left: parent.left
        color:   Theme.panelSideBarAccentColor
        opacity: isSelected ? 1.0 : 0.0
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
        ThemedIcon {
            visible:          deviceItem.iconSource !== ""
            anchors.centerIn: parent
            iconSource: deviceItem.iconSource
            iconSize: 16
            iconColor: deviceItem.statusColor
        }

        // Dot — hiện khi không có icon (unknown/rỗng)
        Rectangle {
            visible:          deviceItem.iconSource === ""
            anchors.centerIn: parent
            width:  8; height: 8
            radius: 4
            color:  deviceItem.dotColor

            border.color: deviceItem.deviceType === ""
                          || deviceItem.deviceType === "unknown"
                              ? Theme.panelSideBarBorderColor
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
        color:          isSelected ? Theme.panelSideBarTextPrimary : Theme.panelSideBarTextSecondary
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
