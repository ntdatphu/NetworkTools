pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

Rectangle {
    id: root

    property var form
    property alias routeText: defaultRouteInput.text
    property bool canSaveDefault: root.form && root.form.canSaveDefaultOnly()

    Layout.fillWidth: true
    Layout.leftMargin: 24
    Layout.rightMargin: 24
    radius: 8
    color: Theme.contentPanelSurface
    border.color: Theme.contentPanelBorder
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
            text: qsTr("Default Route")
            color: Theme.textPrimary
            font.pixelSize: Theme.fontSizeNormal
            font.family: Theme.fontFamily
            font.bold: true
        }

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: qsTr("ip route 0.0.0.0 0.0.0.0 <next-hop>")
                color: Theme.textSecondary
                font.pixelSize: Theme.fontSizeSmall
                font.family: Theme.fontFamily
                Layout.fillWidth: true
            }

            // Nút Add
            StandardButton {
                visible: !root.form.defaultRouteEnabled
                text: qsTr("+ Add")
                type: "Primary"
                onClicked: {
                    root.form.defaultRouteEnabled = true
                    root.focusInput()
                    root.form.markDirty()
                }
            }
        }

        Text {
            visible: !root.form.defaultRouteEnabled
            text: qsTr("No default route configured. Click + Add to set a default route.")
            color: Theme.textSecondary
            font.pixelSize: Theme.fontSizeSmall
            font.family: Theme.fontFamily
        }

        RowLayout {
            visible: root.form.defaultRouteEnabled
            Layout.fillWidth: true
            spacing: 8

            // Ô nhập liệu
            StandardTextField {
                id: defaultRouteInput
                Layout.fillWidth: true
                placeholderText: qsTr("e.g., 192.168.1.1")
                onTextChanged: root.form.markDirty()
                onAccepted: {
                    if (root.canSaveDefault)
                        root.form.saveDefaultOnly()
                }
            }

            // Nút Cancel
            StandardButton {
                text: qsTr("Cancel")
                type: "Secondary"
                enabled: root.form.hasDefaultChanges()
                onClicked: root.form.cancelDefaultChanges()
            }

            // Nút Clear
            StandardButton {
                text: qsTr("Clear")
                type: "Secondary"
                onClicked: {
                    root.routeText = ""
                    root.form.markDirty()
                }
            }

            // Nút Save
            StandardButton {
                text: root.form.isSaving ? qsTr("Saving...") : qsTr("Save Default")
                type: "Primary"
                enabled: root.canSaveDefault
                onClicked: root.form.saveDefaultOnly()
            }
        }
    }
}
