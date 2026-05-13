pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtQuick.Effects
import NetworkTools

Window {
    id: addDeviceWindow
    width: 440; height: 460
    minimumWidth: 440; maximumWidth: 440
    minimumHeight: 460; maximumHeight: 460
    color: "transparent"
    modality: Qt.ApplicationModal
    flags: Qt.Dialog | Qt.FramelessWindowHint

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

    property bool isEditMode: false
    property var editDeviceData: null
    property int escPressCount: 0

    signal deviceAdded(var deviceData)
    signal deviceEdited(var originalIp, var deviceData)

    // ── ALERTS ─────────────────────────────────────────────
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
        onAccepted: addDeviceWindow.close()
    }

    CustomAlert {
        id: errorDialog
        titleText: "Error"
        isError: true
    }

    // ── ESC TIMER ─────────────────────────────────────────
    Timer {
        id: escResetTimer
        interval: 250
        repeat: false
        onTriggered: escPressCount = 0
    }

    Timer {
        id: successAutoCloseTimer
        interval: 5000
        repeat: false
        onTriggered: {
            if (successDialog.visible) {
                successDialog.accepted()
                successDialog.close()
            }
        }
    }

    // ── HELPERS ───────────────────────────────────────────
    function isAnyDialogOpen() {
        return successDialog.visible || errorDialog.visible
    }

    function handleEnterAction() {
        if (successDialog.visible) {
            successDialog.accepted()
            successDialog.close()
            return
        }

        if (errorDialog.visible) {
            errorDialog.accepted()
            errorDialog.close()
            return
        }

        if (addDeviceWindow.visible && addButton.enabled) {
            addDeviceWindow.submit()
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

        if (!addDeviceWindow.visible)
            return

        escPressCount++

        if (escPressCount >= 2) {
            escPressCount = 0
            escResetTimer.stop()
            addDeviceWindow.close()
            return
        }

        escResetTimer.restart()
    }

    // ── SHORTCUTS ──
    Shortcut {
        sequence: "Return"
        onActivated: addDeviceWindow.handleEnterAction()
    }

    Shortcut {
        sequence: "Enter"
        onActivated: addDeviceWindow.handleEnterAction()
    }

    Shortcut {
        sequence: "Escape"
        onActivated: addDeviceWindow.handleEscapeAction()
    }

    // ── INIT ──
    function resetAndOpen(editMode, data) {
        isEditMode = editMode
        editDeviceData = data

        if (isEditMode && editDeviceData) {
            nameInput.text  = editDeviceData.name || ""
            hostInput.text  = editDeviceData.ip || ""
            portInput.text  = editDeviceData.port || "22"
            userField.text  = editDeviceData.user || ""
            passField.text  = editDeviceData.pass || ""

            const protocols = ["SSH", "TELNET"]
            const idx = protocols.indexOf(editDeviceData.protocol || "SSH")
            if (idx !== -1)
                protocolCombo.currentIndex = idx
        } else {
            nameInput.text = ""
            hostInput.text = ""
            portInput.text = "22"
            userField.text = ""
            passField.text = ""
            protocolCombo.currentIndex = 0
        }

        escPressCount = 0
        escResetTimer.stop()

        x = Screen.width / 2 - width / 2
        y = Screen.height / 2 - height / 2
        addDeviceWindow.show()

        hostInput.forceActiveFocus()
    }

    // ── VALIDATION ────────────────────────────────────────────────
    function validate() {
        const reDomain   = /^(?=.{1,253}$)(?!-)(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,}$/i
        const reIPv4     = /^(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}$/
        const reUsername = /^[A-Za-z0-9_.-]+$/
        const rePass     = /^[^\s]+$/

        const host = hostInput.text.trim()
        const isDomain = reDomain.test(host)
        const isIPv4 = reIPv4.test(host)

        if (!isDomain && !isIPv4) {
            errorDialog.messageText = "Host must be a valid domain name or IPv4 address."
            errorDialog.openAlert()
            hostInput.text = ""
            hostInput.forceActiveFocus()
            return false
        }

        if (isIPv4) {
            const octets = host.split(".").map(Number)
            const isPrivateIPv4 =
                octets[0] === 10 ||
                (octets[0] === 172 && octets[1] >= 16 && octets[1] <= 31) ||
                (octets[0] === 192 && octets[1] === 168)

            if (!isPrivateIPv4) {
                errorDialog.messageText = "IPv4 address must be private (10.x.x.x, 172.16-31.x.x, 192.168.x.x)."
                errorDialog.openAlert()
                hostInput.forceActiveFocus()
                return false
            }
        }

        if (userField.text !== "" && !reUsername.test(userField.text)) {
            errorDialog.messageText = "Invalid username."
            errorDialog.openAlert()
            userField.forceActiveFocus()
            return false
        }

        if (passField.text !== "" && !rePass.test(passField.text)) {
            errorDialog.messageText = "Invalid password."
            errorDialog.openAlert()
            passField.forceActiveFocus()
            return false
        }

        return true
    }

    // ── SUBMIT ──
    function submit() {
        if (!validate())
            return

        const ok = dbManager.addDevice(
            hostInput.text.trim(), nameInput.text,
            protocolCombo.currentText, portInput.text,
            userField.text, passField.text
        )
        dbManager.createFoldersFromDevices()

        if (ok) {
            const newDeviceObj = {
                ip:       hostInput.text.trim(),
                name:     nameInput.text,
                protocol: protocolCombo.currentText,
                port:     portInput.text,
                user:     userField.text,
                pass:     passField.text,
                status:   "disconnected",
                type:     "router"
            }

            addDeviceWindow.deviceAdded(newDeviceObj)

            successDialog.messageText = "Device added/updated successfully:\n" + hostInput.text
            successDialog.openAlert()
        } else {
            errorDialog.messageText = "Device already exists in the database:\n" + hostInput.text
            errorDialog.openAlert()
        }
    }

    // ── UI ──
    Rectangle {
        id: mainContent
        anchors.fill: parent
        anchors.margins: 10
        color: Theme.contentBackground
        border.color: addDeviceWindow.active ? Theme.borderColor2 : Theme.textDisabled
        border.width: 1
        radius: 8

        Behavior on border.color {
            ColorAnimation { duration: Theme.animationDurationFast }
        }

        DragHandler {
            onActiveChanged: if (active) addDeviceWindow.startSystemMove()
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 16

            Text {
                text: isEditMode ? "EDIT DEVICE" : "ADD NEW DEVICE"
                color: Theme.textPrimary
                font.pixelSize: Theme.fontSizeTitle
                font.bold: true
                font.family: Theme.fontFamily
                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: 10
            }

            DeviceFormInput {
                id: hostInput
                labelText: "Host:"
                placeholder: "IP or Domain (192.168.1.1)"
                readOnly: isEditMode
                validator: RegularExpressionValidator { regularExpression: /^[^\s]+$/ }
            }

            DeviceFormInput {
                id: nameInput
                labelText: "Device Name:"
                placeholder: "Core-Switch-01"
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "Protocol:"
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontSizeNormal
                    font.family: Theme.fontFamily
                    Layout.preferredWidth: 100
                }

                ProtocolComboBox {
                    id: protocolCombo
                    isEditMode: addDeviceWindow.isEditMode
                    onPortAutoChanged: (newPort) => { portInput.text = newPort }
                }

                Text {
                    text: "Port:"
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontSizeNormal
                    font.family: Theme.fontFamily
                    Layout.leftMargin: 8
                }

                TextField {
                    id: portInput
                    text: "22"
                    Layout.preferredWidth: 50
                    horizontalAlignment: Text.AlignHCenter
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSizeNormal
                    font.family: Theme.fontFamily

                    background: Rectangle {
                        color: Theme.searchBackground2
                        border.color: portInput.activeFocus ? Theme.accentColor : Theme.borderColor
                        border.width: 1
                        radius: 4
                    }
                    validator: IntValidator {
                            bottom: 1
                            top: 65535
                        }
                }
            }

            DeviceFormInput {
                id: userField
                labelText: "Username:"
                placeholder: "admin"
                validator: RegularExpressionValidator { regularExpression: /^[^\s]+$/ }
            }

            DeviceFormInput {
                id: passField
                labelText: "Password:"
                placeholder: "••••••••"
                echoMode: TextInput.Password
                validator: RegularExpressionValidator { regularExpression: /^[^\s]+$/ }
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Item { Layout.fillWidth: true }

                Rectangle {
                    Layout.preferredWidth: 90
                    Layout.preferredHeight: 32
                    radius: 4
                    color: cancelHover.hovered ? Theme.sideBarItemHover : "transparent"
                    border.color: Theme.borderColor

                    Behavior on color {
                        ColorAnimation { duration: Theme.animationDurationMedium }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "Cancel"
                        color: Theme.textPrimary
                        font.pixelSize: Theme.fontSizeNormal
                        font.family: Theme.fontFamily
                    }

                    HoverHandler { id: cancelHover }
                    TapHandler   { onTapped: addDeviceWindow.close() }
                }

                Rectangle {
                    id: addButton
                    Layout.preferredWidth: 120
                    Layout.preferredHeight: 32
                    radius: 4

                    property bool canAdd: hostInput.text.trim().length > 0

                    enabled: canAdd
                    opacity: canAdd ? 1.0 : 0.6
                    color: canAdd
                           ? (addHover.hovered ? Qt.lighter(Theme.accentColor, 1.2) : Theme.accentColor)
                           : Theme.buttonDisabled

                    Behavior on color {
                        ColorAnimation { duration: Theme.animationDurationFast }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: isEditMode ? "Save Changes" : "Add Device"
                        color: Theme.buttonTextSolid
                        font.pixelSize: Theme.fontSizeNormal
                        font.bold: true
                        font.family: Theme.fontFamily
                    }

                    HoverHandler { id: addHover }
                    TapHandler   { onTapped: addDeviceWindow.submit() }
                }
            }
        }
    }

    // ── Hiệu ứng bóng đổ ─────────────────────────────────────────────
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