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
    property var distance: ({})
    property var tuning: ({})

    signal cardChanged()

    ListModel { id: areasModel }
    ListModel { id: redistributeModel }
    ListModel { id: passiveInterfacesModel }
    ListModel { id: interfaceSettingsModel }

    property alias areas: areasModel
    property alias redistribute: redistributeModel
    property alias passiveInterfaces: passiveInterfacesModel
    property alias interfaceSettings: interfaceSettingsModel

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

        distance = payload.distance || ({})
        tuning = payload.tuning || ({})

        networks.clear()
        const netList = payload.networks || []
        for (let i = 0; i < netList.length; i++) {
            networks.append({
                network:  netList[i].network  || "",
                wildcard: netList[i].wildcard || "",
                area:     netList[i].area     || ""
            })
        }

        areas.clear()
        const areaList = payload.areas || []
        for (let a = 0; a < areaList.length; a++) {
            areas.append({
                area_id: areaList[a].area_id !== undefined ? String(areaList[a].area_id) : "",
                area_type: areaList[a].area_type || "normal",
                no_summary: areaList[a].no_summary === true || areaList[a].no_summary === 1,
                authentication: areaList[a].authentication || "",
                ranges: areaList[a].ranges || []
            })
        }

        redistribute.clear()
        const redistList = payload.redistribute || []
        for (let r = 0; r < redistList.length; r++) {
            redistribute.append({
                protocol: redistList[r].protocol || "static",
                process_id: redistList[r].process_id !== undefined ? String(redistList[r].process_id) : "",
                subnets: redistList[r].subnets === undefined ? true : (redistList[r].subnets === true || redistList[r].subnets === 1),
                metric: redistList[r].metric !== undefined ? String(redistList[r].metric) : "",
                metric_type: redistList[r].metric_type !== undefined ? String(redistList[r].metric_type) : "",
                route_map: redistList[r].route_map || ""
            })
        }

        passiveInterfaces.clear()
        const passiveList = payload.passive_interfaces || []
        for (let p = 0; p < passiveList.length; p++) {
            passiveInterfaces.append({
                interface_name: passiveList[p].interface_name || "",
                passive: passiveList[p].passive === undefined ? true : (passiveList[p].passive === true || passiveList[p].passive === 1)
            })
        }

        interfaceSettings.clear()
        const ifaceList = payload.interface_settings || []
        for (let s = 0; s < ifaceList.length; s++) {
            interfaceSettings.append({
                interface_name: ifaceList[s].interface_name || "",
                area: ifaceList[s].area !== undefined ? String(ifaceList[s].area) : "",
                cost: ifaceList[s].cost !== undefined ? String(ifaceList[s].cost) : "",
                hello_interval: ifaceList[s].hello_interval !== undefined ? String(ifaceList[s].hello_interval) : "",
                dead_interval: ifaceList[s].dead_interval !== undefined ? String(ifaceList[s].dead_interval) : "",
                mtu_ignore: ifaceList[s].mtu_ignore === true || ifaceList[s].mtu_ignore === 1,
                bfd: ifaceList[s].bfd === true || ifaceList[s].bfd === 1,
                network_type: ifaceList[s].network_type || "",
                auth_type: ifaceList[s].auth_type || ""
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
            networks:                 netList,
            distance:                 distance,
            tuning:                   tuning,
            areas:                    modelToArray(areas),
            redistribute:             modelToArray(redistribute),
            passive_interfaces:       modelToArray(passiveInterfaces),
            interface_settings:       modelToArray(interfaceSettings)
        }
        return JSON.stringify(state)
    }

    function modelToArray(model) {
        const rows = []
        for (let i = 0; i < model.count; i++)
            rows.push(model.get(i))
        return rows
    }

    onProcessIdChanged: card.cardChanged()
    onRouterIdChanged:  card.cardChanged()

    Connections {
        target: networks
        function onCountChanged() { card.cardChanged() }
        function onDataChanged()  { card.cardChanged() }
    }

    Connections {
        target: areas
        function onCountChanged() { card.cardChanged() }
        function onDataChanged()  { card.cardChanged() }
    }

    Connections {
        target: redistribute
        function onCountChanged() { card.cardChanged() }
        function onDataChanged()  { card.cardChanged() }
    }

    Connections {
        target: passiveInterfaces
        function onCountChanged() { card.cardChanged() }
        function onDataChanged()  { card.cardChanged() }
    }

    Connections {
        target: interfaceSettings
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

    function intOrZero(value) {
        const n = parseInt(String(value || "").trim(), 10)
        return isNaN(n) ? 0 : n
    }

    function intOrEmpty(value) {
        const str = String(value || "").trim()
        if (str === "")
            return ""
        const n = parseInt(str, 10)
        return isNaN(n) ? "" : n
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
            networks:                 netList,
            distance:                 distance,
            tuning:                   tuning,
            areas:                    modelToArray(areas),
            redistribute:             modelToArray(redistribute),
            passive_interfaces:       modelToArray(passiveInterfaces),
            interface_settings:       modelToArray(interfaceSettings)
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
