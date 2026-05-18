pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import NetworkTools
import "qrc:/qt/qml/NetworkTools/components/utils/ValidationUtils.js" as V

BaseCard {
    id: card
    showArea: false
    processIdLabel: "AS Number"
    processIdPlaceholder: "e.g., 100"

    property int processUid: 0
    property var payload: ({})

    signal cardChanged()

    // ── Xử lý dữ liệu khởi tạo ──────────────────────────────────────────────
    onPayloadChanged: {
        if (!payload) return

        processId = payload.as_number !== undefined ? String(payload.as_number) : ""
        routerId  = payload.router_id !== undefined ? String(payload.router_id) : ""

        autoSummaryCheck.checked    = payload.auto_summary    === true || payload.auto_summary    === 1
        passiveDefaultCheck.checked = payload.passive_default === true || payload.passive_default === 1

        const weights = String(payload.metric_weights || "").trim()
        if (weights !== "" && weights !== "0 1 0 1 0 0") {
            useMetricCheck.checked = true
            metricField.text = weights
        } else {
            useMetricCheck.checked = false
            metricField.text = "0 1 0 1 0 0"
        }

        distInternalField.text = payload.distance_internal !== undefined && payload.distance_internal > 0
            ? String(payload.distance_internal) : ""
        distExternalField.text = payload.distance_external !== undefined && payload.distance_external > 0
            ? String(payload.distance_external) : ""

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

    // ── Dirty Flag signature ─────────────────────────────────────────────────
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
            as_number:         String(processId).trim(),
            router_id:         String(routerId).trim(),
            auto_summary:      autoSummaryCheck.checked,
            passive_default:   passiveDefaultCheck.checked,
            metric_weights:    useMetricCheck.checked ? metricField.text.trim() : "0 1 0 1 0 0",
            distance_internal: distInternalField.text.trim(),
            distance_external: distExternalField.text.trim(),
            networks:          netList
        }
        return JSON.stringify(state)
    }

    onProcessIdChanged: card.cardChanged()
    onRouterIdChanged:  card.cardChanged()

    Connections {
        target: networks
        function onCountChanged() { card.cardChanged() }
        function onDataChanged()  { card.cardChanged() }
    }

    // ── Validate ─────────────────────────────────────────────────────────────
    function validate(strictValidation) {
        const asStr = String(processId).trim()
        if (asStr === "")
            return { ok: false, message: "EIGRP AS Number is required." }
        if (!V.isValidAsNumber(asStr))
            return { ok: false, message: "EIGRP AS Number must be an integer between 1 and 65535." }

        const rIdStr = String(routerId).trim()
        if (rIdStr !== "" && !V.isValidIPv4(rIdStr))
            return { ok: false, message: "Router ID must be a valid IPv4 address." }

        if (useMetricCheck.checked) {
            const metricCheck = V.parseMetricWeights(metricField.text)
            if (!metricCheck.ok)
                return { ok: false, message: metricCheck.reason }
        }

        const distIntStr = distInternalField.text.trim()
        if (distIntStr !== "") {
            const v = parseInt(distIntStr, 10)
            if (isNaN(v) || v < 1 || v > 255)
                return { ok: false, message: "EIGRP internal distance must be between 1 and 255." }
        }

        const distExtStr = distExternalField.text.trim()
        if (distExtStr !== "") {
            const v = parseInt(distExtStr, 10)
            if (isNaN(v) || v < 1 || v > 255)
                return { ok: false, message: "EIGRP external distance must be between 1 and 255." }
        }

        if (networks.count === 0)
            return { ok: false, message: "EIGRP AS " + asStr + " must have at least one network." }

        for (let i = 0; i < networks.count; i++) {
            const row   = networks.get(i)
            const net   = String(row.network).trim()
            const wcard = String(row.wildcard).trim()

            if (net === "" && wcard === "")
                continue

            if (net === "" || wcard === "")
                return { ok: false, message: "Network row " + (i+1) + " in AS " + asStr + " is incomplete." }

            if (!V.isValidIPv4(net) || !V.isValidWildcard(wcard))
                return { ok: false, message: "Network and Wildcard must be valid IPv4 formats in AS " + asStr + "." }
        }

        return { ok: true, message: "" }
    }

    // ── Snapshot để lưu ──────────────────────────────────────────────────────
    function snapshotForSave() {
        const netList = []
        for (let i = 0; i < networks.count; i++) {
            const row = networks.get(i)
            const n = String(row.network).trim()
            const w = String(row.wildcard).trim()
            if (n !== "" && w !== "")
                netList.push({ network: n, wildcard: w })
        }

        const distIntStr = distInternalField.text.trim()
        const distExtStr = distExternalField.text.trim()

        return {
            eigrp_id:          payload && payload.eigrp_id !== undefined ? payload.eigrp_id : 0,
            as_number:         parseInt(String(processId).trim(), 10),
            router_id:         String(routerId).trim(),
            auto_summary:      autoSummaryCheck.checked,
            passive_default:   passiveDefaultCheck.checked,
            metric_weights:    useMetricCheck.checked ? metricField.text.trim() : "0 1 0 1 0 0",
            distance_internal: distIntStr !== "" ? parseInt(distIntStr, 10) : 0,
            distance_external: distExtStr !== "" ? parseInt(distExtStr, 10) : 0,
            networks:          netList
        }
    }

    // ── UI riêng của EIGRP ───────────────────────────────────────────────────
    GridLayout {
        Layout.fillWidth: true
        columns: card.width < 760 ? 2 : 4
        columnSpacing: Theme.spacing16
        rowSpacing: Theme.spacing8

        StandardCheckBox {
            id: autoSummaryCheck
            text: "Auto Summary"
            Layout.alignment: Qt.AlignBottom
            onCheckedChanged: card.cardChanged()
        }

        StandardCheckBox {
            id: passiveDefaultCheck
            text: "Passive Default"
            Layout.alignment: Qt.AlignBottom
            onCheckedChanged: card.cardChanged()
        }

        StandardCheckBox {
            id: useMetricCheck
            text: "Custom Metrics"
            Layout.alignment: Qt.AlignBottom
            onCheckedChanged: card.cardChanged()
        }

        StandardTextField {
            id: metricField
            Layout.fillWidth: true
            Layout.minimumWidth: 160
            labelText: "Metric Weights"
            placeholderText: "0 1 0 1 0 0"
            visible: useMetricCheck.checked
            onTextChanged: card.cardChanged()
        }

        StandardTextField {
            id: distInternalField
            Layout.fillWidth: true
            Layout.minimumWidth: 120
            labelText: "Distance Internal"
            placeholderText: "90"
            onTextChanged: card.cardChanged()
        }

        StandardTextField {
            id: distExternalField
            Layout.fillWidth: true
            Layout.minimumWidth: 120
            labelText: "Distance External"
            placeholderText: "170"
            onTextChanged: card.cardChanged()
        }
    }
}
