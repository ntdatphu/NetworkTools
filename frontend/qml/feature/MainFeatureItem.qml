pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import NetworkTools

Rectangle {
    id: mainFeatureItem

    property string iconSource: ""
    property string tooltipText: ""
    property bool isActive: false

    // Biến trạng thái để làm hiệu ứng chớp nháy
    property bool isFlashing: false

    signal clicked()

    width: Theme.featureBarHeight
    height: Theme.featureBarHeight

    // Màu nền và độ mờ ưu tiên trạng thái isFlashing
    color: (isActive || isFlashing) ? Theme.featureMainActive :
           itemHover.hovered ? Theme.featureMainHover : "transparent"

    // ── ĐÃ SỬA: DÙNG BUTTON ĐỂ NHUỘM MÀU SVG ──
    Button {
        anchors.centerIn: parent
        width: 18; height: 18; padding: 0
        icon.source: iconSource
        icon.width: 18; icon.height: 18

        // Nhuộm màu: Nếu đang active hoặc chớp thì dùng màu Xanh (Accent), bình thường thì dùng màu Chữ
        icon.color: (isActive || isFlashing) ? Theme.accentColor : Theme.textPrimary

        opacity: (isActive || isFlashing) ? 1.0 : 0.6

        background: Item {}
        enabled: false
    }

    HoverHandler { id: itemHover }
    TapHandler { onTapped: mainFeatureItem.clicked() }

    ToolTip {
        visible: itemHover.hovered
        text: tooltipText
        delay: 500
    }

    Timer {
        id: flashTimer
        interval: 150
        onTriggered: mainFeatureItem.isFlashing = false
    }

    function triggerFlash() {
        mainFeatureItem.isFlashing = true
        flashTimer.restart()
    }
}