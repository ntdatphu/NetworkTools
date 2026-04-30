pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import NetworkUI

Rectangle {
    id: ospfCard

    required property int processIndex
    property var payload: ({})
    property bool editMode: true
    property bool hydrating: false
    property var originalState: ({})
    property int originalOspfId: 0
    property bool processIdError: false
    property bool routerIdError: false
    property int nextNetworkUid: 1

    signal removeRequested()
    signal cardChanged()

    radius: Theme.cardRadius
    color: Theme.searchBackground2
    border.color: Theme.borderColor
    border.width: Theme.borderWidth
    implicitHeight: cardLayout.implicitHeight + 24

    readonly property bool persisted: originalOspfId > 0
    readonly property bool fieldsEnabled: !persisted || editMode

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
                wildcard: normalizeText(row.wildcard),
                area: normalizeText(row.area)
            })
        }
        return output
    }

    function createNetworkRow(row) {
        const source = row || {}
        const hasArea = source.area !== undefined && source.area !== null && String(source.area).trim() !== ""
        const result = {
            rowUid: nextNetworkUid,
            network: normalizeText(source.network),
            wildcard: normalizeText(source.wildcard),
            area: hasArea ? normalizeText(source.area) : "0",
            networkError: false,
            wildcardError: false,
            areaError: false
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

    function setNetworkErrors(index, networkError, wildcardError, areaError) {
        networkModel.setProperty(index, "networkError", networkError)
        networkModel.setProperty(index, "wildcardError", wildcardError)
        networkModel.setProperty(index, "areaError", areaError)
    }

    function clearValidationState() {
        processIdError = false
        routerIdError = false

        for (let i = 0; i < networkModel.count; i++) {
            setNetworkErrors(i, false, false, false)
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

    function currentNetworks() {
        const rows = []
        for (let i = 0; i < networkModel.count; i++) {
            const row = networkModel.get(i)
            rows.push({
                network: normalizeText(row.network),
                wildcard: normalizeText(row.wildcard),
                area: normalizeText(row.area)
            })
        }
        return rows
    }

    function signatureData() {
        return {
            process_id: normalizeText(processIdField.text),
            router_id: normalizeText(routerIdField.text),
            ad: normalizeText(adField.text),
            default_info: defaultInfoCheck.checked,
            auto_summary: autoSummaryCheck.checked,
            networks: currentNetworks()
        }
    }

    function snapshotForSave() {
        return {
            ospf_id: originalOspfId,
            process_id: parseInt(normalizeText(processIdField.text), 10),
            router_id: normalizeText(routerIdField.text),
            ad: parseInt(normalizeText(adField.text), 10),
            default_info: defaultInfoCheck.checked,
            auto_summary: autoSummaryCheck.checked,
            networks: currentNetworks()
        }
    }

    function hydrateFromPayload(data) {
        const source = data || {}

        hydrating = true
        clearValidationState()

        processIdField.text = source.process_id !== undefined ? String(source.process_id) : ""
        routerIdField.text = source.router_id !== undefined ? String(source.router_id) : ""
        adField.text = source.ad !== undefined && source.ad !== null ? String(source.ad) : "110"
        defaultInfoCheck.checked = Boolean(source.default_info)
        autoSummaryCheck.checked = Boolean(source.auto_summary)

        networkModel.clear()
        const networks = cloneNetworks(source.networks)
        for (let i = 0; i < networks.length; i++) {
            networkModel.append(createNetworkRow(networks[i]))
        }

        originalOspfId = source.ospf_id !== undefined ? Number(source.ospf_id) : 0
        originalState = signatureData()
        editMode = !persisted
        hydrating = false
        cardChanged()
    }

    function restoreOriginal() {
        hydrating = true
        clearValidationState()

        processIdField.text = originalState.process_id !== undefined ? String(originalState.process_id) : ""
        routerIdField.text = originalState.router_id !== undefined ? String(originalState.router_id) : ""
        adField.text = originalState.ad !== undefined ? String(originalState.ad) : "110"
        defaultInfoCheck.checked = Boolean(originalState.default_info)
        autoSummaryCheck.checked = Boolean(originalState.auto_summary)

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

        const processIdText = normalizeText(processIdField.text)
        const routerIdText = normalizeText(routerIdField.text)
        const adText = normalizeText(adField.text)

        const processIdValue = parseInt(processIdText, 10)
        if (processIdText === "" || isNaN(processIdValue) || processIdValue < 1 || processIdValue > 65535) {
            processIdError = true
            return { ok: false, message: "Process ID OSPF phải là số từ 1 đến 65535." }
        }

        if (routerIdText !== "" && !isValidIpv4(routerIdText)) {
            routerIdError = true
            return { ok: false, message: "Router ID phải là địa chỉ IPv4 hợp lệ hoặc để trống." }
        }

        if (adText !== "") {
            const adValue = parseInt(adText, 10)
            if (isNaN(adValue) || adValue < 1 || adValue > 255) {
                return { ok: false, message: "AD OSPF phải nằm trong khoảng 1 đến 255." }
            }
        }

        let validNetworkCount = 0
        for (let i = 0; i < networkModel.count; i++) {
            const row = networkModel.get(i)
            const network = normalizeText(row.network)
            const wildcard = normalizeText(row.wildcard)
            const area = normalizeText(row.area)

            if (network === "" && wildcard === "" && area === "") {
                setNetworkErrors(i, true, true, true)
                return { ok: false, message: "Tat ca o Network, Wildcard va Area deu bat buoc phai nhap." }
            }

            const networkError = network === "" || !isValidIpv4(network)
            const wildcardError = wildcard === "" || !isValidIpv4(wildcard)
            const areaError = area === ""
            setNetworkErrors(i, networkError, wildcardError, areaError)

            if (networkError || wildcardError || areaError) {
                return { ok: false, message: "Mỗi dòng network OSPF cần đủ Network, Wildcard và Area hợp lệ." }
            }

            validNetworkCount += 1
        }

        if (validNetworkCount === 0) {
            return { ok: false, message: "Mỗi process OSPF cần ít nhất một network." }
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
                text: "OSPF Process " + ospfCard.processIndex
                color: Theme.textPrimary
                font.pixelSize: Theme.fontSizeNormal
                font.family: Theme.fontFamily
                font.bold: true
            }

            Rectangle {
                visible: ospfCard.persisted && !ospfCard.editMode
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
                visible: ospfCard.persisted && !ospfCard.editMode
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
                        ospfCard.editMode = true
                        ospfCard.cardChanged()
                    }
                }
            }

            Rectangle {
                visible: ospfCard.persisted && ospfCard.editMode
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
                TapHandler { onTapped: ospfCard.restoreOriginal() }
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
                TapHandler { onTapped: ospfCard.removeRequested() }
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
                    text: "Process ID"
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontSizeSmall
                    font.family: Theme.fontFamily
                }

                Item {
                    Layout.fillWidth: true
                    implicitHeight: processIdField.implicitHeight

                    StandardTextField {
                        id: processIdField
                        anchors.fill: parent
                        placeholderText: "e.g., 1"
                        readOnly: !ospfCard.fieldsEnabled
                        onTextChanged: ospfCard.emitChange()
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        radius: Theme.borderRadius
                        border.color: ospfCard.processIdError ? Theme.alertError : "transparent"
                        border.width: ospfCard.processIdError ? 1 : 0
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
                        readOnly: !ospfCard.fieldsEnabled
                        onTextChanged: ospfCard.emitChange()
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        radius: Theme.borderRadius
                        border.color: ospfCard.routerIdError ? Theme.alertError : "transparent"
                        border.width: ospfCard.routerIdError ? 1 : 0
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            ColumnLayout {
                Layout.preferredWidth: 140
                spacing: 4

                Text {
                    text: "AD"
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontSizeSmall
                    font.family: Theme.fontFamily
                }

                StandardTextField {
                    id: adField
                    Layout.fillWidth: true
                    placeholderText: "110"
                    readOnly: !ospfCard.fieldsEnabled
                    onTextChanged: ospfCard.emitChange()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignBottom
                spacing: 16

                RowLayout {
                    spacing: 8

                    CheckBox {
                        id: defaultInfoCheck
                        enabled: ospfCard.fieldsEnabled
                        onCheckedChanged: ospfCard.emitChange()
                    }

                    Text {
                        text: "Default Information"
                        color: Theme.textPrimary
                        font.pixelSize: Theme.fontSizeNormal
                        font.family: Theme.fontFamily
                    }
                }

                RowLayout {
                    spacing: 8

                    CheckBox {
                        id: autoSummaryCheck
                        enabled: ospfCard.fieldsEnabled
                        onCheckedChanged: ospfCard.emitChange()
                    }

                    Text {
                        text: "Auto Summary"
                        color: Theme.textPrimary
                        font.pixelSize: Theme.fontSizeNormal
                        font.family: Theme.fontFamily
                    }
                }
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
                    opacity: ospfCard.fieldsEnabled ? 1.0 : 0.45
                    color: addNetworkHover.hovered && ospfCard.fieldsEnabled
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
                        enabled: ospfCard.fieldsEnabled
                        onTapped: {
                            networkModel.append(createNetworkRow({}))
                            ospfCard.emitChange()
                        }
                    }
                }
            }

            Text {
                visible: networkModel.count === 0
                Layout.fillWidth: true
                text: ospfCard.fieldsEnabled
                    ? "No OSPF networks. Use + Add to create one."
                    : "No OSPF networks saved for this process."
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
                    required property string area
                    required property bool networkError
                    required property bool wildcardError
                    required property bool areaError

                    Item {
                        Layout.fillWidth: true
                        implicitHeight: networkField.implicitHeight

                        StandardTextField {
                            id: networkField
                            anchors.fill: parent
                            placeholderText: "Network"
                            readOnly: !ospfCard.fieldsEnabled
                            Component.onCompleted: text = network
                            onTextChanged: {
                                const targetIndex = ospfCard.rowIndexByUid(rowUid)
                                if (targetIndex < 0)
                                    return
                                networkModel.setProperty(targetIndex, "network", text)
                                ospfCard.emitChange()
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
                            readOnly: !ospfCard.fieldsEnabled
                            Component.onCompleted: text = wildcard
                            onTextChanged: {
                                const targetIndex = ospfCard.rowIndexByUid(rowUid)
                                if (targetIndex < 0)
                                    return
                                networkModel.setProperty(targetIndex, "wildcard", text)
                                ospfCard.emitChange()
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

                    Item {
                        Layout.preferredWidth: 100
                        implicitHeight: areaField.implicitHeight

                        StandardTextField {
                            id: areaField
                            anchors.fill: parent
                            placeholderText: "Area"
                            readOnly: !ospfCard.fieldsEnabled
                            Component.onCompleted: text = area
                            onTextChanged: {
                                const targetIndex = ospfCard.rowIndexByUid(rowUid)
                                if (targetIndex < 0)
                                    return
                                networkModel.setProperty(targetIndex, "area", text)
                                ospfCard.emitChange()
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            radius: Theme.borderRadius
                            border.color: areaError ? Theme.alertError : "transparent"
                            border.width: areaError ? 1 : 0
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30
                        radius: 4
                        opacity: ospfCard.fieldsEnabled ? 1.0 : 0.45
                        color: deleteNetworkHover.hovered && ospfCard.fieldsEnabled
                            ? Qt.lighter(Theme.alertError, 1.15)
                            : "transparent"
                        border.color: deleteNetworkHover.hovered && ospfCard.fieldsEnabled
                            ? Theme.alertError
                            : Theme.borderColor
                        border.width: Theme.borderWidth

                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            color: deleteNetworkHover.hovered && ospfCard.fieldsEnabled
                                ? Theme.alertError
                                : Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: Theme.fontFamily
                        }

                        HoverHandler { id: deleteNetworkHover }
                        TapHandler {
                            enabled: ospfCard.fieldsEnabled
                            onTapped: {
                                const targetIndex = ospfCard.rowIndexByUid(rowUid)
                                if (targetIndex < 0)
                                    return
                                networkModel.remove(targetIndex)
                                ospfCard.emitChange()
                            }
                        }
                    }
                }
            }
        }
    }
}