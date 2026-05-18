pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import NetworkTools

Rectangle {
    id: settingsView
    color: Theme.contentBackground
    property string activeSettingKey: "theme"

    Rectangle {
        anchors.fill: parent
        color: Theme.contentSurface
        border.width: Theme.borderWidth
        border.color: Theme.borderColor
    }

    Item {
        anchors.fill: parent
        visible: settingsView.activeSettingKey === "theme"

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 16

            Text {
                text: "Appearance"
                color: Theme.textPrimary
                font.pixelSize: Theme.fontSizeLarge
                font.family: Theme.fontFamily
                font.weight: Font.Bold
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 60
                color: Theme.searchBackground2
                radius: Theme.borderRadius
                border.width: Theme.borderWidth
                border.color: Theme.borderColor

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            text: "Theme Mode"
                            color: Theme.textPrimary
                            font.pixelSize: Theme.fontSizeNormal
                            font.family: Theme.fontFamily
                            font.weight: Font.Medium
                        }

                        Text {
                            text: "Choose color scheme"
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: Theme.fontFamily
                        }
                    }

                    StandardComboBox {
                        Layout.preferredWidth: 170
                        model: ["System", "Light mode", "Dark mode"]
                        currentIndex: ThemeState.themeMode
                        onCurrentIndexChanged: ThemeState.themeMode = currentIndex
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }
    }

    Item {
        anchors.fill: parent
        visible: settingsView.activeSettingKey !== "" && settingsView.activeSettingKey !== "theme"

        Text {
            anchors.centerIn: parent
            text: "Settings group '" + settingsView.activeSettingKey + "' is not implemented yet."
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeNormal
        }
    }

    Item {
        anchors.fill: parent
        visible: settingsView.activeSettingKey === ""

        Text {
            anchors.centerIn: parent
            text: "Select a settings group from the left panel."
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeNormal
        }
    }
}

