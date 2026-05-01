pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import NetworkUI

TextField {
    id: root

    // ── Giao diện Text cơ bản ──
    color: Theme.textPrimary
    font.pixelSize: Theme.fontSizeNormal
    font.family: Theme.fontFamily
    
    // Màu của dòng chữ mờ khi chưa nhập liệu
    placeholderTextColor: Theme.placeholderTextColor
    
    // Tự động mờ đi nếu trường nhập liệu bị vô hiệu hóa hoặc chỉ đọc
    opacity: (enabled && !readOnly) ? 1.0 : 0.6

    // Căn lề trái nhẹ để chữ không bị dính sát vào viền
    leftPadding: 12
    rightPadding: 12

    // ── Tùy biến hình nền (Background) ──
    background: Rectangle {
        color: Theme.searchBackground2
        
        // Property Binding: Viền tự động sáng lên màu Accent khi người dùng click vào (activeFocus)
        border.color: root.activeFocus ? Theme.accentColor : Theme.borderColor
        border.width: 1
        
        // Bo góc chuẩn theo Theme
        radius: Theme.borderRadius !== undefined ? Theme.borderRadius : 4

        // Hiệu ứng chuyển màu viền mượt mà (Smooth transition) thay vì đổi màu giật cục
        Behavior on border.color { 
            ColorAnimation { duration: Theme.animationDurationFast } 
        }
    }
}