pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import NetworkTools

Rectangle {
    id: activityBarItem

    property string iconSource: ""
    property string tooltipText: ""
    property bool isActive: false

    width: Theme.activityBarWidth
    height: Theme.activityBarWidth  // vuông
    color: isActive ? Theme.activityBarItemActive :
           itemHover.hovered ? Theme.activityBarItemHover : "transparent"

    signal clicked()

    // ── DÙNG BUTTON ĐỂ NHUỘM MÀU SVG ──
    Button {
        anchors.centerIn: parent
        width: 24
        height: 24
        padding: 0

        // Khai báo Icon cho Button
        icon.source: iconSource
        icon.width: 24
        icon.height: 24

        // Phép thuật nhuộm màu tự động của Qt
        icon.color: isActive ? Theme.textPrimary : Theme.textSecondary

        // Xóa sạch phông nền của Button để nó trong suốt
        background: Item {}

        // Vô hiệu hóa Button này để nó không chặn thao tác click chuột của TapHandler bên ngoài
        enabled: false
    }

    // Active indicator — thanh dọc bên trái giống VS Code
    Rectangle {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 2
        height: 24
        color: Theme.accentColor
        visible: isActive
    }

    HoverHandler { id: itemHover }
    TapHandler { onTapped: activityBarItem.clicked() }

    // Tooltip
    ToolTip {
        visible: itemHover.hovered
        text: tooltipText
        delay: 500
    }
}