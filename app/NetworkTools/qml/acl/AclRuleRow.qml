pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import NetworkTools

// ── AclRuleRow ───────────────────────────────────────────────────────────────
// Row hiển thị một rule trong bảng danh sách rules đang chờ lưu.
// Gồm 4 cột: Sequence | Action (badge màu) | Chi tiết rule | Nút Delete.
// Được dùng làm delegate trong ListView của AclForm.
// ─────────────────────────────────────────────────────────────────────────────
Rectangle {
    id: ruleRow

    // ── Dữ liệu hiển thị được truyền từ delegate ngoài ──
    required property int    rowIndex
    required property int    rowSequence
    required property string rowAction      // "Permit" hoặc "Deny"
    required property string rowDetail      // Chuỗi tóm tắt chi tiết rule
    required property string rowAclType     // Loại ACL để tô màu phân biệt nếu cần

    signal deleteClicked(int index)

    Layout.fillWidth: true
    height:           Theme.itemHeight + 4
    radius:           Theme.borderRadius
    color:            rowHover.hovered ? Theme.sideBarItemHover : "transparent"

    RowLayout {
        anchors.fill:        parent
        anchors.leftMargin:  8
        anchors.rightMargin: 8
        spacing:             8

        // ── Cột 1: Sequence ──────────────────────────────────────────
        Text {
            Layout.preferredWidth: 36
            text:                  String(ruleRow.rowSequence)
            color:                 Theme.textSecondary
            font.pixelSize:        Theme.fontSizeSmall
            font.family:           Theme.fontFamily
            horizontalAlignment:   Text.AlignHCenter
            verticalAlignment:     Text.AlignVCenter
        }

        // ── Cột 2: Action badge (Permit = xanh, Deny = đỏ) ──────────
        Rectangle {
            Layout.preferredWidth:  54
            Layout.preferredHeight: Theme.itemHeight - 8
            Layout.alignment:       Qt.AlignVCenter
            radius:                 Theme.borderRadius

            // ── Permit dùng statusConnected, Deny dùng alertError ──
            color: ruleRow.rowAction === "Permit"
                       ? Qt.rgba(
                             Qt.lighter(Theme.statusConnected, 1.0).r,
                             Qt.lighter(Theme.statusConnected, 1.0).g,
                             Qt.lighter(Theme.statusConnected, 1.0).b,
                             0.18
                         )
                       : Qt.rgba(
                             Theme.alertError.r,
                             Theme.alertError.g,
                             Theme.alertError.b,
                             0.18
                         )

            Text {
                anchors.centerIn: parent
                text:             ruleRow.rowAction
                color:            ruleRow.rowAction === "Permit"
                                      ? Theme.statusConnected
                                      : Theme.alertError
                font.pixelSize:   Theme.fontSizeSmall
                font.family:      Theme.fontFamily
                font.bold:        true
            }
        }

        // ── Cột 3: Chi tiết rule ─────────────────────────────────────
        Text {
            Layout.fillWidth:    true
            text:                ruleRow.rowDetail
            color:               Theme.textPrimary
            font.pixelSize:      Theme.fontSizeSmall
            font.family:         Theme.fontFamily
            elide:               Text.ElideRight
            verticalAlignment:   Text.AlignVCenter
        }

        // ── Cột 4: Nút Delete ────────────────────────────────────────
        IconButton {
            Layout.preferredWidth: 24
            Layout.preferredHeight: 24
            Layout.alignment: Qt.AlignVCenter
            buttonSize: 24
            glyph: "✕"
            danger: true
            tooltip: "Delete"
            onClicked: ruleRow.deleteClicked(ruleRow.rowIndex)
        }
    }

    HoverHandler { id: rowHover }
}
