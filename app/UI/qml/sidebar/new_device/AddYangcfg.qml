pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtQuick.Effects
import UI

Window {
    id: addYangcfgWindow
    width: 420; height: 360
    minimumWidth: 420; maximumWidth: 420
    minimumHeight: 360; maximumHeight: 360
    color: "transparent"
    modality: Qt.ApplicationModal
    flags: Qt.Dialog | Qt.FramelessWindowHint

    property string hostIp: ""
    property int escPressCount: 0

    signal yangcfgAdded(string hostIp)

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
        titleText: qsTr("Success")
        isError: false
        onAccepted: addYangcfgWindow.close()
    }

    CustomAlert {
        id: errorDialog
        titleText: qsTr("Error")
        isError: true
    }

    Timer {
        id: escResetTimer
        interval: 500
        repeat: false
        onTriggered: escPressCount = 0
    }

    Shortcut {
        sequence: "Return"
        onActivated: {
            if (addButton.enabled)
                addYangcfgWindow.submit()
        }
    }

    Shortcut {
        sequence: "Enter"
        onActivated: {
            if (addButton.enabled)
                addYangcfgWindow.submit()
        }
    }

    Shortcut {
        sequence: "Escape"
        onActivated: {
            if (successDialog.visible) {
                successDialog.close()
                return
            }
            if (errorDialog.visible) {
                errorDialog.close()
                return
            }

            escPressCount++
            if (escPressCount >= 2) {
                escPressCount = 0
                escResetTimer.stop()
                addYangcfgWindow.close()
                return
            }
            escResetTimer.restart()
        }
    }

    function resetAndOpen(ip) {
        hostIp = ip || ""
        hostInput.text = hostIp
        userField.text = ""
        passField.text = ""

        escPressCount = 0
        escResetTimer.stop()

        x = Screen.width / 2 - width / 2
        y = Screen.height / 2 - height / 2
        addYangcfgWindow.show()

        userField.forceActiveFocus()
    }

    function logYangcfgEvent(status, message, category) {
        if (typeof appLogger !== "undefined")
            appLogger.log(status, message, "devices", category)
    }

    function validate() {
        const reUsername = /^[A-Za-z0-9_.-]+$/
        const rePass = /^[^\s]+$/

        if (hostInput.text.trim() === "") {
            errorDialog.messageText = qsTr("Host is required.")
            logYangcfgEvent("WARNING", qsTr("Yangcfg validation failed: host is required."), "VALIDATION")
            errorDialog.openAlert()
            return false
        }

        if (userField.text.trim() === "") {
            errorDialog.messageText = qsTr("Username is required.")
            logYangcfgEvent("WARNING", qsTr("Yangcfg validation failed for %1: username is required.").arg(hostInput.text.trim()), "VALIDATION")
            errorDialog.openAlert()
            userField.forceActiveFocus()
            return false
        }

        if (!reUsername.test(userField.text.trim())) {
            errorDialog.messageText = qsTr("Invalid username.")
            logYangcfgEvent("WARNING", qsTr("Yangcfg validation failed for %1: invalid username format.").arg(hostInput.text.trim()), "VALIDATION")
            errorDialog.openAlert()
            userField.forceActiveFocus()
            return false
        }

        if (passField.text.trim() === "") {
            errorDialog.messageText = qsTr("Password is required.")
            logYangcfgEvent("WARNING", qsTr("Yangcfg validation failed for %1: password is required.").arg(hostInput.text.trim()), "VALIDATION")
            errorDialog.openAlert()
            passField.forceActiveFocus()
            return false
        }

        if (!rePass.test(passField.text)) {
            errorDialog.messageText = qsTr("Invalid password.")
            logYangcfgEvent("WARNING", qsTr("Yangcfg validation failed for %1: password must not contain whitespace.").arg(hostInput.text.trim()), "VALIDATION")
            errorDialog.openAlert()
            passField.forceActiveFocus()
            return false
        }

        logYangcfgEvent("SUCCESS", qsTr("Yangcfg validation passed for %1.").arg(hostInput.text.trim()), "VALIDATION")
        return true
    }

    function submit() {
        if (!validate())
            return

        const ok = dbManager.addYangcfg(
            hostInput.text.trim(),
            userField.text.trim(),
            passField.text,
            0
        )

        if (ok) {
            addYangcfgWindow.yangcfgAdded(hostInput.text.trim())
            logYangcfgEvent("SUCCESS", qsTr("Yangcfg added for %1.").arg(hostInput.text.trim()), "CONFIGURATION")
            successDialog.messageText = qsTr("Yangcfg added successfully:\n") + hostInput.text.trim()
            successDialog.openAlert()
        } else {
            errorDialog.messageText = qsTr("Failed to add yangcfg for:\n") + hostInput.text.trim()
            logYangcfgEvent("ERROR", qsTr("Failed to add yangcfg for %1.").arg(hostInput.text.trim()), "CONFIGURATION")
            errorDialog.openAlert()
        }
    }

    Rectangle {
        id: mainContent
        anchors.fill: parent
        anchors.margins: 10
        color: Theme.contentBackground
        border.color: addYangcfgWindow.active ? Theme.borderColor2 : Theme.textDisabled
        border.width: 1
        radius: 8

        DragHandler {
            onActiveChanged: if (active) addYangcfgWindow.startSystemMove()
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 16

            DialogTitleBar {
                Layout.fillWidth: true
                Layout.bottomMargin: 4
                title: qsTr("Add Yangcfg")
                closeTooltip: qsTr("Close yangcfg form")
                onCloseRequested: addYangcfgWindow.close()
            }

            DeviceFormInput {
                id: hostInput
                labelText: qsTr("Host:")
                placeholder: "192.168.1.1"
                readOnly: true
            }

            DeviceFormInput {
                id: userField
                labelText: qsTr("Username:")
                placeholder: qsTr("restconf-user")
            }

            DeviceFormInput {
                id: passField
                labelText: qsTr("Password:")
                placeholder: "••••••••"
                echoMode: TextInput.Password
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

                    Text {
                        anchors.centerIn: parent
                        text: qsTr("Cancel")
                        color: Theme.textPrimary
                        font.pixelSize: Theme.fontSizeNormal
                        font.family: Theme.fontFamily
                    }

                    HoverHandler { id: cancelHover }
                    TapHandler { onTapped: addYangcfgWindow.close() }
                }

                Rectangle {
                    id: addButton
                    Layout.preferredWidth: 120
                    Layout.preferredHeight: 32
                    radius: 4

                    property bool canAdd: hostInput.text.trim() !== "" &&
                                          userField.text.trim() !== "" &&
                                          passField.text.trim() !== ""

                    enabled: canAdd
                    opacity: canAdd ? 1.0 : 0.6
                    color: canAdd
                           ? (addHover.hovered ? Qt.lighter(Theme.accentEmphasis, 1.2) : Theme.accentEmphasis)
                           : Theme.buttonDisabled

                    Text {
                        anchors.centerIn: parent
                        text: qsTr("Add Yangcfg")
                        color: Theme.buttonTextSolid
                        font.pixelSize: Theme.fontSizeNormal
                        font.bold: true
                        font.family: Theme.fontFamily
                    }

                    HoverHandler { id: addHover }
                    TapHandler { onTapped: addYangcfgWindow.submit() }
                }
            }
        }
    }

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
