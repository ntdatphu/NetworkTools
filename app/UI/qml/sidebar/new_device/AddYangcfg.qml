pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtQuick.Effects
import UI

Window {
    id: addYangcfgWindow
    width: 480; height: 360
    minimumWidth: 480; maximumWidth: 480
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
        titleText: "Success"
        isError: false
        onAccepted: addYangcfgWindow.close()
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
    function validate() {
        const reUsername = /^[A-Za-z0-9_.-]+$/
        const rePass = /^[^\s]+$/

        if (hostInput.text.trim() === "") {
            errorDialog.messageText = "Host is required."
            errorDialog.openAlert()
            return false
        }

        if (userField.text.trim() === "") {
            errorDialog.messageText = "Username is required."
            errorDialog.openAlert()
            userField.forceActiveFocus()
            return false
        }

        if (!reUsername.test(userField.text.trim())) {
            errorDialog.messageText = "Invalid username."
            errorDialog.openAlert()
            userField.forceActiveFocus()
            return false
        }

        if (passField.text.trim() === "") {
            errorDialog.messageText = "Password is required."
            errorDialog.openAlert()
            passField.forceActiveFocus()
            return false
        }

        if (!rePass.test(passField.text)) {
            errorDialog.messageText = "Invalid password."
            errorDialog.openAlert()
            passField.forceActiveFocus()
            return false
        }
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
            successDialog.messageText = "Yangcfg added successfully:\n" + hostInput.text.trim()
            successDialog.openAlert()
        } else {
            errorDialog.messageText = "Failed to add yangcfg for:\n" + hostInput.text.trim()
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
                title: "Add Yangcfg"
                closeTooltip: "Close yangcfg form"
                onCloseRequested: addYangcfgWindow.close()
            }

            DeviceFormInput {
                id: hostInput
                labelText: "Host:"
                placeholder: "192.168.1.1"
                readOnly: true
            }

            DeviceFormInput {
                id: userField
                labelText: "Username:"
                placeholder: "restconf-user"
            }

            StandardPasswordField {
                id: passField
                labelText: "Password:"
                placeholderText: "••••••••"
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Item { Layout.fillWidth: true }

                StandardButton {
                    Layout.preferredWidth: 90
                    Layout.preferredHeight: 32
                    text: "Cancel"
                    type: "Text"
                    onClicked: addYangcfgWindow.close()
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
                        text: "Add Yangcfg"
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
