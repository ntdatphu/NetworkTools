pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import NetworkUI
import "qrc:/qt/qml/NetworkUI/qml/shared/ValidationUtils.js" as V

// EigrpProcessCard kế thừa BaseProcessCard
BaseProcessCard {
    id: card
    showArea: false // EIGRP không dùng Area trong cấu hình Network

    property int processUid: 0
    property var payload: ({})

    // Chỉ khai báo signal riêng của card này, removeRequested đã được kế thừa từ BaseProcessCard
    signal cardChanged()

    // ── Xử lý dữ liệu khởi tạo ──────────────────────────────────────────────
    onPayloadChanged: {
        if (!payload) return

        processId = payload.as_number !== undefined ? String(payload.as_number) : ""
        routerId  = payload.router_id !== undefined ? String(payload.router_id) : ""
        ad        = payload.ad        !== undefined ? String(payload.ad)        : "90"

        autoSummaryCheck.checked = payload.auto_summary === true || payload.auto_summary === 1
        passiveDefaultCheck.checked = payload.passive_default === true || payload.passive_default === 1

        const weights = String(payload.metric_weights || "").trim()
        if (weights !== "" && weights !== "0 1 0 1 0 0") {
            useMetricCheck.checked = true
            metricField.text = weights
        } else {
            useMetricCheck.checked = false
            metricField.text = "0 1 0 1 0 0"
        }

        networks.clear()
        const netList = payload.networks || []
        for (let i = 0; i < netList.length; i++) {
            networks.append({
                network:  netList[i].network  || "",
                wildcard: netList[i].wildcard || "",
                area:     ""
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
                wildcard: String(row.wildcard || "").trim()
            })
        }
        const state = {
            as_number:       String(processId).trim(),
            router_id:       String(routerId).trim(),
            ad:              String(ad).trim(),
            auto_summary:    autoSummaryCheck.checked,
            passive_default: passiveDefaultCheck.checked,
            metric_weights:  useMetricCheck.checked ? metricField.text.trim() : "0 1 0 1 0 0",
            networks:        netList
        }
        return JSON.stringify(state)
    }

    // ── Các thuộc tính theo dõi thay đổi ────────────────────────────────────
    onProcessIdChanged: card.cardChanged()
    onRouterIdChanged:  card.cardChanged()
    onAdChanged:        card.cardChanged()

    Connections {
        target: networks
        function onCountChanged() { card.cardChanged() }
        function onDataChanged()  { card.cardChanged() }
    }

    // ── Hàm Validate dữ liệu đầu vào ────────────────────────────────────────
    function validate(strictValidation) {
        const asStr = String(processId).trim()
        if (asStr === "") {
            return { ok: false, message: "EIGRP AS Number is required." }
        }
        if (!V.isValidAsNumber(asStr)) {
            return { ok: false, message: "EIGRP AS Number must be an integer between 1 and 65535." }
        }

        const rIdStr = String(routerId).trim()
        if (rIdStr !== "" && !V.isValidIPv4(rIdStr)) {
            return { ok: false, message: "Router ID must be a valid IPv4 address." }
        }

        const adStr = String(ad).trim()
        if (adStr !== "" && !V.isValidAdValue(adStr)) {
            return { ok: false, message: "AD must be an integer between 1 and 255." }
        }

        if (useMetricCheck.checked) {
            const metricCheck = V.parseMetricWeights(metricField.text)
            if (!metricCheck.ok) {
                return { ok: false, message: metricCheck.reason }
            }
        }

        if (networks.count === 0) {
            return { ok: false, message: "EIGRP AS " + asStr + " must have at least one network." }
        }

        for (let i = 0; i < networks.count; i++) {
            const row = networks.get(i)
            const net = String(row.network).trim()
            const wcard = String(row.wildcard).trim()

            if (net === "" && wcard === "")
                continue

            if (net === "" || wcard === "") {
                return { ok: false, message: "Network row " + (i+1) + " in AS " + asStr + " is incomplete." }
            }

            if (!V.isValidIPv4(net) || !V.isValidWildcard(wcard)) {
                return { ok: false, message: "Network and Wildcard must be valid IPv4 formats in AS " + asStr + "." }
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
            if (n !== "" && w !== "") {
                netList.push({ network: n, wildcard: w })
            }
        }

        return {
            eigrp_id:        payload && payload.eigrp_id !== undefined ? payload.eigrp_id : 0,
            as_number:       parseInt(String(processId).trim(), 10),
            router_id:       String(routerId).trim(),
            ad:              V.normalizeAd(ad, 90),
            auto_summary:    autoSummaryCheck.checked,
            passive_default: passiveDefaultCheck.checked,
            metric_weights:  useMetricCheck.checked ? metricField.text.trim() : "0 1 0 1 0 0",
            networks:        netList
        }
    }

    // ── UI RIÊNG BIỆT CỦA EIGRP (Nhúng vào slot extraControls) ──────────────
    RowLayout {
        spacing: 16
        Layout.fillWidth: true

        StandardCheckBox {
            id: autoSummaryCheck
            text: "Auto Summary"
            onCheckedChanged: card.cardChanged()
        }

        StandardCheckBox {
            id: passiveDefaultCheck
            text: "Passive Default"
            onCheckedChanged: card.cardChanged()
        }

        StandardCheckBox {
            id: useMetricCheck
            text: "Custom Metrics"
            onCheckedChanged: card.cardChanged()
        }

        StandardTextField {
            id: metricField
            Layout.preferredWidth: 150
            placeholderText: "0 1 0 1 0 0"
            visible: useMetricCheck.checked
            onTextChanged: card.cardChanged()
        }
    }
}