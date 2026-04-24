import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

Rectangle {
    id: root

    property var form
    property alias routeText: defaultRouteInput.text
    property bool canSaveDefault: root.form && root.form.canSaveDefaultOnly()

    Layout.fillWidth: true
    Layout.leftMargin: 24
    Layout.rightMargin: 24
    radius: 8
    color: Theme.searchBackground2
    border.color: Theme.borderColor
    border.width: Theme.borderWidth
    implicitHeight: defaultCardLayout.implicitHeight + 16

    function focusInput() {
        defaultRouteInput.forceActiveFocus()
    }

    ColumnLayout {
        id: defaultCardLayout
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        Text {
            text: "Default Route"
            color: Theme.textPrimary
            font.pixelSize: Theme.fontSizeNormal
            font.family: Theme.fontFamily
            font.bold: true
        }

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "ip route 0.0.0.0 0.0.0.0 <next-hop>"
                color: Theme.textSecondary
                font.pixelSize: Theme.fontSizeSmall
                font.family: Theme.fontFamily
                Layout.fillWidth: true
            }

            Rectangle {
                Layout.preferredWidth: 86
                Layout.preferredHeight: 30
                radius: 4
                visible: !root.form.defaultRouteEnabled
                color: addDefaultHover.hovered ? Qt.lighter(Theme.accentColor, 1.2) : Theme.accentColor

                Text {
                    anchors.centerIn: parent
                    text: "+ Add"
                    color: Theme.buttonTextSolid
                    font.pixelSize: Theme.fontSizeSmall
                    font.family: Theme.fontFamily
                    font.bold: true
                }

                HoverHandler { id: addDefaultHover }
                TapHandler {
                    onTapped: {
                        root.form.defaultRouteEnabled = true
                        root.focusInput()
                        root.form.markDirty()
                    }
                }
            }
        }

        Text {
            visible: !root.form.defaultRouteEnabled
            text: "Chua co default route. Nhan + Add de them."
            color: Theme.textSecondary
            font.pixelSize: Theme.fontSizeSmall
            font.family: Theme.fontFamily
        }

        RowLayout {
            visible: root.form.defaultRouteEnabled
            Layout.fillWidth: true
            spacing: 8

            TextField {
                id: defaultRouteInput
                Layout.fillWidth: true
                placeholderText: "e.g., 192.168.1.1"
                color: Theme.textPrimary
                font.pixelSize: 14
                font.family: Theme.fontFamily
                onTextChanged: {
                    root.form.markDirty()
                }
                onAccepted: {
                    if (root.canSaveDefault)
                        root.form.saveDefaultOnly()
                }

                background: Rectangle {
                    color: Theme.contentBackground
                    border.color: defaultRouteInput.activeFocus ? Theme.accentColor : Theme.borderColor
                    border.width: 1
                    radius: 4
                }
            }

            Rectangle {
                Layout.preferredWidth: 78
                Layout.preferredHeight: 32
                radius: 4
                opacity: root.form.hasDefaultChanges() ? 1.0 : 0.45
                color: cancelDefaultHover.hovered ? Theme.sideBarItemHover : "transparent"
                border.color: Theme.borderColor
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "Cancel"
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSizeSmall
                    font.family: Theme.fontFamily
                }

                HoverHandler { id: cancelDefaultHover }
                TapHandler {
                    enabled: root.form.hasDefaultChanges()
                    onTapped: {
                        root.form.cancelDefaultChanges()
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: 78
                Layout.preferredHeight: 32
                radius: 4
                color: clearDefaultHover.hovered ? Theme.sideBarItemHover : "transparent"
                border.color: Theme.borderColor
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "Clear"
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSizeSmall
                    font.family: Theme.fontFamily
                }

                HoverHandler { id: clearDefaultHover }
                TapHandler {
                    onTapped: {
                        root.routeText = ""
                        root.form.defaultRouteEnabled = false
                        if (!root.form.saveDefaultOnly()) {
                            root.form.markDirty()
                        }
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: 104
                Layout.preferredHeight: 32
                radius: 4
                opacity: root.canSaveDefault ? 1.0 : 0.45
                color: root.canSaveDefault
                    ? (saveDefaultHover.hovered ? Qt.lighter(Theme.accentColor, 1.2) : Theme.accentColor)
                    : Theme.borderColor

                Text {
                    anchors.centerIn: parent
                    text: root.form.isSaving ? "Saving..." : "Save Default"
                    color: Theme.buttonTextSolid
                    font.pixelSize: Theme.fontSizeSmall
                    font.family: Theme.fontFamily
                    font.bold: true
                }

                HoverHandler { id: saveDefaultHover }
                TapHandler {
                    enabled: root.canSaveDefault
                    onTapped: {
                        root.form.saveDefaultOnly()
                    }
                }
            }
        }
    }
}
