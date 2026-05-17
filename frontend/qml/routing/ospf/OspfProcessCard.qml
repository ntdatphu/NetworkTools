pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import NetworkTools
import "qrc:/qt/qml/NetworkTools/components/utils/ValidationUtils.js" as V

BaseCard {
    id: card
    showArea: true
    processIdLabel: "Process ID"
    processIdPlaceholder: "e.g., 1"

    property int processUid: 0
    property var payload: ({})

    signal cardChanged()

    // ── Xử lý dữ liệu khởi tạo ──────────────────────────────────────────────
    onPayloadChanged: {
        if (!payload) return

        processId = payload.process_id !== undefined ? String(payload.process_id) : ""
        routerId  = payload.router_id  !== undefined ? String(payload.router_id)  : ""

        refBwField.text = payload.reference_bandwidth !== undefined && payload.reference_bandwidth > 0
            ? String(payload.reference_bandwidth) : ""

        passiveDefaultCheck.checked  = payload.passive_default          === true || payload.passive_default          === 1
        defaultOriginateCheck.checked = payload.default_originate       === true || payload.default_originate        === 1
        defaultAlwaysCheck.checked    = payload.default_originate_always === true || payload.default_originate_always === 1

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

    // ── Dirty Flag signature ─────────────────────────────────────────────────
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
            process_id:               String(processId).trim(),
            router_id:                String(routerId).trim(),
            reference_bandwidth:      refBwField.text.trim(),
            passive_default:          passiveDefaultCheck.checked,
            default_originate:        defaultOriginateCheck.checked,
            default_originate_always: defaultAlwaysCheck.checked,
            networks:                 netList
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
        const pIdStr = String(processId).trim()
        if (pIdStr === "")
            return { ok: false, message: "OSPF Process ID is required." }
        if (!V.isValidOspfProcessId(pIdStr))
            return { ok: false, message: "OSPF Process ID must be an integer between 1 and 65535." }

        const rIdStr = String(routerId).trim()
        if (rIdStr !== "" && !V.isValidIPv4(rIdStr))
            return { ok: false, message: "Router ID must be a valid IPv4 address." }

        const bwStr = refBwField.text.trim()
        if (bwStr !== "") {
            const bwVal = parseInt(bwStr, 10)
            if (isNaN(bwVal) || bwVal < 1)
                return { ok: false, message: "Reference bandwidth must be a positive integer (Mbps)." }
        }

        if (networks.count === 0)
            return { ok: false, message: "Process " + pIdStr + " must have at least one network." }

        for (let i = 0; i < networks.count; i++) {
            const row  = networks.get(i)
            const net  = String(row.network).trim()
            const wcard = String(row.wildcard).trim()
            const a    = String(row.area).trim()

            if (net === "" && wcard === "" && a === "")
                continue

            if (net === "" || wcard === "" || a === "")
                return { ok: false, message: "Network row " + (i+1) + " in Process " + pIdStr + " is incomplete." }

            if (!V.isValidIPv4(net) || !V.isValidWildcard(wcard))
                return { ok: false, message: "Network and Wildcard must be valid IPv4 formats in Process " + pIdStr + "." }
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
            const a = String(row.area).trim()
            if (n !== "" && w !== "" && a !== "")
                netList.push({ network: n, wildcard: w, area: a })
        }

        const bwStr = refBwField.text.trim()
        const bwVal = bwStr !== "" ? parseInt(bwStr, 10) : 0

        return {
            ospf_id:                  payload && payload.ospf_id !== undefined ? payload.ospf_id : 0,
            process_id:               parseInt(String(processId).trim(), 10),
            router_id:                String(routerId).trim(),
            reference_bandwidth:      bwVal > 0 ? bwVal : 0,
            passive_default:          passiveDefaultCheck.checked,
            default_originate:        defaultOriginateCheck.checked,
            default_originate_always: defaultAlwaysCheck.checked && defaultOriginateCheck.checked,
            networks:                 netList
        }
    }

    // ── UI riêng của OSPF ────────────────────────────────────────────────────
    GridLayout {
        Layout.fillWidth: true
        columns: card.width < 680 ? 2 : 4
        columnSpacing: Theme.spacing16
        rowSpacing: Theme.spacing8

        StandardTextField {
            id: refBwField
            Layout.fillWidth: true
            Layout.minimumWidth: 140
            labelText: "Reference BW"
            placeholderText: "e.g. 1000"
            onTextChanged: card.cardChanged()
        }

        StandardCheckBox {
            id: passiveDefaultCheck
            text: "Passive Default"
            Layout.alignment: Qt.AlignBottom
            onCheckedChanged: card.cardChanged()
        }

        StandardCheckBox {
            id: defaultOriginateCheck
            text: "Default Originate"
            Layout.alignment: Qt.AlignBottom
            onCheckedChanged: {
                if (!checked) defaultAlwaysCheck.checked = false
                card.cardChanged()
            }
        }

        StandardCheckBox {
            id: defaultAlwaysCheck
            text: "Always"
            enabled: defaultOriginateCheck.checked
            Layout.alignment: Qt.AlignBottom
            onCheckedChanged: card.cardChanged()
        }
    }
}
