pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

ColumnLayout {
    id: root
    spacing: 4

    // ── Các properties mở rộng để tái sử dụng ──
    property string labelText: ""
    property color  contentColor: Theme.textPrimary
    property bool   contentBold: false

    // ── Alias xuống ComboBox bên trong ──
    property alias model: combo.model
    property alias currentIndex: combo.currentIndex
    property alias currentText: combo.currentText
    property alias displayText: combo.displayText

    signal activated(int index)

    // ── Label hiển thị tên trường (nếu có) ──
    Text {
        visible: root.labelText !== ""
        text: root.labelText
        color: Theme.textSecondary
        font.pixelSize: Theme.fontSizeSmall
        font.family: Theme.fontFamily
    }

    // ── ComboBox chính ──
    ComboBox {
        id: combo
        Layout.fillWidth: true
        implicitHeight: Theme.itemHeight
        font.pixelSize: Theme.fontSizeNormal
        font.family: Theme.fontFamily

        onActivated: (index) => root.activated(index)

        background: Rectangle {
            color: Theme.inputBackground
            border.color: combo.activeFocus || combo.popup.visible ? Theme.inputBorderFocusColor : Theme.inputBorderColor
            border.width: Theme.borderWidth
            radius: Theme.radiusSmall

        }

        indicator: Item {
            x: combo.mirrored ? Theme.spacing8 : combo.width - width - Theme.spacing8
            y: (combo.height - height) / 2
            width: 14
            height: 14
            opacity: combo.enabled ? (combo.hovered || combo.activeFocus || combo.popup.visible ? 0.68 : 0.42) : 0.24

            Canvas {
                id: chevronCanvas
                anchors.centerIn: parent
                width: 10
                height: 6

                Connections {
                    target: Theme
                    function onThemeModeChanged() { chevronCanvas.requestPaint() }
                }

                onPaint: {
                    const ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    ctx.strokeStyle = Theme.textPrimary
                    ctx.lineWidth = 1.6
                    ctx.lineCap = "round"
                    ctx.lineJoin = "round"
                    ctx.beginPath()
                    ctx.moveTo(1, 1)
                    ctx.lineTo(width / 2, height - 1)
                    ctx.lineTo(width - 1, 1)
                    ctx.stroke()
                }
            }
        }

        // Tùy chỉnh vùng hiển thị chữ đang được chọn
        contentItem: Text {
            text: combo.displayText
            color: root.contentColor  // Áp dụng màu tùy chỉnh
            font.pixelSize: Theme.fontSizeNormal
            font.family: Theme.fontFamily
            font.bold: root.contentBold // Áp dụng in đậm
            verticalAlignment: Text.AlignVCenter
            leftPadding: 10
            rightPadding: 32
            opacity: combo.enabled ? 1.0 : 0.5
        }

        // Tùy chỉnh từng item trong danh sách thả xuống
        delegate: ItemDelegate {
            id: del
            width: combo.width
            required property int index
            required property string modelData

            hoverEnabled: true

            contentItem: Text {
                text: modelData
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeNormal
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                // Sáng lên khi chuột di qua HOẶC khi dùng phím mũi tên
                color: del.hovered || del.highlighted ? Theme.sideBarItemHover : "transparent"
                radius: Theme.borderRadius
            }
        }

        // Tùy chỉnh khung popup chứa danh sách
        popup: Popup {
            y: combo.height + 4
            width: combo.width
            // Đặt padding nhỏ để danh sách gọn gàng
            padding: 4

            // Quan trọng: Giới hạn chiều cao popup để hiển thị tối đa 5 item.
            // Nếu model ít hơn 5, nó sẽ tự động thu nhỏ lại nhờ tính toán của QML.
            // Số 36 là chiều cao ước tính của một item (dựa trên font size và padding).
            // Số 8 là bù trừ cho padding trên/dưới của popup (4 + 4).
            height: Math.min(contentItem.implicitHeight + 8, (36 * 5) + 8)

            contentItem: ListView {
                id: listview
                clip: true
                implicitHeight: contentHeight
                model: combo.popup.visible ? combo.delegateModel : null
                currentIndex: combo.highlightedIndex

                // Tối ưu scrollbar
                ScrollIndicator.vertical: ScrollIndicator {
                    active: true
                }
            }

            background: Rectangle {
                color: Theme.inputBackground
                border.color: Theme.inputBorderColor
                border.width: Theme.borderWidth
                radius: Theme.radiusSmall
            }
        }
    }
}
