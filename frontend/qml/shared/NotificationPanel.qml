pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import NetworkTools

Popup {
    id: root

    // Kích thước chuẩn của một bảng thông báo
    width: 360
    height: 400
    padding: 0

    // Xóa nền mặc định của Popup để tự vẽ bằng chuẩn Theme
    background: Rectangle {
        color: Theme.searchBackground2
        border.color: Theme.borderColor
        border.width: 1
        radius: Theme.borderRadius !== undefined ? Theme.borderRadius : 6
    }

    // ListModel chứa dữ liệu sẽ được truyền từ Main.qml vào đây
    property alias model: listView.model

    // Tín hiệu yêu cầu xóa toàn bộ thông báo
    signal clearAllRequested()

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── 1. HEADER (Tiêu đề và nút Clear) ──
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            color: "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16

                Text {
                    text: "Notifications"
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSizeNormal
                    font.weight: Font.DemiBold
                    Layout.fillWidth: true
                }

                // Nút Xóa tất cả
                Rectangle {
                    width: 24; height: 24
                    color: clearHover.hovered ? Theme.borderColor : "transparent"
                    radius: 4

                    Image {
                        anchors.centerIn: parent
                        source: "qrc:/qt/qml/NetworkTools/resources/devicetabs/close.svg"
                        width: 12; height: 12
                    }

                    HoverHandler { id: clearHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: root.clearAllRequested() }

                    ToolTip {
                        visible: clearHover.hovered
                        text: "Clear All Notifications"
                        delay: 400
                    }
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width; height: 1
                color: Theme.borderColor
            }
        }

        // ── 2. DANH SÁCH LỊCH SỬ THÔNG BÁO ──
        ListView {
            id: listView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            spacing: 1

            delegate: Rectangle {
                width: listView.width
                height: Math.max(56, contentLayout.implicitHeight + 24)
                color: hoverHandler.hovered ? Theme.searchBackground : "transparent"

                // Lấy dữ liệu từ ListModel an toàn với chế độ Bound
                required property string msgText
                required property string msgType
                required property string timestamp

                HoverHandler { id: hoverHandler }

                RowLayout {
                    id: contentLayout
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12

                    Image {
                        Layout.alignment: Qt.AlignTop | Qt.AlignLeft
                        sourceSize: Qt.size(16, 16)
                        width: 16; height: 16
                        source: {
                            if (msgType === "success") return "qrc:/qt/qml/NetworkTools/resources/statusbar/check.svg"
                            if (msgType === "error")   return "qrc:/qt/qml/NetworkTools/resources/statusbar/error.svg"
                            if (msgType === "warning") return "qrc:/qt/qml/NetworkTools/resources/statusbar/warning.svg"
                            return "qrc:/qt/qml/NetworkTools/resources/statusbar/info.svg"
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            Layout.fillWidth: true
                            text: msgText
                            color: Theme.textPrimary
                            font.pixelSize: Theme.fontSizeNormal
                            font.family: Theme.fontFamily
                            wrapMode: Text.Wrap
                        }

                        Text {
                            text: timestamp
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall - 1
                            font.family: Theme.fontFamily
                        }
                    }
                }

                // Đường viền ngăn cách các thông báo
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width; height: 1
                    color: Theme.borderColor
                }
            }

            // ── THÔNG ĐIỆP KHI TRỐNG ──
            Text {
                anchors.centerIn: parent
                text: "No new notifications"
                color: Theme.textDisabled
                font.pixelSize: Theme.fontSizeNormal
                font.family: Theme.fontFamily
                visible: listView.count === 0
            }
        }
    }
}