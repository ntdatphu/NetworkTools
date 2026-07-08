pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

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

        // ── 1. HEADER ──
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            color: "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: Theme.spacing8

                Text {
                    text: qsTr("Notifications")
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSizeNormal
                    font.weight: Font.DemiBold
                    Layout.fillWidth: true
                }

                StandardButton {
                    visible: listView.count > 0
                    text: qsTr("Clear All")
                    type: "Ghost"
                    tooltip: qsTr("Clear all notifications")
                    Layout.preferredHeight: 32
                    Layout.alignment: Qt.AlignVCenter
                    onClicked: root.clearAllRequested()
                }

                CloseButton {
                    variant: "compact"
                    tooltip: qsTr("Close notifications")
                    Layout.alignment: Qt.AlignVCenter
                    onClicked: root.close()
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
                id: notificationItem
                width: listView.width
                height: Math.max(56, contentLayout.implicitHeight + 24)
                color: "transparent"
                border.color: Theme.borderColor
                border.width: 1

                // Lấy dữ liệu từ ListModel an toàn với chế độ Bound
                required property string msgText
                required property string msgType
                required property string timestamp

                HoverHandler { id: hoverHandler }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 1
                    color: hoverHandler.hovered ? Theme.searchBackground : notificationIcon.contentBackgroundColor
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 4
                    color: notificationIcon.accentColor
                }

                RowLayout {
                    id: contentLayout
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12

                    StatusIcon {
                        id: notificationIcon
                        Layout.alignment: Qt.AlignTop | Qt.AlignLeft
                        statusType: notificationItem.msgType
                        iconSize: 16
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

            }

            // ── THÔNG ĐIỆP KHI TRỐNG ──
            Text {
                anchors.centerIn: parent
                text: qsTr("No new notifications")
                color: Theme.textDisabled
                font.pixelSize: Theme.fontSizeNormal
                font.family: Theme.fontFamily
                visible: listView.count === 0
            }
        }
    }
}
