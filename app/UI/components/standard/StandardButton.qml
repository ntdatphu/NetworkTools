pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

// ─────────────────────────────────────────────────────────────────────────────
// StandardButton
// Button chuẩn của ứng dụng.
// Hỗ trợ 5 types:
// - "Primary": Nút chính (màu xanh accent).
// - "Secondary": Nút phụ (nền xám/outline).
// - "Danger": Nút cảnh báo (màu đỏ).
// - "Ghost": Nút trong suốt, chỉ hiện nền khi hover.
// - "Icon": Nút vuông, chỉ hiển thị icon (MỚI THÊM).
// ─────────────────────────────────────────────────────────────────────────────
Button {
    id: root

    // ── Public API ───────────────────────────────────────────────────────────
    property string type:       "Secondary" // Primary | Secondary | Danger | Ghost | Icon
    property string tooltip:    ""

    // UI-P2-01: Standard controls are the lowest-cost place to establish an
    // accessibility contract for every feature that consumes them.
    Accessible.role: Accessible.Button
    Accessible.name: text !== "" ? text : tooltip
    Accessible.description: tooltip

    // Lưu ý: Icon truyền qua property `icon.source` mặc định của Button.
    // Text truyền qua property `text` mặc định của Button.

    // ── Kích thước ───────────────────────────────────────────────────────────
    implicitHeight: 34

    // Xử lý kích thước đặc biệt cho type "Icon" (ép thành hình vuông)
    implicitWidth: type === "Icon"
        ? implicitHeight
        : Math.max(80, contentItem.implicitWidth + leftPadding + rightPadding)

    leftPadding:  type === "Icon" ? 0 : Theme.spacing16
    rightPadding: type === "Icon" ? 0 : Theme.spacing16

    // ── Interaction ──────────────────────────────────────────────────────────
    HoverHandler {
        id: hoverHandler
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    }

    // ── Styling Helper ───────────────────────────────────────────────────────
    readonly property bool _selected: root.checkable && root.checked

    property color _textColor: {
        if (!root.enabled) return Theme.textDisabled
        if (root.type === "Primary" || root.type === "Danger") return Theme.buttonTextSolid
        if (root._selected) return Theme.textPrimary
        if (root.type === "Secondary" || root.type === "Ghost" || root.type === "Icon") {
            return hoverHandler.hovered ? Theme.textPrimary : Theme.textSecondary
        }
        return Theme.textPrimary
    }

    icon.color: _textColor

    // ── Background ───────────────────────────────────────────────────────────
    background: Rectangle {
        radius: Theme.radiusSmall

        color: {
            if (!root.enabled) return Theme.sideBarBackground
            if (root._selected) return Theme.sideBarItemSelected

            if (root.type === "Primary") {
                return hoverHandler.hovered ? Qt.lighter(Theme.accentEmphasis, 1.15) : Theme.accentEmphasis
            }
            if (root.type === "Danger") {
                return hoverHandler.hovered ? Qt.lighter(Theme.alertError, 1.15) : Theme.alertError
            }
            if (root.type === "Ghost" || root.type === "Icon") {
                return hoverHandler.hovered ? Theme.sideBarItemHover : "transparent"
            }
            // Secondary
            return hoverHandler.hovered ? Theme.sideBarItemHover : "transparent"
        }

        border.color: {
            if (!root.enabled) return Theme.inputBorderColor
            if (root._selected) return Theme.accentColor
            if (root.type === "Secondary") {
                return hoverHandler.hovered ? Theme.textSecondary : Theme.borderColor
            }
            return "transparent"
        }
        border.width: (!root.enabled || root.type === "Secondary" || root._selected) ? Theme.borderWidth : 0

    }

    // ── Content ──────────────────────────────────────────────────────────────
    contentItem: RowLayout {
        spacing: Theme.spacing8

        ThemedIcon {
            visible: root.icon.source.toString() !== ""
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: Theme.iconSizeNormal
            Layout.preferredHeight: Theme.iconSizeNormal
            iconSource: root.icon.source
            iconSize: Theme.iconSizeNormal
            iconColor: root._textColor
        }

        // Text
        Text {
            // Tự động ẩn chữ nếu là nút Icon (phòng trường hợp truyền nhầm cả chữ)
            visible: root.text !== "" && root.type !== "Icon"
            text: root.text
            color: root._textColor
            font.pixelSize: Theme.fontSizeNormal
            font.family: Theme.fontFamily
            font.bold: root.type === "Primary" || root.type === "Danger"
            Layout.alignment: Qt.AlignVCenter
        }
    }

    // ── Tooltip ──────────────────────────────────────────────────────────────
    ToolTip {
        visible: root.tooltip !== "" && hoverHandler.hovered
        text: root.tooltip
        delay: 400
    }
}
