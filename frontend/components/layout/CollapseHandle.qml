pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import NetworkTools

Rectangle {
    id: root

    // ── Public API ───────────────────────────────────────────────────────────
    property bool vertical:           true
    property bool collapsed:          false
    property string collapseDirection: "left"

    signal expandRequested()

    // ── Kích thước ───────────────────────────────────────────────────────────
    // Dùng Rectangle làm root thay vì Item để SplitView nhận đúng kích thước
    implicitWidth:  vertical ? Theme.splitHandleHitWidth : parent.width
    implicitHeight: vertical ? parent.height : Theme.splitHandleHitWidth

    // Nền trong suốt — chỉ line bên trong có màu
    color: "transparent"

    // ── Hover detection ───────────────────────────────────────────────────────
    HoverHandler {
        id: hoverHandler
        cursorShape: root.vertical ? Qt.SizeHorCursor : Qt.SizeVerCursor
    }

    // ── Line chính ────────────────────────────────────────────────────────────
    Rectangle {
        id: handleLine
        anchors.centerIn: parent

        width:  root.vertical ? 1 : parent.width
        height: root.vertical ? parent.height : 1

        color: (hoverHandler.hovered || root.collapsed)
                   ? Theme.splitHandleHoverColor
                   : Theme.splitHandleColor

        Behavior on color {
            ColorAnimation { duration: Theme.animationDurationFast }
        }

        // Dày lên khi hover — dùng scale để không ảnh hưởng layout
        transform: Scale {
            xScale: root.vertical
                        ? (hoverHandler.hovered ? 2.5 : 1.0)
                        : 1.0
            yScale: root.vertical
                        ? 1.0
                        : (hoverHandler.hovered ? 2.5 : 1.0)
            origin.x: handleLine.width  / 2
            origin.y: handleLine.height / 2

            Behavior on xScale {
                NumberAnimation {
                    duration: Theme.animationDurationFast
                    easing.type: Easing.OutQuad
                }
            }
            Behavior on yScale {
                NumberAnimation {
                    duration: Theme.animationDurationFast
                    easing.type: Easing.OutQuad
                }
            }
        }
    }

    // ── Nút Expand (chỉ hiện khi collapsed) ──────────────────────────────────
    Rectangle {
        id: expandButton
        visible: root.collapsed
        anchors.centerIn: parent

        width:  Theme.splitCollapseButtonSize + 8
        height: Theme.splitCollapseButtonSize + 8
        radius: Theme.radiusSmall

        color: expandBtnHover.hovered
                   ? Theme.accentColor
                   : Theme.splitHandleHoverColor

        Behavior on color {
            ColorAnimation { duration: Theme.animationDurationFast }
        }

        Text {
            anchors.centerIn: parent
            text: {
                if (root.vertical)
                    return root.collapseDirection === "left" ? "›" : "‹"
                return root.collapseDirection === "left" ? "∨" : "∧"
            }
            color:          Theme.buttonTextSolid
            font.pixelSize: Theme.fontSizeLarge
            font.family:    Theme.fontFamily
            font.bold:      true
        }

        HoverHandler { id: expandBtnHover; cursorShape: Qt.PointingHandCursor }
        TapHandler   { onTapped: root.expandRequested() }

        opacity: root.collapsed ? 1.0 : 0.0
        Behavior on opacity {
            NumberAnimation { duration: Theme.animationDurationMedium }
        }
    }
}