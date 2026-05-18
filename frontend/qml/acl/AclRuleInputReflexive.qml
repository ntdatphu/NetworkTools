pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import NetworkTools

// ── AclRuleInputReflexive ────────────────────────────────────────────────────
// Box nhập thông tin rule cho Reflexive ACL.
// Cấu trúc giống Dynamic ACL, chỉ khác:
//   - "Dynamic Name" đổi thành "Reflect Name"
//   - Ý nghĩa: Reflect Name là tên của reflexive ACL entry được tạo tự động
//     khi traffic outbound match rule này.
// Được nhúng vào AclForm khi ACL type = "Reflexive".
// ─────────────────────────────────────────────────────────────────────────────
ColumnLayout {
    id: root

    // ── Properties alias trỏ vào Extended box bên trong ──
    property alias protocol:            extendedBox.protocol
    property alias sourceIp:            extendedBox.sourceIp
    property alias sourceWildcard:      extendedBox.sourceWildcard
    property alias sourcePort:          extendedBox.sourcePort
    property alias destinationIp:       extendedBox.destinationIp
    property alias destinationWildcard: extendedBox.destinationWildcard
    property alias destinationPort:     extendedBox.destinationPort

    // ── Properties riêng của Reflexive ──
    property alias reflectName: reflectNameField.text
    // Lấy thẳng giá trị value từ StandardSpinBox thay vì text field giả
    property int timeout: timeoutSpinBox.value

    // ── Signal thông báo dữ liệu thay đổi để AclForm theo dõi ──
    signal fieldChanged()

    // ── Hàm xóa sạch toàn bộ input sau khi Add Rule ──
    function clearFields() {
        extendedBox.clearFields()
        reflectNameField.text = ""
        timeoutSpinBox.value  = 0
    }

    // ── Hàm tạo chuỗi tóm tắt cho cột Detail trong bảng Rules ──
    function buildDetail() {
        const extDetail = extendedBox.buildDetail()
        const refName   = reflectNameField.text.trim()
        const tout      = timeoutSpinBox.value

        let refPart = refName !== "" ? "  |  reflect: " + refName : ""
        if (tout > 0) refPart += "  timeout: " + tout + "s"

        return extDetail + refPart
    }

    spacing: 12

    // ── Phần 1: Extended box (tái sử dụng hoàn toàn) ─────────────────
    AclRuleInputExtended {
        id:               extendedBox
        Layout.fillWidth: true
        onFieldChanged:   root.fieldChanged()
    }

    // ── Phần 2: Reflexive-specific box ───────────────────────────────
    Rectangle {
        Layout.fillWidth: true
        implicitHeight:   reflexiveLayout.implicitHeight + 24
        radius:           Theme.cardRadius
        color:            Theme.contentSurface
        border.color:     Theme.borderColor
        border.width:     Theme.borderWidth

        ColumnLayout {
            id:              reflexiveLayout
            anchors.fill:    parent
            anchors.margins: 12
            spacing:         12

            // ── Tiêu đề box ──────────────────────────────────────────
            Text {
                text:                "Reflexive Options"
                color:               Theme.textSecondary
                font.pixelSize:      Theme.fontSizeSmall
                font.family:         Theme.fontFamily
                font.bold:           true
                font.capitalization: Font.AllUppercase
            }

            Rectangle {
                Layout.fillWidth: true
                height:           Theme.borderWidth
                color:            Theme.borderColor
                opacity:          0.6
            }

            RowLayout {
                Layout.fillWidth: true
                spacing:          12

                // Reflect Name
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing:          4

                    Text {
                        text:           "Reflect Name"
                        color:          Theme.textSecondary
                        font.pixelSize: Theme.fontSizeSmall
                        font.family:    Theme.fontFamily
                    }

                    StandardTextField {
                        id:               reflectNameField
                        Layout.fillWidth: true
                        placeholderText:  "e.g., REFLECT_OUT"
                        onTextChanged:    root.fieldChanged()
                    }
                }

                // Timeout (Seconds) - Dùng StandardSpinBox
                StandardSpinBox {
                    id: timeoutSpinBox
                    Layout.preferredWidth: 140
                    labelText: "Timeout (Seconds)"
                    from: 0
                    to: 86400 // tối đa 24 giờ tính bằng giây
                    // StandardSpinBox tự động phát ra valueChanged()
                    // Nhưng để kích hoạt fieldChanged() của form, ta bắt sự kiện bằng onValueChanged:
                    onValueChanged: root.fieldChanged()
                }
            }
        }
    }
}
