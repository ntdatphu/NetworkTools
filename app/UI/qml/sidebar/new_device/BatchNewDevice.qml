pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import QtQuick.Controls.Basic
import QtQuick.Dialogs
import QtQuick.Layouts
import QtQuick.Effects
import UI

Window {
    id: batchWindow
    width: 1280; height: 620
    minimumWidth: 1280; maximumWidth: 1280
    minimumHeight: 620; maximumHeight: 620
    color: "transparent"
    modality: Qt.ApplicationModal
    flags: Qt.Dialog | Qt.FramelessWindowHint

    property int escPressCount: 0
    readonly property var protocolOptions: ["SSH", "TELNET", "NETCONF", "RESTCONF"]
    readonly property var osOptions: ["cisco_ios", "cisco_xe", "cisco_nxos", "cisco_asa", "mikrotik_routeros"]
    readonly property var roleOptions: ["rou", "sw2", "sw3"]
    readonly property var typeOptions: ["router", "sw2", "sw3", "unknown"]
    readonly property int tableColumnSpacing: 6
    readonly property int indexColumnWidth: 34
    readonly property int hostColumnWidth: 154
    readonly property int nameColumnWidth: 120
    readonly property int protocolColumnWidth: 106
    readonly property int portColumnWidth: 58
    readonly property int osColumnWidth: 138
    readonly property int roleColumnWidth: 76
    readonly property int typeColumnWidth: 100
    readonly property int usernameColumnWidth: 110
    readonly property int passwordColumnWidth: 110
    readonly property int actionColumnWidth: 34
    readonly property string defaultOs: "cisco_ios"
    readonly property string defaultRole: "rou"
    readonly property string defaultDeviceType: "router"
    readonly property string sampleFileName: "Template_NetworkTools-MultipleDevices.xlsx"

    signal devicesAdded(var addedDevices, int totalRows, int skipped, bool foldersOk)

    onVisibleChanged: {
        if (!visible) {
            UiState.windowLock = false
            escPressCount = 0
        }
    }

    onClosing: (close) => {
        UiState.windowLock = false
        escPressCount = 0
    }

    CustomAlert {
        id: successDialog
        titleText: "Success"
        isError: false
        onVisibleChanged: {
            if (visible)
                successAutoCloseTimer.restart()
            else
                successAutoCloseTimer.stop()
        }
        onAccepted: batchWindow.close()
    }

    CustomAlert {
        id: errorDialog
        titleText: "Error"
        isError: true
    }

    Timer {
        id: escResetTimer
        interval: 500
        repeat: false
        onTriggered: escPressCount = 0
    }

    Timer {
        id: successAutoCloseTimer
        interval: 2500
        repeat: false
        onTriggered: {
            if (successDialog.visible) {
                successDialog.accepted()
                successDialog.close()
            }
        }
    }

    ListModel { id: rowModel }

    FileDialog {
        id: importDialog
        title: "Import Devices"
        nameFilters: ["Excel workbook (*.xlsx)", "JSON file (*.json)"]
        onAccepted: batchWindow.importDevices(selectedFile)
    }

    FileDialog {
        id: sampleSaveDialog
        title: "Save Sample Excel"
        fileMode: FileDialog.SaveFile
        defaultSuffix: "xlsx"
        nameFilters: ["Excel workbook (*.xlsx)"]
        selectedFile: batchWindow.sampleFileName
        onAccepted: batchWindow.saveSampleFile(selectedFile)
    }

    function protocolIndex(protocol) {
        const idx = protocolOptions.indexOf((protocol || "SSH").toUpperCase())
        return idx >= 0 ? idx : 0
    }

    function comboIndex(options, value, fallbackIndex) {
        const idx = options.indexOf(value || "")
        return idx >= 0 ? idx : fallbackIndex
    }
    function defaultPortForProtocol(protocol) {
        const value = (protocol || "SSH").toUpperCase()
        if (value === "TELNET")
            return "23"
        if (value === "NETCONF")
            return "830"
        if (value === "RESTCONF")
            return "443"
        return "22"
    }

    function resetAndOpen() {
        initRows(5)
        escPressCount = 0
        escResetTimer.stop()

        x = Screen.width / 2 - width / 2
        y = Screen.height / 2 - height / 2
        batchWindow.show()
    }

    function initRows(count) {
        rowModel.clear()
        for (let i = 0; i < count; i++) {
            rowModel.append({
                host: "",
                name: "",
                protocol: "SSH",
                port: "22",
                username: "",
                password: "",
                os: batchWindow.defaultOs,
                role: batchWindow.defaultRole,
                type: batchWindow.defaultDeviceType
            })
        }
    }

    function addEmptyRow() {
        rowModel.append({
            host: "",
            name: "",
            protocol: "SSH",
            port: "22",
            username: "",
            password: "",
            os: batchWindow.defaultOs,
            role: batchWindow.defaultRole,
            type: batchWindow.defaultDeviceType
        })
    }

    function clearRows() {
        initRows(5)
    }

    function removeRow(rowIndex) {
        if (rowModel.count <= 1) {
            rowModel.setProperty(rowIndex, "host", "")
            rowModel.setProperty(rowIndex, "name", "")
            rowModel.setProperty(rowIndex, "protocol", "SSH")
            rowModel.setProperty(rowIndex, "port", "22")
            rowModel.setProperty(rowIndex, "username", "")
            rowModel.setProperty(rowIndex, "password", "")
            rowModel.setProperty(rowIndex, "os", batchWindow.defaultOs)
            rowModel.setProperty(rowIndex, "role", batchWindow.defaultRole)
            rowModel.setProperty(rowIndex, "type", batchWindow.defaultDeviceType)
            return
        }

        rowModel.remove(rowIndex)
    }

    function collectRows() {
        const rows = []

        for (let i = 0; i < rowModel.count; i++) {
            const r = rowModel.get(i)
            const line = {
                lineNumber: i + 1,
                host: (r.host || "").trim(),
                name: (r.name || "").trim(),
                protocol: (r.protocol || "SSH").trim(),
                port: (r.port || "").trim(),
                username: (r.username || "").trim(),
                password: (r.password || "").trim(),
                os: (r.os || batchWindow.defaultOs).trim(),
                role: (r.role || batchWindow.defaultRole).trim(),
                type: (r.type || batchWindow.defaultDeviceType).trim()
            }

            if (line.host === "" && line.name === "" && line.username === "" && line.password === "")
                continue

            rows.push(line)
        }

        return rows
    }

    function validateAndNormalize(row) {
        const reDomain = /^(?=.{1,253}$)(?!-)(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,}$/i
        const reIPv4 = /^(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}$/
        const reUsername = /^[A-Za-z0-9_.-]+$/
        const rePass = /^[^\s]+$/

        const host = row.host
        const isDomain = reDomain.test(host)
        const isIPv4 = reIPv4.test(host)

        if (!host || (!isDomain && !isIPv4)) {
            return {
                ok: false,
                message: "Line %1: Host must be a valid domain name or IPv4 address.".arg(row.lineNumber)
            }
        }

        if (isIPv4) {
            const octets = host.split(".").map(Number)
            const isPrivateIPv4 =
                octets[0] === 10 ||
                (octets[0] === 172 && octets[1] >= 16 && octets[1] <= 31) ||
                (octets[0] === 192 && octets[1] === 168)

            if (!isPrivateIPv4) {
                return {
                    ok: false,
                    message: "Line %1: IPv4 address must be private (10.x.x.x, 172.16-31.x.x, 192.168.x.x).".arg(row.lineNumber)
                }
            }
        }

        const protocol = row.protocol.toUpperCase()
        if (protocol !== "SSH" && protocol !== "TELNET" && protocol !== "NETCONF" && protocol !== "RESTCONF") {
            return {
                ok: false,
                message: "Line %1: Protocol must be SSH, TELNET, NETCONF, or RESTCONF.".arg(row.lineNumber)
            }
        }

        if (row.username !== "" && !reUsername.test(row.username)) {
            return {
                ok: false,
                message: "Line %1: Invalid username.".arg(row.lineNumber)
            }
        }

        if (row.password !== "" && !rePass.test(row.password)) {
            return {
                ok: false,
                message: "Line %1: Invalid password.".arg(row.lineNumber)
            }
        }

        let portNumber = Number(row.port)
        if (row.port === "")
            portNumber = Number(defaultPortForProtocol(protocol))

        if (!Number.isInteger(portNumber) || portNumber < 1 || portNumber > 65535) {
            return {
                ok: false,
                message: "Line %1: Port must be an integer in range 1-65535.".arg(row.lineNumber)
            }
        }

        return {
            ok: true,
            row: {
                host: host,
                name: row.name,
                protocol: protocol,
                port: String(portNumber),
                username: row.username,
                password: row.password,
                os: row.os || batchWindow.defaultOs,
                role: row.role || batchWindow.defaultRole,
                type: row.type || batchWindow.defaultDeviceType
            }
        }
    }

    function importDevices(fileUrl) {
        const result = dbManager.importDevicesFromFile(String(fileUrl))
        batchWindow.handleImportResult(result)
    }

    function handleImportResult(result) {
        const message = result && result.message ? String(result.message) : "Import finished."
        if (result && result.ok) {
            batchWindow.devicesAdded([], result.added || 0, result.skipped || 0, result.foldersOk !== false)
            successDialog.messageText = message
            successDialog.openAlert()
        } else {
            errorDialog.messageText = message
            errorDialog.openAlert()
        }
    }

    function saveSampleFile(fileUrl) {
        const result = dbManager.saveDeviceImportSample(String(fileUrl))
        const message = result && result.message ? String(result.message) : "Sample export finished."
        if (result && result.ok) {
            successDialog.messageText = message
            successDialog.openAlert()
        } else {
            errorDialog.messageText = message
            errorDialog.openAlert()
        }
    }

    function submitBatch() {
        const rows = collectRows()
        if (rows.length === 0) {
            errorDialog.messageText = "No input rows found. Fill at least one row in the table."
            errorDialog.openAlert()
            return
        }

        const added = []
        let skipped = 0

        for (let i = 0; i < rows.length; i++) {
            const check = validateAndNormalize(rows[i])
            if (!check.ok) {
                errorDialog.messageText = check.message
                errorDialog.openAlert()
                return
            }

            const item = check.row
            const ok = dbManager.addDevice(
                item.host,
                item.name,
                item.protocol,
                item.port,
                item.username,
                item.password,
                item.os,
                item.role,
                item.type
            )

            if (ok) {
                added.push({
                    ip: item.host,
                    name: item.name,
                    protocol: item.protocol,
                    port: item.port,
                    user: item.username,
                    pass: item.password,
                    os: item.os,
                    role: item.role,
                    status: "disconnected",
                    type: item.type
                })
            } else {
                skipped++
            }
        }

        const foldersOk = added.length > 0 ? dbManager.createFoldersFromDevices() : true

        if (added.length > 0) {
            batchWindow.devicesAdded(added, rows.length, skipped, foldersOk)
            successDialog.messageText = "Added %1/%2 devices. Skipped (already exists): %3".arg(added.length).arg(rows.length).arg(skipped)
            if (!foldersOk)
                successDialog.messageText += "\nBackup folder creation failed."
            if (!foldersOk)
            successDialog.openAlert()
        } else {
            errorDialog.messageText = "No device was added. All rows were skipped (already exists)."
            errorDialog.openAlert()
        }
    }

    function handleEscapeAction() {
        if (successDialog.visible) {
            successDialog.close()
            return
        }

        if (errorDialog.visible) {
            errorDialog.close()
            return
        }

        if (!batchWindow.visible)
            return

        escPressCount++

        if (escPressCount >= 2) {
            escPressCount = 0
            escResetTimer.stop()
            batchWindow.close()
            return
        }

        escResetTimer.restart()
    }

    Shortcut {
        sequence: "Ctrl+Shift+N"
        onActivated: if (batchWindow.visible) batchWindow.submitBatch()
    }

    Shortcut {
        sequence: "Ctrl+Enter"
        onActivated: if (batchWindow.visible) batchWindow.submitBatch()
    }

    Shortcut {
        sequence: "Escape"
        onActivated: batchWindow.handleEscapeAction()
    }

    Rectangle {
        id: mainContent
        anchors.fill: parent
        anchors.margins: 10
        color: Theme.contentBackground
        border.color: batchWindow.active ? Theme.borderColor2 : Theme.textDisabled
        border.width: 1
        radius: 8

        DragHandler {
            onActiveChanged: if (active) batchWindow.startSystemMove()
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: Theme.spacing12

            DialogTitleBar {
                Layout.fillWidth: true
                title: "Add Multiple Devices"
                closeTooltip: "Close batch device form"
                onCloseRequested: batchWindow.close()
            }

            DataTableFrame {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: Theme.spacing8

                    DataTableHeader {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Theme.tableHeaderHeight

                        RowLayout {
                            anchors.fill: parent
                            spacing: batchWindow.tableColumnSpacing

                            DataTableCell { Layout.preferredWidth: batchWindow.indexColumnWidth; header: true; text: "#"; horizontalAlignment: Text.AlignHCenter }
                            DataTableCell { Layout.preferredWidth: batchWindow.hostColumnWidth; header: true; text: "Host *" }
                            DataTableCell { Layout.preferredWidth: batchWindow.nameColumnWidth; header: true; text: "Name" }
                            DataTableCell { Layout.preferredWidth: batchWindow.protocolColumnWidth; header: true; text: "Protocol" }
                            DataTableCell { Layout.preferredWidth: batchWindow.portColumnWidth; header: true; text: "Port"; horizontalAlignment: Text.AlignHCenter }
                            DataTableCell { Layout.preferredWidth: batchWindow.osColumnWidth; header: true; text: "OS" }
                            DataTableCell { Layout.preferredWidth: batchWindow.roleColumnWidth; header: true; text: "Role" }
                            DataTableCell { Layout.preferredWidth: batchWindow.typeColumnWidth; header: true; text: "Device Type" }
                            DataTableCell { Layout.preferredWidth: batchWindow.usernameColumnWidth; header: true; text: "Username" }
                            DataTableCell { Layout.preferredWidth: batchWindow.passwordColumnWidth; header: true; text: "Password" }
                            DataTableCell { Layout.preferredWidth: batchWindow.actionColumnWidth; header: true; text: "" }
                        }
                    }

                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 0
                        model: rowModel

                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                        }

                        delegate: DataTableRow {
                            required property int index
                            required property string host
                            required property string name
                            required property string protocol
                            required property string port
                            required property string username
                            required property string password
                            required property string os
                            required property string role
                            required property string type

                            width: ListView.view.width
                            height: Theme.tableRowHeight + Theme.spacing4
                            rowIndex: index
                            interactive: false

                            RowLayout {
                                anchors.fill: parent
                                spacing: batchWindow.tableColumnSpacing

                                DataTableCell {
                                    Layout.preferredWidth: batchWindow.indexColumnWidth
                                    text: String(index + 1)
                                    horizontalAlignment: Text.AlignHCenter
                                }

                                StandardTextField {
                                    Layout.preferredWidth: batchWindow.hostColumnWidth
                                    text: host
                                    placeholderText: "192.168.1.10"
                                    onTextChanged: rowModel.setProperty(index, "host", text)
                                }

                                StandardTextField {
                                    Layout.preferredWidth: batchWindow.nameColumnWidth
                                    text: name
                                    placeholderText: "Core-R1"
                                    onTextChanged: rowModel.setProperty(index, "name", text)
                                }

                                StandardComboBox {
                                    Layout.preferredWidth: batchWindow.protocolColumnWidth
                                    model: batchWindow.protocolOptions
                                    currentIndex: batchWindow.protocolIndex(protocol)
                                    onCurrentTextChanged: rowModel.setProperty(index, "protocol", currentText)
                                    onActivated: (selectedIndex) => {
                                        const selectedProtocol = batchWindow.protocolOptions[selectedIndex]
                                        rowModel.setProperty(index, "protocol", selectedProtocol)
                                        rowModel.setProperty(index, "port", batchWindow.defaultPortForProtocol(selectedProtocol))
                                    }
                                }

                                StandardTextField {
                                    Layout.preferredWidth: batchWindow.portColumnWidth
                                    text: port
                                    placeholderText: "22"
                                    horizontalAlignment: Text.AlignHCenter
                                    onTextChanged: rowModel.setProperty(index, "port", text)
                                }

                                StandardComboBox {
                                    Layout.preferredWidth: batchWindow.osColumnWidth
                                    model: batchWindow.osOptions
                                    currentIndex: batchWindow.comboIndex(batchWindow.osOptions, os, 0)
                                    onCurrentTextChanged: rowModel.setProperty(index, "os", currentText)
                                }

                                StandardComboBox {
                                    Layout.preferredWidth: batchWindow.roleColumnWidth
                                    model: batchWindow.roleOptions
                                    currentIndex: batchWindow.comboIndex(batchWindow.roleOptions, role, 0)
                                    onCurrentTextChanged: rowModel.setProperty(index, "role", currentText)
                                    onActivated: (selectedIndex) => {
                                        const selectedRole = batchWindow.roleOptions[selectedIndex]
                                        rowModel.setProperty(index, "role", selectedRole)
                                        if (selectedRole === "rou")
                                            rowModel.setProperty(index, "type", "router")
                                        else
                                            rowModel.setProperty(index, "type", selectedRole)
                                    }
                                }

                                StandardComboBox {
                                    Layout.preferredWidth: batchWindow.typeColumnWidth
                                    model: batchWindow.typeOptions
                                    currentIndex: batchWindow.comboIndex(batchWindow.typeOptions, type, 0)
                                    onCurrentTextChanged: rowModel.setProperty(index, "type", currentText)
                                }

                                StandardTextField {
                                    Layout.preferredWidth: batchWindow.usernameColumnWidth
                                    text: username
                                    placeholderText: "admin"
                                    onTextChanged: rowModel.setProperty(index, "username", text)
                                }

                                StandardPasswordField {
                                    Layout.preferredWidth: batchWindow.passwordColumnWidth
                                    text: password
                                    placeholderText: "••••••••"
                                    onTextChanged: rowModel.setProperty(index, "password", text)
                                }

                                IconButton {
                                    Layout.preferredWidth: batchWindow.actionColumnWidth
                                    Layout.alignment: Qt.AlignVCenter
                                    buttonSize: 28
                                    iconSize: Theme.iconSizeSmall
                                    radius: Theme.radiusSmall
                                    iconSource: AppAssets.resource("resources/general/close.svg")
                                    tooltip: "Remove row"
                                    danger: true
                                    enabled: rowModel.count > 1
                                    opacity: enabled ? 1.0 : 0.45
                                    onClicked: batchWindow.removeRow(index)
                                }
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacing8

                StandardButton {
                    text: "Add Row"
                    type: "Secondary"
                    onClicked: addEmptyRow()
                }

                StandardButton {
                    text: "Clear"
                    type: "Secondary"
                    onClicked: clearRows()
                }

                StandardButton {
                    text: "Import"
                    type: "Secondary"
                    onClicked: importDialog.open()
                }

                StandardButton {
                    text: "Get Sample"
                    type: "Secondary"
                    onClicked: {
                        sampleSaveDialog.selectedFile = batchWindow.sampleFileName
                        sampleSaveDialog.open()
                    }
                }

                Item { Layout.fillWidth: true }

                StandardButton {
                    text: "Cancel"
                    type: "Text"
                    onClicked: batchWindow.close()
                }

                StandardButton {
                    id: addAllButton
                    text: "Add All"
                    type: "Primary"
                    enabled: rowModel.count > 0
                    onClicked: batchWindow.submitBatch()
                }
            }
        }
    }

    Component.onCompleted: initRows(5)

    MultiEffect {
        source: mainContent
        anchors.fill: mainContent
        shadowEnabled: true
        shadowColor: Theme.shadowColor
        shadowBlur: 0.8
        shadowHorizontalOffset: 0
        shadowVerticalOffset: 4
    }
}
