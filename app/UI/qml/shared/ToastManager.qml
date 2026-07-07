pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

Item {
    id: root

    width: 320
    // [1] Cập nhật chiều cao ôm theo nội dung của ListView
    height: toastList.contentHeight 

    anchors.bottom: parent.bottom
    anchors.bottomMargin: Theme.statusBarHeight + 16
    anchors.right: parent.right
    anchors.rightMargin: 16
    z: 9999

    property int nextId: 0

    ListModel {
        id: toastModel
    }

    // [2] Dùng tham số mặc định (default parameter) của ES6 cho type
    function showToast(message, type = "info") {
        toastModel.append({
            "uid": nextId++,
            "msgText": message,
            "msgType": type
        })
    }

    function removeToast(uid) {
        for (let i = 0; i < toastModel.count; i++) {
            if (toastModel.get(i).uid === uid) {
                toastModel.remove(i)
                break
            }
        }
    }

    // [3] THAY THẾ ColumnLayout + Repeater bằng ListView
    ListView {
        id: toastList
        anchors.bottom: parent.bottom
        width: parent.width
        
        // Quan trọng: Tự động co giãn chiều cao theo tổng các Toast
        height: contentHeight 
        
        interactive: false // Tắt tính năng cuộn bằng chuột
        spacing: 12

        // Quan trọng: Thông báo mới nhất sẽ xuất hiện ở ĐÁY và đẩy các thông báo cũ lên trên
        verticalLayoutDirection: ListView.BottomToTop

        model: toastModel

        // ── HỆ THỐNG TRANSITION (Tự động hóa Animation) ──

        // Hiệu ứng MƯỢT khi Toast MỚI xuất hiện
        add: Transition {
            NumberAnimation {
                property: "opacity"
                from: 0; to: 1
                duration: 300
                easing.type: Easing.OutCubic
            }
        }

        // Hiệu ứng MƯỢT khi Toast BỊ XÓA
        remove: Transition {
            NumberAnimation { property: "opacity"; to: 0; duration: 200 }
        }

        // Hiệu ứng TRƯỢT LẤP CHỖ TRỐNG cho các Toast còn lại
        displaced: Transition {
            NumberAnimation { properties: "y"; duration: 300; easing.type: Easing.OutCubic }
        }

        delegate: Rectangle {
            id: toastCard

            // Khai báo tường minh từ model
            required property int uid
            required property string msgText
            required property string msgType

            width: toastList.width
            implicitHeight: contentLayout.implicitHeight + 20

            color: Theme.searchBackground2
            radius: Theme.borderRadius !== undefined ? Theme.borderRadius : 6
            border.color: Theme.borderColor
            border.width: 1

            property string iconSource: {
                if (msgType === "success") return AppPaths.resource("resources/statusbar/check.svg")
                if (msgType === "error")   return AppPaths.resource("resources/statusbar/error.svg")
                if (msgType === "warning") return AppPaths.resource("resources/statusbar/warning.svg")
                return AppPaths.resource("resources/statusbar/info.svg")
            }

            property color accentColor: {
                if (msgType === "success") return Theme.alertSuccess
                if (msgType === "error")   return Theme.alertError
                if (msgType === "warning") return Theme.alertWarning
                return Theme.alertInfo
            }

            property color contentBgColor: {
                if (msgType === "success") return Theme.alertSuccessSubtle
                if (msgType === "error")   return Theme.alertErrorSubtle
                if (msgType === "warning") return Theme.alertWarningSubtle
                return Theme.alertInfoSubtle
            }

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 4
                color: toastCard.accentColor
                topLeftRadius: toastCard.radius
                bottomLeftRadius: toastCard.radius
            }

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 4
                color: toastCard.contentBgColor
                radius: toastCard.radius
            }

            RowLayout {
                id: contentLayout
                anchors.fill: parent
                anchors.margins: 10
                anchors.leftMargin: 16
                spacing: 12

                Button {
                    Layout.alignment: Qt.AlignTop | Qt.AlignLeft
                    Layout.topMargin: 2
                    width: 16; height: 16; padding: 0
                    icon.source: toastCard.iconSource
                    icon.width: 16; icon.height: 16
                    icon.color: toastCard.accentColor
                    background: Item {}
                    enabled: false
                }

                Text {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
                    text: msgText
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSizeNormal
                    font.family: Theme.fontFamily
                    wrapMode: Text.Wrap
                }

                CloseButton {
                    Layout.alignment: Qt.AlignTop | Qt.AlignRight
                    variant: "compact"
                    tooltip: "Dismiss notification"
                    onClicked: {
                        autoCloseTimer.stop()
                        root.removeToast(uid)
                        // Việc gọi removeToast() sẽ tự động kích hoạt "remove: Transition" ở trên.
                    }
                }
            }

            // [4] Hẹn giờ tự đóng gọn gàng hơn
            Timer {
                id: autoCloseTimer
                interval: 5000
                running: true // Tự động bắt đầu đếm ngược khi Delegate này được tạo ra
                repeat: false
                onTriggered: {
                    root.removeToast(uid)
                }
            }
        }
    }
}
