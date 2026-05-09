pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Basic
import QtQuick.Layouts
import NetworkTools

Popup {
    id: dialog

    // Các properties có thể tùy chỉnh khi gọi component
    property string titleText: "Validation Error"
    property string messageText: "Please check your inputs."
    property string acceptText: "OK"
    property string rejectText: "Cancel"
    property bool showCancel: false

    signal accepted()
    signal rejected()

    anchors.centerIn: parent
    width: 400
    modal: true
    focus: true
    closePolicy: Popup.NoAutoClose

    // Sử dụng màu overlay đã được chuẩn hóa ở Giai đoạn 1
    Overlay.modal: Rectangle {
        color: Theme.dialogOverlay
    }

    background: Rectangle {
        color: Theme.contentBackground
        radius: Theme.cardRadius
        border.color: Theme.borderColor
        border.width: Theme.borderWidth
    }

    contentItem: ColumnLayout {
        spacing: 16

        // Tiêu đề Dialog
        Text {
            Layout.fillWidth: true
            text: dialog.titleText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeTitle
            font.weight: Font.Bold
            color: Theme.alertError // Mặc định dialog lỗi thường dùng màu đỏ
        }

        // Nội dung thông báo
        Text {
            Layout.fillWidth: true
            text: dialog.messageText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeNormal
            color: Theme.textSecondary
            wrapMode: Text.WordWrap
            lineHeight: 1.4
        }

        Item { Layout.preferredHeight: 8 } // Khoảng cách

        // Khu vực nút bấm
        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignRight
            spacing: 12

            // Nút Cancel (ẩn theo mặc định)
            Rectangle {
                visible: dialog.showCancel
                Layout.preferredWidth: 80
                Layout.preferredHeight: 32
                radius: Theme.borderRadius
                border.color: Theme.borderColor

                // Gán color duy nhất 1 lần ở đây, sử dụng HoverHandler
                color: cancelHover.hovered ? Theme.sideBarItemHover : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: dialog.rejectText
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeNormal
                }

                HoverHandler { id: cancelHover }
                TapHandler {
                    onTapped: {
                        dialog.rejected()
                        dialog.close()
                    }
                }
            }

            // Nút OK/Accept
            Rectangle {
                Layout.preferredWidth: 80
                Layout.preferredHeight: 32
                radius: Theme.borderRadius

                // Gán color duy nhất 1 lần ở đây, sử dụng HoverHandler
                color: okHover.hovered ? Qt.lighter(Theme.accentColor, 1.1) : Theme.accentColor

                Text {
                    anchors.centerIn: parent
                    text: dialog.acceptText
                    color: Theme.buttonTextSolid
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeNormal
                    font.weight: Font.Medium
                }

                HoverHandler { id: okHover }
                TapHandler {
                    onTapped: {
                        dialog.accepted()
                        dialog.close()
                    }
                }
            }
        }
    }
}