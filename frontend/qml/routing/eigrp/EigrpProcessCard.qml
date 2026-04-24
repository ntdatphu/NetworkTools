pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import NetworkUI

Rectangle {
    id: eigrpCard

    required property int processIndex
    property var payload: ({})
    property bool editMode: true
    property bool hydrating: false
    property var originalState: ({})
    property int originalEigrpId: 0
    property bool asNumberError: false
    property bool routerIdError: false
    property bool metricWeightsError: false
    property int nextNetworkUid: 1

    signal removeRequested()
    signal cardChanged()

    radius: Theme.cardRadius
    color: Theme.searchBackground2
    border.color: Theme.borderColor
    border.width: Theme.borderWidth
    implicitHeight: cardLayout.implicitHeight + 24

    readonly property bool persisted: originalEigrpId > 0
    readonly property bool fieldsEnabled: !persisted || editMode
    readonly property string defaultMetricWeights: "0 1 0 1 0 0"

    ListModel {
        id: networkModel
    }

    function normalizeText(value) {
        return String(value === undefined || value === null ? "" : value).trim()
    }

    function cloneNetworks(rows) {
        const output = []
        const input = rows || []
        for (let i = 0; i < input.length; i++) {
            const row = input[i] || {}
            output.push({
                network: normalizeText(row.network),
                wildcard: normalizeText(row.wildcard)
            })
        }
        return output
    }

    function createNetworkRow(row) {
        const source = row || {}
        const result = {
            rowUid: nextNetworkUid,
            network: normalizeText(source.network),
            wildcard: normalizeText(source.wildcard),
            networkError: false,
            wildcardError: false
        }
        nextNetworkUid += 1
        return result
    }

    function rowIndexByUid(rowUid) {
        for (let i = 0; i < networkModel.count; i++) {
            const row = networkModel.get(i)
            if (Number(row.rowUid) === Number(rowUid))
                return i
        }
        return -1
    }

    function emitChange() {
        if (!hydrating)
            cardChanged()
    }

    function setNetworkErrors(index, networkError, wildcardError) {
        networkModel.setProperty(index, "networkError", networkError)
        networkModel.setProperty(index, "wildcardError", wildcardError)
    }

    function clearValidationState() {
        asNumberError = false
        routerIdError = false
        metricWeightsError = false

        for (let i = 0; i < networkModel.count; i++) {
            setNetworkErrors(i, false, false)
        }
    }

    function isValidIpv4(value) {
        const parts = normalizeText(value).split(".")
        if (parts.length !== 4)
            return false

        for (let i = 0; i < parts.length; i++) {
            if (parts[i] === "")
                return false

            const number = parseInt(parts[i], 10)
            if (isNaN(number) || number < 0 || number > 255)
                return false
        }

        return true
    }

    function parseMetricWeights(value) {
        const tokens = normalizeText(value).split(/\s+/)
        if (tokens.length !== 6)
            return null

        if (tokens[0] !== "0")
            return null

        for (let i = 1; i <= 5; i++) {
            const n = parseInt(tokens[i], 10)
            if (isNaN(n) || n < 0 || n > 255)
                return null
        }

        return {
            k1: tokens[1],
            k2: tokens[2],
            k3: tokens[3],
            k4: tokens[4],
            k5: tokens[5]
        }
    }

    function currentNetworks() {
        const rows = []
        for (let i = 0; i < networkModel.count; i++) {
            const row = networkModel.get(i)
            rows.push({
                network: normalizeText(row.network),
                wildcard: normalizeText(row.wildcard)
            })
        }
        return rows
    }

    function metricWeightsForSave() {
        if (!metricWeightsCheck.checked)
            return defaultMetricWeights

        return "0 "
            + normalizeText(k1Field.text) + " "
            + normalizeText(k2Field.text) + " "
            + normalizeText(k3Field.text) + " "
            + normalizeText(k4Field.text) + " "
            + normalizeText(k5Field.text)
    }

    function signatureData() {
        return {
            as_number: normalizeText(asNumberField.text),
            router_id: normalizeText(routerIdField.text),
            auto_summary: autoSummaryCheck.checked,
            passive_default: passiveDefaultCheck.checked,
            use_metric_weights: metricWeightsCheck.checked,
            k1: normalizeText(k1Field.text),
            k2: normalizeText(k2Field.text),
            k3: normalizeText(k3Field.text),
            k4: normalizeText(k4Field.text),
            k5: normalizeText(k5Field.text),
            metric_weights: metricWeightsForSave(),
            networks: currentNetworks()
        }
    }

    function snapshotForSave() {
        return {
            eigrp_id: originalEigrpId,
            as_number: parseInt(normalizeText(asNumberField.text), 10),
            router_id: normalizeText(routerIdField.text),
            auto_summary: autoSummaryCheck.checked,
            passive_default: passiveDefaultCheck.checked,
            metric_weights: metricWeightsForSave(),
            networks: currentNetworks()
        }
    }

    function hydrateFromPayload(data) {
        const source = data || {}

        hydrating = true
        clearValidationState()

        asNumberField.text = source.as_number !== undefined ? String(source.as_number) : ""
        routerIdField.text = source.router_id !== undefined ? String(source.router_id) : ""
        autoSummaryCheck.checked = Boolean(source.auto_summary)
        passiveDefaultCheck.checked = Boolean(source.passive_default)

        const metricRaw = source.metric_weights !== undefined && source.metric_weights !== null
            ? String(source.metric_weights)
            : defaultMetricWeights
        const parsedMetric = parseMetricWeights(metricRaw)
        const useMetric = source.use_metric_weights !== undefined
            ? Boolean(source.use_metric_weights)
            : normalizeText(metricRaw) !== defaultMetricWeights

        if (parsedMetric) {
            k1Field.text = parsedMetric.k1
            k2Field.text = parsedMetric.k2
            k3Field.text = parsedMetric.k3
            k4Field.text = parsedMetric.k4
            k5Field.text = parsedMetric.k5
        } else {
            k1Field.text = "1"
            k2Field.text = "0"
            k3Field.text = "1"
            k4Field.text = "0"
            k5Field.text = "0"
        }
        metricWeightsCheck.checked = useMetric

        networkModel.clear()
        const networks = cloneNetworks(source.networks)
        for (let i = 0; i < networks.length; i++) {
            networkModel.append(createNetworkRow(networks[i]))
        }

        originalEigrpId = source.eigrp_id !== undefined ? Number(source.eigrp_id) : 0
        originalState = signatureData()
        editMode = !persisted
        hydrating = false
        cardChanged()
    }

    function restoreOriginal() {
        hydrating = true
        clearValidationState()

        asNumberField.text = originalState.as_number !== undefined ? String(originalState.as_number) : ""
        routerIdField.text = originalState.router_id !== undefined ? String(originalState.router_id) : ""
        autoSummaryCheck.checked = Boolean(originalState.auto_summary)
        passiveDefaultCheck.checked = Boolean(originalState.passive_default)
        metricWeightsCheck.checked = Boolean(originalState.use_metric_weights)

        k1Field.text = originalState.k1 !== undefined ? String(originalState.k1) : "1"
        k2Field.text = originalState.k2 !== undefined ? String(originalState.k2) : "0"
        k3Field.text = originalState.k3 !== undefined ? String(originalState.k3) : "1"
        k4Field.text = originalState.k4 !== undefined ? String(originalState.k4) : "0"
        k5Field.text = originalState.k5 !== undefined ? String(originalState.k5) : "0"

        networkModel.clear()
        const networks = cloneNetworks(originalState.networks)
        for (let i = 0; i < networks.length; i++) {
            networkModel.append(createNetworkRow(networks[i]))
        }

        editMode = false
        hydrating = false
        cardChanged()
    }

    function validate(showErrors) {
        clearValidationState()

        const asNumberText = normalizeText(asNumberField.text)
        const routerIdText = normalizeText(routerIdField.text)

        const asNumberValue = parseInt(asNumberText, 10)
        if (asNumberText === "" || isNaN(asNumberValue) || asNumberValue < 1 || asNumberValue > 65535) {
            asNumberError = true
            return { ok: false, message: "AS Number EIGRP phai la so tu 1 den 65535." }
        }

        if (routerIdText !== "" && !isValidIpv4(routerIdText)) {
            routerIdError = true
            return { ok: false, message: "Router ID phai la dia chi IPv4 hop le hoac de trong." }
        }

        if (metricWeightsCheck.checked) {
            const metricFields = [k1Field, k2Field, k3Field, k4Field, k5Field]
            for (let i = 0; i < metricFields.length; i++) {
                const valueText = normalizeText(metricFields[i].text)
                const value = parseInt(valueText, 10)
                if (valueText === "" || isNaN(value) || value < 0 || value > 255) {
                    metricWeightsError = true
                    return { ok: false, message: "K1..K5 phai la so nguyen trong khoang 0 den 255." }
                }
            }
        }

        let validNetworkCount = 0
        for (let i = 0; i < networkModel.count; i++) {
            const row = networkModel.get(i)
            const network = normalizeText(row.network)
            const wildcard = normalizeText(row.wildcard)

            if (network === "" && wildcard === "") {
                setNetworkErrors(i, true, true)
                return { ok: false, message: "Tat ca o Network va Wildcard deu bat buoc phai nhap." }
            }

            const networkError = network === "" || !isValidIpv4(network)
            const wildcardError = wildcard === "" || !isValidIpv4(wildcard)
            setNetworkErrors(i, networkError, wildcardError)

            if (networkError || wildcardError) {
                return { ok: false, message: "Moi dong network EIGRP can Network va Wildcard hop le." }
            }

            validNetworkCount += 1
        }

        if (validNetworkCount === 0) {
            return { ok: false, message: "Moi process EIGRP can it nhat mot network." }
        }

        return { ok: true, message: "" }
    }

    Component.onCompleted: hydrateFromPayload(payload)
    onPayloadChanged: hydrateFromPayload(payload)

    ColumnLayout {
        id: cardLayout
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "EIGRP Process " + eigrpCard.processIndex
                color: Theme.textPrimary
                font.pixelSize: Theme.fontSizeNormal
                font.family: Theme.fontFamily
                font.bold: true
            }

            Rectangle {
                visible: eigrpCard.persisted && !eigrpCard.editMode
                radius: 10
                color: Theme.sideBarItemHover
                implicitWidth: lockText.implicitWidth + 16
                implicitHeight: lockText.implicitHeight + 6

                Text {
                    id: lockText
                    anchors.centerIn: parent
                    text: "Locked"
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontSizeSmall
                    font.family: Theme.fontFamily
                }
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                visible: eigrpCard.persisted && !eigrpCard.editMode
                Layout.preferredWidth: 84
                Layout.preferredHeight: 30
                radius: 4
                color: changeHover.hovered ? Qt.lighter(Theme.accentColor, 1.2) : Theme.accentColor

                Text {
                    anchors.centerIn: parent
                    text: "Change"
                    color: Theme.buttonTextSolid
                    font.pixelSize: Theme.fontSizeSmall
                    font.family: Theme.fontFamily
                    font.bold: true
                }

                HoverHandler { id: changeHover }
                TapHandler {
                    onTapped: {
                        eigrpCard.editMode = true
                        eigrpCard.cardChanged()
                    }
                }
            }

            Rectangle {
                visible: eigrpCard.persisted && eigrpCard.editMode
                Layout.preferredWidth: 84
                Layout.preferredHeight: 30
                radius: 4
                color: cancelHover.hovered ? Qt.lighter(Theme.sideBarItemHover, 1.1) : Theme.sideBarItemHover
                border.color: Theme.borderColor
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "Cancel"
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSizeSmall
                    font.family: Theme.fontFamily
                    font.bold: true
                }

                HoverHandler { id: cancelHover }
                TapHandler { onTapped: eigrpCard.restoreOriginal() }
            }

            Rectangle {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                radius: 4
                color: removeHover.hovered ? Qt.lighter(Theme.alertError, 1.15) : "transparent"
                border.color: removeHover.hovered ? Theme.alertError : Theme.borderColor
                border.width: Theme.borderWidth

                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    color: removeHover.hovered ? Theme.alertError : Theme.textSecondary
                    font.pixelSize: Theme.fontSizeSmall
                    font.family: Theme.fontFamily
                }

                HoverHandler { id: removeHover }
                TapHandler { onTapped: eigrpCard.removeRequested() }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: Theme.borderWidth
            color: Theme.borderColor
            opacity: 0.6
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            ColumnLayout {
                Layout.preferredWidth: 140
                spacing: 4

                Text {
                    text: "AS Number"
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontSizeSmall
                    font.family: Theme.fontFamily
                }

                Item {
                    Layout.fillWidth: true
                    implicitHeight: asNumberField.implicitHeight

                    StandardTextField {
                        id: asNumberField
                        anchors.fill: parent
                        placeholderText: "e.g., 100"
                        readOnly: !eigrpCard.fieldsEnabled
                        onTextChanged: eigrpCard.emitChange()
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        radius: Theme.borderRadius
                        border.color: eigrpCard.asNumberError ? Theme.alertError : "transparent"
                        border.width: eigrpCard.asNumberError ? 1 : 0
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: "Router ID"
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontSizeSmall
                    font.family: Theme.fontFamily
                }

                Item {
                    Layout.fillWidth: true
                    implicitHeight: routerIdField.implicitHeight

                    StandardTextField {
                        id: routerIdField
                        anchors.fill: parent
                        placeholderText: "e.g., 1.1.1.1"
                        readOnly: !eigrpCard.fieldsEnabled
                        onTextChanged: eigrpCard.emitChange()
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        radius: Theme.borderRadius
                        border.color: eigrpCard.routerIdError ? Theme.alertError : "transparent"
                        border.width: eigrpCard.routerIdError ? 1 : 0
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignLeft
            spacing: 16

            RowLayout {
                spacing: 8

                CheckBox {
                    id: autoSummaryCheck
                    enabled: eigrpCard.fieldsEnabled
                    onCheckedChanged: eigrpCard.emitChange()
                }

                Text {
                    text: "Auto Summary"
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSizeNormal
                    font.family: Theme.fontFamily
                }
            }

            RowLayout {
                spacing: 8

                CheckBox {
                    id: passiveDefaultCheck
                    enabled: eigrpCard.fieldsEnabled
                    onCheckedChanged: eigrpCard.emitChange()
                }

                Text {
                    text: "Passive Default"
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSizeNormal
                    font.family: Theme.fontFamily
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            RowLayout {
                spacing: 8

                CheckBox {
                    id: metricWeightsCheck
                    enabled: eigrpCard.fieldsEnabled
                    scale: 0.9
                    onCheckedChanged: eigrpCard.emitChange()
                }

                Text {
                    text: "Metric Weights"
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSizeNormal
                    font.family: Theme.fontFamily
                }

                Text {
                    visible: eigrpCard.metricWeightsError
                    text: "K1..K5 khong hop le"
                    color: Theme.alertError
                    font.pixelSize: Theme.fontSizeSmall
                    font.family: Theme.fontFamily
                }
            }

            RowLayout {
                visible: metricWeightsCheck.checked
                spacing: 8
                Layout.fillWidth: true

                ColumnLayout {
                    Layout.preferredWidth: 70
                    spacing: 4

                    Text {
                        text: "K1"
                        color: Theme.textSecondary
                        font.pixelSize: Theme.fontSizeSmall
                        font.family: Theme.fontFamily
                    }

                    StandardTextField {
                        id: k1Field
                        Layout.fillWidth: true
                        readOnly: !eigrpCard.fieldsEnabled
                        placeholderText: "0-255"
                        onTextChanged: eigrpCard.emitChange()
                    }
                }

                ColumnLayout {
                    Layout.preferredWidth: 70
                    spacing: 4

                    Text {
                        text: "K2"
                        color: Theme.textSecondary
                        font.pixelSize: Theme.fontSizeSmall
                        font.family: Theme.fontFamily
                    }

                    StandardTextField {
                        id: k2Field
                        Layout.fillWidth: true
                        readOnly: !eigrpCard.fieldsEnabled
                        placeholderText: "0-255"
                        onTextChanged: eigrpCard.emitChange()
                    }
                }

                ColumnLayout {
                    Layout.preferredWidth: 70
                    spacing: 4

                    Text {
                        text: "K3"
                        color: Theme.textSecondary
                        font.pixelSize: Theme.fontSizeSmall
                        font.family: Theme.fontFamily
                    }

                    StandardTextField {
                        id: k3Field
                        Layout.fillWidth: true
                        readOnly: !eigrpCard.fieldsEnabled
                        placeholderText: "0-255"
                        onTextChanged: eigrpCard.emitChange()
                    }
                }

                ColumnLayout {
                    Layout.preferredWidth: 70
                    spacing: 4

                    Text {
                        text: "K4"
                        color: Theme.textSecondary
                        font.pixelSize: Theme.fontSizeSmall
                        font.family: Theme.fontFamily
                    }

                    StandardTextField {
                        id: k4Field
                        Layout.fillWidth: true
                        readOnly: !eigrpCard.fieldsEnabled
                        placeholderText: "0-255"
                        onTextChanged: eigrpCard.emitChange()
                    }
                }

                ColumnLayout {
                    Layout.preferredWidth: 70
                    spacing: 4

                    Text {
                        text: "K5"
                        color: Theme.textSecondary
                        font.pixelSize: Theme.fontSizeSmall
                        font.family: Theme.fontFamily
                    }

                    StandardTextField {
                        id: k5Field
                        Layout.fillWidth: true
                        readOnly: !eigrpCard.fieldsEnabled
                        placeholderText: "0-255"
                        onTextChanged: eigrpCard.emitChange()
                    }
                }
            }

            Text {
                visible: metricWeightsCheck.checked
                Layout.fillWidth: true
                text: "metric_weights: " + eigrpCard.metricWeightsForSave()
                color: Theme.textSecondary
                font.pixelSize: Theme.fontSizeSmall
                font.family: Theme.fontFamily
                elide: Text.ElideRight
            }

            Text {
                visible: !metricWeightsCheck.checked
                Layout.fillWidth: true
                text: "metric_weights mac dinh: " + eigrpCard.defaultMetricWeights
                color: Theme.textDisabled
                font.pixelSize: Theme.fontSizeSmall
                font.family: Theme.fontFamily
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "NETWORKS"
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontSizeSmall
                    font.family: Theme.fontFamily
                    font.bold: true
                    font.capitalization: Font.AllUppercase
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    Layout.preferredWidth: 96
                    Layout.preferredHeight: 30
                    radius: 4
                    opacity: eigrpCard.fieldsEnabled ? 1.0 : 0.45
                    color: addNetworkHover.hovered && eigrpCard.fieldsEnabled
                        ? Qt.lighter(Theme.accentColor, 1.2)
                        : Theme.accentColor

                    Text {
                        anchors.centerIn: parent
                        text: "+ Add"
                        color: Theme.buttonTextSolid
                        font.pixelSize: Theme.fontSizeSmall
                        font.family: Theme.fontFamily
                        font.bold: true
                    }

                    HoverHandler { id: addNetworkHover }
                    TapHandler {
                        enabled: eigrpCard.fieldsEnabled
                        onTapped: {
                            networkModel.append(createNetworkRow({}))
                            eigrpCard.emitChange()
                        }
                    }
                }
            }

            Text {
                visible: networkModel.count === 0
                Layout.fillWidth: true
                text: eigrpCard.fieldsEnabled
                    ? "No EIGRP networks. Use + Add to create one."
                    : "No EIGRP networks saved for this process."
                color: Theme.textDisabled
                font.pixelSize: Theme.fontSizeNormal
                font.family: Theme.fontFamily
                horizontalAlignment: Text.AlignHCenter
                topPadding: 4
                bottomPadding: 4
            }

            Repeater {
                model: networkModel

                delegate: RowLayout {
                    required property int rowUid
                    Layout.fillWidth: true
                    spacing: 8

                    required property string network
                    required property string wildcard
                    required property bool networkError
                    required property bool wildcardError

                    Item {
                        Layout.fillWidth: true
                        implicitHeight: networkField.implicitHeight

                        StandardTextField {
                            id: networkField
                            anchors.fill: parent
                            placeholderText: "Network"
                            readOnly: !eigrpCard.fieldsEnabled
                            Component.onCompleted: text = network
                            onTextChanged: {
                                const targetIndex = eigrpCard.rowIndexByUid(rowUid)
                                if (targetIndex < 0)
                                    return
                                networkModel.setProperty(targetIndex, "network", text)
                                eigrpCard.emitChange()
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            radius: Theme.borderRadius
                            border.color: networkError ? Theme.alertError : "transparent"
                            border.width: networkError ? 1 : 0
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        implicitHeight: wildcardField.implicitHeight

                        StandardTextField {
                            id: wildcardField
                            anchors.fill: parent
                            placeholderText: "Wildcard"
                            readOnly: !eigrpCard.fieldsEnabled
                            Component.onCompleted: text = wildcard
                            onTextChanged: {
                                const targetIndex = eigrpCard.rowIndexByUid(rowUid)
                                if (targetIndex < 0)
                                    return
                                networkModel.setProperty(targetIndex, "wildcard", text)
                                eigrpCard.emitChange()
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            radius: Theme.borderRadius
                            border.color: wildcardError ? Theme.alertError : "transparent"
                            border.width: wildcardError ? 1 : 0
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30
                        radius: 4
                        opacity: eigrpCard.fieldsEnabled ? 1.0 : 0.45
                        color: deleteNetworkHover.hovered && eigrpCard.fieldsEnabled
                            ? Qt.lighter(Theme.alertError, 1.15)
                            : "transparent"
                        border.color: deleteNetworkHover.hovered && eigrpCard.fieldsEnabled
                            ? Theme.alertError
                            : Theme.borderColor
                        border.width: Theme.borderWidth

                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            color: deleteNetworkHover.hovered && eigrpCard.fieldsEnabled
                                ? Theme.alertError
                                : Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: Theme.fontFamily
                        }

                        HoverHandler { id: deleteNetworkHover }
                        TapHandler {
                            enabled: eigrpCard.fieldsEnabled
                            onTapped: {
                                const targetIndex = eigrpCard.rowIndexByUid(rowUid)
                                if (targetIndex < 0)
                                    return
                                networkModel.remove(targetIndex)
                                eigrpCard.emitChange()
                            }
                        }
                    }
                }
            }
        }
    }
}
