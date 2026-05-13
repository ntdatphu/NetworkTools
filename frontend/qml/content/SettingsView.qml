pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import NetworkTools

Rectangle {
    id: settingsView
    color: Theme.contentBackground

    property int selectedCategory: 0  // 0=Theme, 1=General, 2=Advanced

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // Left Sidebar
        Rectangle {
            Layout.preferredWidth: 200
            Layout.fillHeight: true
            color: Theme.sideBarBackground

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 0
                spacing: 0

                // Header
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 50
                    color: Theme.sideBarBackground

                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        verticalAlignment: Text.AlignVCenter
                        text: "Settings"
                        color: Theme.textPrimary
                        font.pixelSize: Theme.fontSizeLarge
                        font.family: Theme.fontFamily
                        font.weight: Font.Bold
                    }
                }

                // Category: Theme
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    color: settingsView.selectedCategory === 0 ? Theme.sideBarItemSelected : (themeCatHover.hovered ? Theme.sideBarItemHover : "transparent")

                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        verticalAlignment: Text.AlignVCenter
                        text: "Theme"
                        color: settingsView.selectedCategory === 0 ? Theme.textPrimary : Theme.textSecondary
                        font.pixelSize: Theme.fontSizeNormal
                        font.family: Theme.fontFamily
                    }

                    HoverHandler { id: themeCatHover }
                    TapHandler {
                        onTapped: settingsView.selectedCategory = 0
                    }
                }

                // Category: General
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    color: settingsView.selectedCategory === 1 ? Theme.sideBarItemSelected : (generalCatHover.hovered ? Theme.sideBarItemHover : "transparent")

                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        verticalAlignment: Text.AlignVCenter
                        text: "General"
                        color: settingsView.selectedCategory === 1 ? Theme.textPrimary : Theme.textSecondary
                        font.pixelSize: Theme.fontSizeNormal
                        font.family: Theme.fontFamily
                    }

                    HoverHandler { id: generalCatHover }
                    TapHandler {
                        onTapped: settingsView.selectedCategory = 1
                    }
                }

                // Category: Advanced
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    color: settingsView.selectedCategory === 2 ? Theme.sideBarItemSelected : (advancedCatHover.hovered ? Theme.sideBarItemHover : "transparent")

                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        verticalAlignment: Text.AlignVCenter
                        text: "Advanced"
                        color: settingsView.selectedCategory === 2 ? Theme.textPrimary : Theme.textSecondary
                        font.pixelSize: Theme.fontSizeNormal
                        font.family: Theme.fontFamily
                    }

                    HoverHandler { id: advancedCatHover }
                    TapHandler {
                        onTapped: settingsView.selectedCategory = 2
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }

        // Right Content
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Theme.contentBackground

            // Theme Content
            Item {
                anchors.fill: parent
                visible: settingsView.selectedCategory === 0

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
                                Layout.preferredWidth: 150
                                model: ["System Default", "Light Mode", "Dark Mode"]
                                currentIndex: Theme.themeMode
                                onCurrentIndexChanged: {
                                    Theme.themeMode = currentIndex
                                }
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }
                }
            }

            // General Content
            Item {
                anchors.fill: parent
                visible: settingsView.selectedCategory === 1

                Text {
                    anchors.centerIn: parent
                    text: "General settings\n(Coming soon)"
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontSizeNormal
                    font.family: Theme.fontFamily
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            // Advanced Content
            Item {
                anchors.fill: parent
                visible: settingsView.selectedCategory === 2

                Text {
                    anchors.centerIn: parent
                    text: "Advanced settings\n(Coming soon)"
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontSizeNormal
                    font.family: Theme.fontFamily
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }
}
