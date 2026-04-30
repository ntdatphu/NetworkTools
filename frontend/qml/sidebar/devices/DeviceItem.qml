pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import NetworkUI

Rectangle {
    id: deviceItem

    required property int index
    required property var modelData

    property string deviceName: ""
    property string deviceIp:   ""
    // ── THÊM MỚI: Nhận loại thiết bị từ Model ──
    property string deviceType: ""

    property bool isSelected:   false

    // ── NÂNG CẤP: Dùng String thay vì Boolean cho khả năng mở rộng ──
    property string displayFormat: "name" // "name" | "ip" | "both"

    property string status:     "connected"
    readonly property bool blockedByStatus: status === "waiting"

    // ── LOGIC 1: Động hóa Chuỗi Hiển thị ──
    property string displayText: {
        // Fallback: Nếu tên rỗng thì xài IP làm tên tạm
        const safeName = deviceName.trim() !== "" ? deviceName : deviceIp

        if (displayFormat === "ip") return deviceIp
        if (displayFormat === "both") return safeName + " (" + deviceIp + ")"
        return safeName // Default là "name"
    }

    // ── LOGIC 2: Quyết định Icon ──
    property string iconSource: {
        if (deviceType === "router") return "qrc:/qt/qml/NetworkUI/resources/sidebar/router.svg"
        if (deviceType === "sw2" || deviceType === "sw3") return "qrc:/qt/qml/NetworkUI/resources/sidebar/switch.svg"
        return "" // Rỗng = không có icon, sẽ xài dấu chấm
    }

    // ── LOGIC 3: Đồng bộ Màu Trạng thái ──
    property color statusColor: {
        if (status === "connected") return Theme.statusConnected
        if (status === "waiting")   return Theme.statusWaiting
        return Theme.statusDisconnected
    }

    ToolTip.visible: itemHover.hovered
    ToolTip.text: deviceIp
    ToolTip.delay: 400

    width: parent.width
    height: Theme.listItemHeight
    opacity: blockedByStatus ? 0.45 : 1.0

    Behavior on opacity { NumberAnimation { duration: Theme.animationDurationMedium } }

    color: isSelected        ? Theme.sideBarItemSelected :
           itemHover.hovered ? Theme.sideBarItemHover    : "transparent"

    signal clicked()
    signal rightClicked(string ip, int mouseX, int mouseY)

    // Active border
    Rectangle {
        width: 3
        height: parent.height
        anchors.left: parent.left
        color: Theme.accentColor
        opacity: isSelected ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: Theme.animationDurationMedium } }
    }

    // ── KHU VỰC ICON / STATUS DOT ──
    Item {
        id: iconContainer
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        width: 16
        height: 16

        // Tuyệt chiêu nhuộm màu SVG bằng Button (Áp dụng cho Router/Switch)
        Button {
            visible: deviceItem.iconSource !== ""
            anchors.centerIn: parent
            width: 16
            height: 16
            padding: 0
            icon.source: deviceItem.iconSource
            icon.width: 16
            icon.height: 16
            icon.color: deviceItem.statusColor // Tự động nhuộm màu theo mạng
            background: Item {}
            enabled: false
        }

        // Native Dot (Nhanh và mượt hơn ảnh SVG dot.svg)
        Rectangle {
            visible: deviceItem.iconSource === ""
            anchors.centerIn: parent
            width: 8
            height: 8
            radius: 4
            color: deviceItem.statusColor
            Behavior on color { ColorAnimation { duration: Theme.animationDurationMedium } }
        }
    }

    // ── KHU VỰC TEXT ──
    Text {
        anchors.left: iconContainer.right
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: 8

        text: deviceItem.displayText // Gọi property binding
        color: isSelected ? Theme.textPrimary : Theme.textSecondary
        font.pixelSize: Theme.fontSizeNormal
        font.family: Theme.fontFamily
        elide: Text.ElideRight
    }

    HoverHandler { id: itemHover }

    TapHandler {
        enabled: !deviceItem.blockedByStatus
        acceptedButtons: Qt.LeftButton
        onTapped: deviceItem.clicked()
    }

    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: (eventPoint) => {
            var globalPos = deviceItem.mapToItem(null, eventPoint.position.x, eventPoint.position.y)
            deviceItem.rightClicked(deviceIp, globalPos.x, globalPos.y)
        }
    }
}