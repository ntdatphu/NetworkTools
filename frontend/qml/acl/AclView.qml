pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import NetworkTools

// ── AclView ──────────────────────────────────────────────────────────────────
// Layout tổng của ACL feature.
// Gồm 2 phần xếp dọc:
//   1. AclSubBar — thanh tab chọn loại ACL
//   2. AclForm   — form nhập liệu, danh sách rules và save
// Cấu trúc nhất quán với RoutingView và DhcpView.
// ─────────────────────────────────────────────────────────────────────────────
Rectangle {
    id: aclView

    color: Theme.contentBackground

    // ── Nhận host IP từ ContentArea để pre-fill vào form ──
    property string currentHostIp: ""

    // ── Tab đang active, mặc định là "Standard" ──
    property string currentTab: "Standard"

    ColumnLayout {
        anchors.fill: parent
        spacing:      0

        // ── 1. Thanh tab chọn loại ACL ───────────────────────────────
        AclSubBar {
            Layout.fillWidth: true
            activeTab:        aclView.currentTab
            onTabClicked:     (tabName) => { aclView.currentTab = tabName }
        }

        // ── 2. Form chính ────────────────────────────────────────────
        AclForm {
            Layout.fillWidth:  true
            Layout.fillHeight: true
            currentHostIp:     aclView.currentHostIp
            currentAclType:    aclView.currentTab
        }
    }
}