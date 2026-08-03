pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

StandardDialog {
    id: root

    title: "Global Settings"
    subtitle: "Appearance is available before a project is opened"
    preferredWidth: 560
    implicitHeight: 390

    contentItem: ColumnLayout {
        spacing: Theme.spacing16

        Text {
            text: "Color theme"
            color: Theme.textPrimary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeNormal
            font.bold: true
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing8

            Repeater {
                model: [
                    { "label": "System", "value": ThemeState.system },
                    { "label": "Light", "value": ThemeState.light },
                    { "label": "Dark", "value": ThemeState.dark }
                ]

                delegate: StandardButton {
                    required property var modelData
                    Layout.fillWidth: true
                    text: modelData.label
                    type: "Secondary"
                    checkable: true
                    checked: ThemeState.themeMode === modelData.value
                    onClicked: ThemeState.themeMode = modelData.value
                }
            }
        }

        StandardCheckBox {
            text: "High contrast"
            checked: ThemeState.highContrast
            onToggled: ThemeState.highContrast = checked
        }

        InlineMessage {
            Layout.fillWidth: true
            message: "Additional global settings remain available from the workspace Settings view."
            severity: "info"
        }

        Item { Layout.fillHeight: true }

        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            StandardButton {
                text: "Done"
                type: "Primary"
                onClicked: root.accept()
            }
        }
    }
}
