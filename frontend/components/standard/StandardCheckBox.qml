pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import NetworkTools

// ─────────────────────────────────────────────────────────────────────────────
// StandardCheckBox
// Checkbox chuẩn của ứng dụng.
// Hỗ trợ cả 3 trạng thái: Checked, Unchecked, và PartiallyChecked.
// ─────────────────────────────────────────────────────────────────────────────
CheckBox {
    id: root

    // ── Kích thước & Font ────────────────────────────────────────────────────
    font.pixelSize: Theme.fontSizeNormal
    font.family:    Theme.fontFamily
    spacing:        Theme.spacing8

    opacity: enabled ? 1.0 : 0.6

    // ── Indicator (Ô vuông Checkbox) ─────────────────────────────────────────
    indicator: Rectangle {
        implicitWidth:  Theme.checkboxSize
        implicitHeight: Theme.checkboxSize
        x: root.leftPadding
        y: parent.height / 2 - height / 2

        radius: 3 // Bo góc nhẹ

        // Màu nền: Accent nếu được chọn/bán chọn, ngược lại dùng màu nền search
        color: (root.checkState === Qt.Checked || root.checkState === Qt.PartiallyChecked)
               ? Theme.accentColor
               : Theme.searchBackground2

        // Viền: Đổi màu khi hover, focus hoặc checked
        border.color: {
            if (root.checkState === Qt.Checked || root.checkState === Qt.PartiallyChecked) return Theme.accentColor
            if (root.hovered || root.visualFocus) return Theme.accentColor
            return Theme.borderColor
        }
        border.width: Theme.borderWidth

        // ── Trạng thái Checked (Dấu tick) ──
        Text {
            anchors.centerIn: parent
            visible:          root.checkState === Qt.Checked
            text:             "✓"
            color:            Theme.buttonTextSolid
            font.pixelSize:   12
            font.bold:        true
        }

        // ── Trạng thái PartiallyChecked (Dấu trừ) ──
        Rectangle {
            anchors.centerIn: parent
            visible:          root.checkState === Qt.PartiallyChecked
            width:            8
            height:           2
            color:            Theme.buttonTextSolid
            radius:           1
        }
    }

    // ── Content (Nhãn Text) ──────────────────────────────────────────────────
    contentItem: Text {
        text:              root.text
        font:              root.font
        color:             root.enabled ? Theme.textPrimary : Theme.textDisabled
        verticalAlignment: Text.AlignVCenter
        leftPadding:       root.indicator.width + root.spacing
    }
}
