pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import NetworkUI

ComboBox {
    id: control

    implicitWidth: 120
    implicitHeight: Theme.itemHeight

    // ── BACKGROUND ────────────────────────────────────────────────────────
    background: Rectangle {
        implicitWidth: control.implicitWidth
        implicitHeight: control.implicitHeight
        color: control.enabled ? Theme.searchBackground : Theme.tabInactive
        border.color: control.activeFocus ? Theme.accentColor : Theme.borderColor
        border.width: control.activeFocus ? 2 : Theme.borderWidth
        radius: Theme.borderRadius
    }

    // ── CONTENT ITEM (TEXT HIỂN THỊ KHI CHƯA MỞ POPUP) ──────────────────────
    contentItem: Text {
        leftPadding: 10
        rightPadding: control.indicator.width + control.spacing
        text: control.displayText
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeNormal
        color: control.enabled ? Theme.textPrimary : Theme.textDisabled
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    // ── INDICATOR (MŨI TÊN DROPDOWN) ─────────────────────────────────────────
    indicator: Canvas {
        x: control.width - width - control.rightPadding
        y: control.topPadding + (control.availableHeight - height) / 2
        width: 10
        height: 6
        contextType: "2d"

        Connections {
            target: control
            function onPressedChanged() { control.indicator.requestPaint() }
        }

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            ctx.moveTo(0, 0);
            ctx.lineTo(width, 0);
            ctx.lineTo(width / 2, height);
            ctx.closePath();
            ctx.fillStyle = control.enabled ? Theme.textSecondary : Theme.textDisabled;
            ctx.fill();
        }
    }

    // ── DELEGATE (TỪNG ITEM TRONG DANH SÁCH) ─────────────────────────────────
    delegate: ItemDelegate {
        width: control.width
        height: Theme.itemHeight

        contentItem: Text {
            text: control.textRole ? (Array.isArray(control.model) ? modelData[control.textRole] : model[control.textRole]) : modelData
            color: control.highlightedIndex === index ? Theme.accentColor : Theme.textPrimary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeNormal
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }

        background: Rectangle {
            color: control.highlightedIndex === index ? Theme.sideBarItemHover : "transparent"
            radius: Theme.borderRadius / 2
        }

        highlighted: control.highlightedIndex === index
    }

    // ── POPUP (KHUNG CHỨA DANH SÁCH) ─────────────────────────────────────────
    popup: Popup {
        y: control.height + 2
        width: control.width
        implicitHeight: contentItem.implicitHeight
        padding: 4

        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight > 200 ? 200 : contentHeight // Giới hạn chiều cao popup
            model: control.popup.visible ? control.delegateModel : null
            currentIndex: control.highlightedIndex
            ScrollIndicator.vertical: ScrollIndicator { }
        }

        background: Rectangle {
            color: Theme.contentBackground
            border.color: Theme.borderColor
            border.width: Theme.borderWidth
            radius: Theme.borderRadius

            // Đổ bóng nhẹ cho Popup
            layer.enabled: true
            layer.effect: ShaderEffect {
                property variant src: background
                // Simple drop shadow effect can be added here if needed in the future
                // Hiện tại giữ ở mức cơ bản để tối ưu performance
            }
        }
    }
}