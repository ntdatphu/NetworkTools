pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import NetworkUI
import "qrc:/qt/qml/NetworkUI/components/utils/ValidationUtils.js" as V

// OspfProcessCard kế thừa BaseProcessCard
BaseCard {
    id: card
    showArea: true

    property int processUid: 0
    property var payload: ({})

    signal cardChanged()
    // ── Xử lý dữ liệu khởi tạo ──────────────────────────────────────────────
    onPayloadChanged: {
        if (!payload) return

        processId = payload.process_id !== undefined ? String(payload.process_id) : ""
        routerId  = payload.router_id  !== undefined ? String(payload.router_id)  : ""
        ad        = payload.ad         !== undefined ? String(payload.ad)         : "110"

        defaultInfoCheck.checked = payload.default_info === true || payload.default_info === 1
        autoSummaryCheck.checked = payload.auto_summary === true || payload.auto_summary === 1

        networks.clear()
        const netList = payload.networks || []
        for (let i = 0; i < netList.length; i++) {
            networks.append({
                network:  netList[i].network  || "",
                wildcard: netList[i].wildcard || "",
                area:     netList[i].area     || ""
            })
        }
    }

    // ── Hàm tạo dữ liệu ký dạng chuỗi để so sánh (Dirty Flag) ──────────────
    function signatureData() {
        const netList = []
        for (let i = 0; i < networks.count; i++) {
            const row = networks.get(i)
            netList.push({
                network:  String(row.network  || "").trim(),
                wildcard: String(row.wildcard || "").trim(),
                area:     String(row.area     || "").trim()
            })
        }
        const state = {
            process_id:   String(processId).trim(),
            router_id:    String(routerId).trim(),
            ad:           String(ad).trim(),
            default_info: defaultInfoCheck.checked,
            auto_summary: autoSummaryCheck.checked,
            networks:     netList
        }
        return JSON.stringify(state)
    }

    // ── Các thuộc tính theo dõi thay đổi ────────────────────────────────────
    onProcessIdChanged: card.cardChanged()
    onRouterIdChanged:  card.cardChanged()
    onAdChanged:        card.cardChanged()

    // Theo dõi thay đổi trong model networks
    Connections {
        target: networks
        function onCountChanged() { card.cardChanged() }
        function onDataChanged()  { card.cardChanged() }
    }

    // ── Hàm Validate dữ liệu đầu vào ────────────────────────────────────────
    function validate(strictValidation) {
        const pIdStr = String(processId).trim()
        if (pIdStr === "") {
            return { ok: false, message: "OSPF Process ID is required." }
        }
        if (!V.isValidOspfProcessId(pIdStr)) {
            return { ok: false, message: "OSPF Process ID must be an integer between 1 and 65535." }
        }

        const rIdStr = String(routerId).trim()
        if (rIdStr !== "" && !V.isValidIPv4(rIdStr)) {
            return { ok: false, message: "Router ID must be a valid IPv4 address." }
        }

        const adStr = String(ad).trim()
        if (adStr !== "" && !V.isValidAdValue(adStr)) {
            return { ok: false, message: "AD must be an integer between 1 and 255." }
        }

        if (networks.count === 0) {
            return { ok: false, message: "Process " + pIdStr + " must have at least one network." }
        }

        for (let i = 0; i < networks.count; i++) {
            const row = networks.get(i)
            const net = String(row.network).trim()
            const wcard = String(row.wildcard).trim()
            const a = String(row.area).trim()

            if (net === "" && wcard === "" && a === "")
                continue

            if (net === "" || wcard === "" || a === "") {
                return { ok: false, message: "Network row " + (i+1) + " in Process " + pIdStr + " is incomplete." }
            }

            if (!V.isValidIPv4(net) || !V.isValidWildcard(wcard)) {
                return { ok: false, message: "Network and Wildcard must be valid IPv4 formats in Process " + pIdStr + "." }
            }
        }

        return { ok: true, message: "" }
    }

    // ── Hàm gom dữ liệu lại để lưu xuống DB ─────────────────────────────────
    function snapshotForSave() {
        const netList = []
        for (let i = 0; i < networks.count; i++) {
            const row = networks.get(i)
            const n = String(row.network).trim()
            const w = String(row.wildcard).trim()
            const a = String(row.area).trim()
            if (n !== "" && w !== "" && a !== "") {
                netList.push({ network: n, wildcard: w, area: a })
            }
        }

        return {
            ospf_id:      payload && payload.ospf_id !== undefined ? payload.ospf_id : 0,
            process_id:   parseInt(String(processId).trim(), 10),
            router_id:    String(routerId).trim(),
            ad:           V.normalizeAd(ad, 110),
            default_info: defaultInfoCheck.checked,
            auto_summary: autoSummaryCheck.checked,
            networks:     netList
        }
    }

    // ── UI RIÊNG BIỆT CỦA OSPF (Nhúng vào slot extraControls) ───────────────
    // Trong BaseProcessCard, chúng ta đã định nghĩa "default property alias extraControls"
    // Nên bất cứ component nào đặt trực tiếp trong card sẽ được nhúng vào vị trí đó.

    RowLayout {
        spacing: 16
        Layout.fillWidth: true

        StandardCheckBox {
            id: defaultInfoCheck
            text: "Default Information Originate"
            onCheckedChanged: card.cardChanged()
        }

        StandardCheckBox {
            id: autoSummaryCheck
            text: "Auto Summary"
            onCheckedChanged: card.cardChanged()
        }
    }
}