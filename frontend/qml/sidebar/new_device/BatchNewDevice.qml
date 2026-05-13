pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtQuick.Effects
import NetworkTools

Window {
    id: batchWindow
    width: 900; height: 620
    minimumWidth: 900; maximumWidth: 900
    minimumHeight: 620; maximumHeight: 620
    color: "transparent"
    modality: Qt.ApplicationModal
    flags: Qt.Dialog | Qt.FramelessWindowHint

    property int escPressCount: 0

    signal devicesAdded(var addedDevices)

    onVisibleChanged: {
        if (!visible) {
            Theme.windowLock = false
            escPressCount = 0
        }
    }

    onClosing: (close) => {
        Theme.windowLock = false
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

    function resetAndOpen() {
        initRows(2)
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
                password: ""
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
            password: ""
        })
    }

    function clearRows() {
        initRows(2)
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
                password: (r.password || "").trim()
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
                message: "Line " + row.lineNumber + ": Host must be a valid domain name or IPv4 address."
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
                    message: "Line " + row.lineNumber + ": IPv4 address must be private (10.x.x.x, 172.16-31.x.x, 192.168.x.x)."
                }
            }
        }

        const protocol = row.protocol.toUpperCase()
        if (protocol !== "SSH" && protocol !== "TELNET") {
            return {
                ok: false,
                message: "Line " + row.lineNumber + ": Protocol must be SSH or TELNET."
            }
        }

        if (row.username !== "" && !reUsername.test(row.username)) {
            return {
                ok: false,
                message: "Line " + row.lineNumber + ": Invalid username."
            }
        }

        if (row.password !== "" && !rePass.test(row.password)) {
            return {
                ok: false,
                message: "Line " + row.lineNumber + ": Invalid password."
            }
        }

        let portNumber = Number(row.port)
        if (row.port === "")
            portNumber = protocol === "TELNET" ? 23 : 22

        if (!Number.isInteger(portNumber) || portNumber < 1 || portNumber > 65535) {
            return {
                ok: false,
                message: "Line " + row.lineNumber + ": Port must be an integer in range 1-65535."
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
                password: row.password
            }
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
                item.password
            )

            if (ok) {
                added.push({
                    ip: item.host,
                    name: item.name,
                    protocol: item.protocol,
                    port: item.port,
                    user: item.username,
                    pass: item.password,
                    status: "disconnected",
                    type: "router"
                })
            } else {
                skipped++
            }
        }

        dbManager.createFoldersFromDevices()

        if (added.length > 0) {
            batchWindow.devicesAdded(added)
            successDialog.messageText = "Added " + added.length + "/" + rows.length + " devices. Skipped (already exists): " + skipped
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

        Behavior on border.color {
            ColorAnimation { duration: Theme.animationDurationFast }
        }

        DragHandler {
            onActiveChanged: if (active) batchWindow.startSystemMove()
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 10

            Text {
                text: "ADD MULTIPLE DEVICES"
                color: Theme.textPrimary
                font.pixelSize: Theme.fontSizeTitle
                font.bold: true
                font.family: Theme.fontFamily
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: Theme.textSecondary
                font.pixelSize: Theme.fontSizeSmall
                font.family: Theme.fontFamily
                text: "Nhap theo dang bang nhu Excel: Host, Name, Protocol, Port, Username, Password"
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 6
                color: Theme.searchBackground2
                border.width: 1
                border.color: Theme.borderColor

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 6

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        color: Theme.sideBarBackground
                        radius: 4
                        border.color: Theme.borderColor

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 8

                            Text { Layout.preferredWidth: 40; text: "#"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSmall; font.family: Theme.fontFamily }
                            Text { Layout.preferredWidth: 190; text: "Host"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSmall; font.family: Theme.fontFamily }
                            Text { Layout.preferredWidth: 130; text: "Name"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSmall; font.family: Theme.fontFamily }
                            Text { Layout.preferredWidth: 90; text: "Protocol"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSmall; font.family: Theme.fontFamily }
                            Text { Layout.preferredWidth: 70; text: "Port"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSmall; font.family: Theme.fontFamily }
                            Text { Layout.preferredWidth: 130; text: "Username"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSmall; font.family: Theme.fontFamily }
                            Text { Layout.fillWidth: true; text: "Password"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSmall; font.family: Theme.fontFamily }
                        }
                    }

                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 6
                        model: rowModel

                        delegate: Rectangle {
                            required property int index
                            required property string host
                            required property string name
                            required property string protocol
                            required property string port
                            required property string username
                            required property string password

                            width: ListView.view.width
                            height: 34
                            radius: 4
                            color: Theme.contentBackground
                            border.color: Theme.borderColor

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 8

                                Text {
                                    Layout.preferredWidth: 40
                                    text: String(index + 1)
                                    color: Theme.textSecondary
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.family: Theme.fontFamily
                                }

                                TextField {
                                    Layout.preferredWidth: 190
                                    text: host
                                    placeholderText: "192.168.1.10"
                                    onTextChanged: rowModel.setProperty(index, "host", text)
                                }

                                TextField {
                                    Layout.preferredWidth: 130
                                    text: name
                                    placeholderText: "Core-R1"
                                    onTextChanged: rowModel.setProperty(index, "name", text)
                                }

                                ComboBox {
                                    Layout.preferredWidth: 90
                                    model: ["SSH", "TELNET"]
                                    currentIndex: protocol === "TELNET" ? 1 : 0
                                    onCurrentTextChanged: rowModel.setProperty(index, "protocol", currentText)
                                }

                                TextField {
                                    Layout.preferredWidth: 70
                                    text: port
                                    placeholderText: "22"
                                    horizontalAlignment: Text.AlignHCenter
                                    onTextChanged: rowModel.setProperty(index, "port", text)
                                }

                                TextField {
                                    Layout.preferredWidth: 130
                                    text: username
                                    placeholderText: "admin"
                                    onTextChanged: rowModel.setProperty(index, "username", text)
                                }

                                TextField {
                                    Layout.fillWidth: true
                                    text: password
                                    placeholderText: "password"
                                    echoMode: TextInput.Password
                                    onTextChanged: rowModel.setProperty(index, "password", text)
                                }
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Item { Layout.fillWidth: true }

                Rectangle {
                    Layout.preferredWidth: 110
                    Layout.preferredHeight: 32
                    radius: 4
                    color: cancelHover.hovered ? Theme.sideBarItemHover : "transparent"
                    border.color: Theme.borderColor

                    Text {
                        anchors.centerIn: parent
                        text: "Cancel"
                        color: Theme.textPrimary
                        font.pixelSize: Theme.fontSizeNormal
                        font.family: Theme.fontFamily
                    }

                    HoverHandler { id: cancelHover }
                    TapHandler { onTapped: batchWindow.close() }
                }

                Rectangle {
                    Layout.preferredWidth: 110
                    Layout.preferredHeight: 32
                    radius: 4
                    color: addRowHover.hovered ? Theme.sideBarItemHover : "transparent"
                    border.color: Theme.borderColor

                    Text {
                        anchors.centerIn: parent
                        text: "Add Row"
                        color: Theme.textPrimary
                        font.pixelSize: Theme.fontSizeNormal
                        font.family: Theme.fontFamily
                    }

                    HoverHandler { id: addRowHover }
                    TapHandler { onTapped: addEmptyRow() }
                }

                Rectangle {
                    Layout.preferredWidth: 110
                    Layout.preferredHeight: 32
                    radius: 4
                    color: clearHover.hovered ? Theme.sideBarItemHover : "transparent"
                    border.color: Theme.borderColor

                    Text {
                        anchors.centerIn: parent
                        text: "Clear"
                        color: Theme.textPrimary
                        font.pixelSize: Theme.fontSizeNormal
                        font.family: Theme.fontFamily
                    }

                    HoverHandler { id: clearHover }
                    TapHandler { onTapped: clearRows() }
                }

                Rectangle {
                    id: addAllButton
                    Layout.preferredWidth: 140
                    Layout.preferredHeight: 32
                    radius: 4

                    property bool canSubmit: rowModel.count > 0

                    enabled: canSubmit
                    opacity: canSubmit ? 1.0 : 0.6
                    color: canSubmit
                           ? (addHover.hovered ? Qt.lighter(Theme.accentColor, 1.2) : Theme.accentColor)
                           : Theme.buttonDisabled

                    Text {
                        anchors.centerIn: parent
                        text: "Add All"
                        color: Theme.buttonTextSolid
                        font.pixelSize: Theme.fontSizeNormal
                        font.bold: true
                        font.family: Theme.fontFamily
                    }

                    HoverHandler { id: addHover }
                    TapHandler { onTapped: batchWindow.submitBatch() }
                }
            }
        }
    }

    Component.onCompleted: initRows(12)

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
