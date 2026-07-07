pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import UI

Rectangle {
    id: root

    property string iconSource: ""
    property string tooltipText: ""
    property bool isActive: false

    width: Theme.activityBarWidth
    height: Theme.activityBarWidth // Hình vuông
    color: "transparent"

    signal clicked()

    // ── HIỆU ỨNG NỀN KHI HOVER (Phản hồi ngay lập tức, không delay) ──
    Rectangle {
        anchors.fill: parent
        color: Theme.activityBarItemHover
        visible: itemHover.hovered && !isActive
    }

    // ── VẠCH TRẠNG THÁI (Sắc nét, xuất hiện ngay không cần mọc từ giữa) ──
    Rectangle {
        id: activeIndicator
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 2 // Rất mỏng và tinh tế
        height: parent.height
        color: Theme.accentColor
        visible: root.isActive
    }

    // ── ICON (Dùng Button rỗng để nhuộm màu tự động) ──
    Button {
        anchors.centerIn: parent
        width: 28 // To hơn bản cũ một chút cho dễ nhìn
        height: 28
        padding: 0
        enabled: false // Tắt tương tác để nhường cho TapHandler
        background: Item {}

        icon.source: root.iconSource
        icon.width: 28
        icon.height: 28

        icon.color: root.isActive || itemHover.hovered ? Theme.activityBarTextPrimary : Theme.activityBarTextSecondary
        opacity: 1.0
    }

    HoverHandler {
        id: itemHover
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: root.clicked()
    }

    // Tooltip mang phong cách VS Code (Bám sát lề phải)
    ToolTip {
        visible: itemHover.hovered
        text: root.tooltipText
        delay: 600
        x: root.width + 5
        y: (root.height - height) / 2
    }
}
