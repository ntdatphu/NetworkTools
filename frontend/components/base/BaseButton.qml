pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import NetworkTools

// ─────────────────────────────────────────────────────────────────────────────
// BASE BUTTON
// Lớp dưới cùng của mọi loại nút bấm.
// Không fix cứng Business Logic, chỉ cung cấp cấu trúc và Interaction.
// Sử dụng HoverHandler và TapHandler chuẩn.
// ─────────────────────────────────────────────────────────────────────────────
Item {
    id: root

    // ── 1. Public API (UI Contract) ──────────────────────────────────────────
    property string text: ""
    property string iconSource: ""
    property bool enabled: true

    // ── 2. Styling Properties (Cho phép override thoải mái) ──────────────────
    property color backgroundColor: Theme.accentColor
    property color backgroundHoveredColor: Qt.lighter(backgroundColor, 1.15)
    property color backgroundPressedColor: Qt.darker(backgroundColor, 1.15)
    property color backgroundDisabledColor: "transparent"

    property color borderColor: "transparent"
    property color borderHoveredColor: borderColor
    property int borderWidth: 0

    property color contentColor: Theme.buttonTextSolid
    property color contentDisabledColor: Theme.textDisabled

    property int radius: Theme.borderRadius
    property int leftPadding: 16
    property int rightPadding: 16
    property int fontPixelSize: Theme.fontSizeNormal
    property bool fontBold: true

    // ── 3. Dimensions ────────────────────────────────────────────────────────
    implicitWidth: Math.max(80, contentLayout.implicitWidth + leftPadding + rightPadding)
    implicitHeight: 34

    opacity: enabled ? 1.0 : 0.6

    // ── 4. Signals ───────────────────────────────────────────────────────────
    signal clicked()

    // ── 5. Layout & Render ───────────────────────────────────────────────────
    Rectangle {
        id: bg
        anchors.fill: parent
        radius: root.radius

        color: {
            if (!root.enabled) return root.backgroundDisabledColor
            if (tapHandler.pressed) return root.backgroundPressedColor
            if (hoverHandler.hovered) return root.backgroundHoveredColor
            return root.backgroundColor
        }

        border.color: {
            if (!root.enabled) return root.borderColor
            if (hoverHandler.hovered) return root.borderHoveredColor
            return root.borderColor
        }
        border.width: root.borderWidth

    }

    RowLayout {
        id: contentLayout
        anchors.centerIn: parent
        spacing: 8

        Image {
            visible: root.iconSource !== ""
            source: root.iconSource
            sourceSize.width: 16
            sourceSize.height: 16
            Layout.alignment: Qt.AlignVCenter
            opacity: root.enabled ? 1.0 : 0.5
        }

        Text {
            visible: root.text !== ""
            text: root.text
            color: root.enabled ? root.contentColor : root.contentDisabledColor
            font.pixelSize: root.fontPixelSize
            font.family: Theme.fontFamily
            font.bold: root.fontBold
            Layout.alignment: Qt.AlignVCenter
        }
    }

    // ── 6. Interactions (Modern QML) ─────────────────────────────────────────
    HoverHandler {
        id: hoverHandler
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        id: tapHandler
        enabled: root.enabled
        onTapped: root.clicked()
    }
}
