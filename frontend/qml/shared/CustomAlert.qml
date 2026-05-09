pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtQuick.Effects
import NetworkTools

Window {
    id: alertWindow
    // 1. Tăng kích thước Window thêm 20px mỗi chiều để lấy không gian vẽ bóng
    width: 340; height: 180
    minimumWidth: 340; maximumWidth: 340
    minimumHeight: 180; maximumHeight: 180
    color: "transparent"

    // Ép người dùng phải bấm OK mới được làm việc khác
    modality: Qt.ApplicationModal
    flags: Qt.Dialog | Qt.FramelessWindowHint

    // Các biến cho bên ngoài truyền vào
    property string titleText: "NetworkTools Alert"
    property string messageText: ""
    property bool isError: false

    // Đường ống tín hiệu khi bấm OK
    signal accepted()

    // Hàm mở cửa sổ (tự căn giữa màn hình)
    function openAlert() {
        x = Screen.width / 2 - width / 2
        y = Screen.height / 2 - height / 2
        show()
    }

    // Vùng chứa nội dung (Rectangle chính)
    Rectangle {
        id: mainContent
        anchors.fill: parent
        anchors.margins: 10
        color: Theme.contentBackground
        radius: 8

        // Thu hẹp border xuống 1px để thanh thoát, giống phong cách phẳng của Word
        border.color: alertWindow.active
                      ? (isError ? Theme.alertError : Theme.alertSuccess)
                      : Theme.textDisabled
        border.width: 1

        Behavior on border.color { ColorAnimation { duration: Theme.animationDurationFast } }

        DragHandler { onActiveChanged: if (active) alertWindow.startSystemMove() }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 12

            Text {
                text: titleText
                color: isError ? Theme.alertError : Theme.textPrimary
                font.pixelSize: 18 // Tiêu đề to hơn một chút giống form hệ thống
                font.bold: true
                font.family: Theme.fontFamily
            }

            Text {
                text: messageText
                color: Theme.textPrimary
                font.pixelSize: Theme.fontSizeNormal
                font.family: Theme.fontFamily
                Layout.fillWidth: true
                Layout.fillHeight: true
                wrapMode: Text.WordWrap
                verticalAlignment: Text.AlignTop
            }

            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true } // Lò xo đẩy nút sang phải

                // Nút OK
                Rectangle {
                    Layout.preferredWidth: 80; Layout.preferredHeight: 32; radius: 4
                    color: okHover.hovered
                           ? Qt.lighter(isError ? Theme.alertError : Theme.alertSuccess, 1.2)
                           : (isError ? Theme.alertError : Theme.alertSuccess)

                    Text {
                        anchors.centerIn: parent
                        text: "OK"
                        color: Theme.buttonTextSolid
                        font.pixelSize: Theme.fontSizeNormal; font.bold: true; font.family: Theme.fontFamily
                    }

                    HoverHandler { id: okHover }
                    TapHandler {
                        onTapped: {
                            alertWindow.accepted() // Phát tín hiệu ra ngoài
                            alertWindow.close()    // Tự đóng chính nó
                        }
                    }
                }
            }
        }
    }

    // 3. Hiệu ứng đổ bóng chuẩn phong cách Windows
    MultiEffect {
        source: mainContent
        anchors.fill: mainContent
        shadowEnabled: true
        shadowColor: Theme.shadowColor
        shadowBlur: 0.8          // Độ nhòe của bóng
        shadowHorizontalOffset: 0
        shadowVerticalOffset: 4  // Bóng hắt nhẹ xuống dưới
    }
}