pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import NetworkTools

// ── AclRuleInputDynamic ──────────────────────────────────────────────────────
// Box nhập thông tin rule cho Dynamic ACL.
// Gồm 2 phần:
//   1. Phần Extended (Protocol, Source, Destination) — tái sử dụng AclRuleInputExtended
//   2. Phần Dynamic-specific (Dynamic Name + Timeout)
// Được nhúng vào AclForm khi ACL type = "Dynamic".
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

    // ── Properties riêng của Dynamic ──
    property alias dynamicName: dynamicNameField.text
    // Lấy thẳng giá trị value từ StandardSpinBox thay vì text field giả
    property int timeout: timeoutSpinBox.value

    // ── Signal thông báo dữ liệu thay đổi để AclForm theo dõi ──
    signal fieldChanged()

    // ── Hàm xóa sạch toàn bộ input sau khi Add Rule ──
    function clearFields() {
        extendedBox.clearFields()
        dynamicNameField.text = ""
        timeoutSpinBox.value  = 0
    }

    // ── Hàm tạo chuỗi tóm tắt cho cột Detail trong bảng Rules ──
    function buildDetail() {
        const extDetail = extendedBox.buildDetail()
        const dynName   = dynamicNameField.text.trim()
        const tout      = timeoutSpinBox.value

        let dynPart = dynName !== "" ? "  |  dynamic: " + dynName : ""
        if (tout > 0) dynPart += "  timeout: " + tout + "s"

        return extDetail + dynPart
    }

    spacing: 12

    // ── Phần 1: Extended box (tái sử dụng hoàn toàn) ─────────────────
    AclRuleInputExtended {
        id:               extendedBox
        Layout.fillWidth: true
        onFieldChanged:   root.fieldChanged()
    }

    // ── Phần 2: Dynamic-specific box ─────────────────────────────────
    Rectangle {
        Layout.fillWidth: true
        implicitHeight:   dynamicLayout.implicitHeight + 24
        radius:           Theme.cardRadius
        color:            Theme.searchBackground2
        border.color:     Theme.borderColor
        border.width:     Theme.borderWidth

        ColumnLayout {
            id:              dynamicLayout
            anchors.fill:    parent
            anchors.margins: 12
            spacing:         12

            // ── Tiêu đề box ──────────────────────────────────────────
            Text {
                text:                "Dynamic Options"
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

                // Dynamic Name
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing:          4

                    Text {
                        text:           "Dynamic Name"
                        color:          Theme.textSecondary
                        font.pixelSize: Theme.fontSizeSmall
                        font.family:    Theme.fontFamily
                    }

                    StandardTextField {
                        id:               dynamicNameField
                        Layout.fillWidth: true
                        placeholderText:  "e.g., DYNAMIC_ACL"
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
                    onValueChanged: root.fieldChanged()
                }
            }
        }
    }
}