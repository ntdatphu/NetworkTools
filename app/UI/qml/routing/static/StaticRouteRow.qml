pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import UI

// ─────────────────────────────────────────────────────────────────────────────
// StaticRouteRow
// Refactor: Đồng bộ 100% với giao diện chuẩn và API của StaticRoutingRoutesCard.
// ─────────────────────────────────────────────────────────────────────────────
RowLayout {
    id: root

    // ── 1. Khai báo ĐẦY ĐỦ các property được truyền từ Card vào ──────────────
    property int    rowIndex
    property string rowNetwork
    property string rowMask
    property string rowNexthop
    property string rowAd
    property int    rowRouteId
    property string rowOriginalNetwork
    property string rowOriginalMask
    property string rowOriginalNexthop
    property string rowOriginalAd
    property int    rowSuccess
    property bool   rowEdited
    property bool   rowCanEdit
    property bool   rowNetworkError
    property bool   rowMaskError
    property bool   rowNexthopError

    // ── 2. Khai báo ĐẦY ĐỦ các signals để gửi ngược ra Card ──────────────────
    signal networkTextChanged(string text)
    signal maskTextChanged(string text)
    signal nextHopTextChanged(string text)
    signal adTextChanged(string text)

    signal changeClicked()
    signal cancelClicked()
    signal deleteClicked()
    signal accepted()

    spacing: Theme.spacing8

    function prefixToSubnetMask(text) {
        const value = String(text || "")
        if (!value.endsWith(" "))
            return ""

        const prefixText = value.trim()
        if (!prefixText.startsWith("/"))
            return ""

        const prefix = Number(prefixText.slice(1))
        if (!Number.isInteger(prefix) || prefix < 0 || prefix > 32)
            return ""

        let maskValue = prefix === 0 ? 0 : (0xffffffff << (32 - prefix)) >>> 0
        return [
            (maskValue >>> 24) & 255,
            (maskValue >>> 16) & 255,
            (maskValue >>> 8) & 255,
            maskValue & 255
        ].join(".")
    }

    // ── 3. CÁC Ô NHẬP LIỆU ───────────────────────────────────────────────────
    StandardTextField {
        id: networkInput
        Layout.fillWidth: true
        Layout.minimumWidth: 120
        placeholderText: qsTr("Network IP")

        text: root.rowNetwork
        readOnly: !root.rowCanEdit

        onTextEdited: function(text) { root.networkTextChanged(text) }
        onAccepted:   root.accepted()
    }

    StandardTextField {
        id: maskInput
        Layout.fillWidth: true
        Layout.minimumWidth: 120
        placeholderText: qsTr("Subnet Mask")

        text: root.rowMask
        readOnly: !root.rowCanEdit

        onTextEdited: function(text) {
            const subnetMask = root.prefixToSubnetMask(text)
            root.maskTextChanged(subnetMask !== "" ? subnetMask : text)
        }
        onAccepted:   root.accepted()
    }

    StandardTextField {
        id: nextHopInput
        Layout.fillWidth: true
        Layout.minimumWidth: 120
        placeholderText: qsTr("Next Hop IP")

        text: root.rowNexthop
        readOnly: !root.rowCanEdit

        onTextEdited: function(text) { root.nextHopTextChanged(text) }
        onAccepted:   root.accepted()
    }

    StandardTextField {
        id: adInput
        Layout.preferredWidth: 80
        placeholderText: qsTr("AD")

        text: root.rowAd
        readOnly: !root.rowCanEdit

        onTextEdited: function(text) { root.adTextChanged(text) }
        onAccepted:   root.accepted()
    }

    // ── 4. CÁC NÚT BẤM VÀ TRẠNG THÁI ─────────────────────────────────────────

    // Icon báo trạng thái (Chưa lưu / Thành công / Lỗi)
    Text {
        visible: !root.rowCanEdit && root.rowRouteId > 0
        text: {
            if (root.rowEdited) return "✎"
            if (root.rowSuccess === 1) return "✓"
            if (root.rowSuccess === -1) return "✕"
            return ""
        }
        color: {
            if (root.rowEdited) return Theme.alertWarning
            if (root.rowSuccess === 1) return Theme.alertSuccess
            return Theme.alertError
        }
        font.pixelSize: Theme.fontSizeNormal
        Layout.alignment: Qt.AlignVCenter
    }

    // Nút Change (Chỉ hiện khi đang xem tĩnh)
    StandardButton {
        visible: !root.rowCanEdit
        type: "Secondary"
        text: qsTr("Change")
        onClicked: root.changeClicked()
    }

    // Nút Cancel (Hiện khi đang nhập hoặc sửa route)
    StandardButton {
        visible: root.rowCanEdit
        type: "Secondary"
        text: qsTr("Cancel")
        onClicked: root.cancelClicked()
    }

    // Nút Delete (Luôn hiện)
    StandardButton {
        type: "Danger"
        text: qsTr("Delete")
        onClicked: root.deleteClicked()
    }
}
