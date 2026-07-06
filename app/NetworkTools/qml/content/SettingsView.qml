pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import NetworkTools

Rectangle {
    id: settingsView
    color: Theme.contentBackground

    property string activeSettingKey: "theme"
    property date statusBarPreviewDateTime: new Date()

    function statusBarPreviewDate() {
        const customFormat = (statusBarSettings.customDateFormat || "").trim()
        if (statusBarSettings.dateTimeFormatMode === 1 && customFormat !== "")
            return Qt.formatDate(statusBarPreviewDateTime, customFormat)
        return statusBarPreviewDateTime.toLocaleDateString(Qt.locale())
    }

    function statusBarPreviewTime() {
        const customFormat = (statusBarSettings.customTimeFormat || "").trim()
        if (statusBarSettings.dateTimeFormatMode === 1 && customFormat !== "")
            return Qt.formatTime(statusBarPreviewDateTime, customFormat)
        return statusBarPreviewDateTime.toLocaleTimeString(Qt.locale())
    }

    function resetStatusBarDefaults() {
        statusBarSettings.resetDefaults()
    }

    Timer {
        interval: 1000
        running: settingsView.activeSettingKey === "statusbar"
        repeat: true
        onTriggered: settingsView.statusBarPreviewDateTime = new Date()
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
                        Layout.preferredWidth: 230
                        model: [
                            "System",
                            "Light",
                            "Dark",
                            "Light High Contrast",
                            "Dark High Contrast"
                        ]
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
        visible: settingsView.activeSettingKey === "statusbar"

        ScrollView {
            id: statusScroll
            anchors.fill: parent
            clip: true
            contentWidth: availableWidth
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.policy: ScrollBar.AsNeeded

            ColumnLayout {
                width: statusScroll.availableWidth
                spacing: 16

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 8
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 24
                    Layout.rightMargin: 24
                    spacing: 12

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            text: "Status Bar"
                            color: Theme.textPrimary
                            font.pixelSize: Theme.fontSizeLarge
                            font.family: Theme.fontFamily
                            font.weight: Font.Bold
                        }

                        Text {
                            text: "Choose which indicators are shown and how RAM and time are formatted."
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: Theme.fontFamily
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }

                    StandardButton {
                        text: "Reset"
                        type: "Secondary"
                        onClicked: settingsView.resetStatusBarDefaults()
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: 24
                    Layout.rightMargin: 24
                    Layout.preferredHeight: visibilityLayout.implicitHeight + 24
                    color: Theme.searchBackground2
                    radius: Theme.borderRadius
                    border.width: Theme.borderWidth
                    border.color: Theme.borderColor

                    ColumnLayout {
                        id: visibilityLayout
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 12

                        Text {
                            text: "Visible Indicators"
                            color: Theme.textPrimary
                            font.pixelSize: Theme.fontSizeNormal
                            font.family: Theme.fontFamily
                            font.weight: Font.Medium
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2
                            columnSpacing: 20
                            rowSpacing: 8

                            StandardCheckBox {
                                text: "Python status"
                                checked: statusBarSettings.showPythonStatus
                                onToggled: statusBarSettings.showPythonStatus = checked
                            }

                            StandardCheckBox {
                                text: "Network"
                                checked: statusBarSettings.showNetwork
                                onToggled: statusBarSettings.showNetwork = checked
                            }

                            StandardCheckBox {
                                text: "Network name"
                                enabled: statusBarSettings.showNetwork
                                checked: statusBarSettings.showNetworkName
                                onToggled: statusBarSettings.showNetworkName = checked
                            }

                            StandardCheckBox {
                                text: "RAM"
                                checked: statusBarSettings.showRam
                                onToggled: statusBarSettings.showRam = checked
                            }

                            StandardCheckBox {
                                text: "Date"
                                checked: statusBarSettings.showDate
                                onToggled: statusBarSettings.showDate = checked
                            }

                            StandardCheckBox {
                                text: "Time"
                                checked: statusBarSettings.showTime
                                onToggled: statusBarSettings.showTime = checked
                            }

                            StandardCheckBox {
                                text: "Notifications"
                                checked: statusBarSettings.showNotifications
                                onToggled: statusBarSettings.showNotifications = checked
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: 24
                    Layout.rightMargin: 24
                    Layout.preferredHeight: ramLayout.implicitHeight + 24
                    color: Theme.searchBackground2
                    radius: Theme.borderRadius
                    border.width: Theme.borderWidth
                    border.color: Theme.borderColor

                    ColumnLayout {
                        id: ramLayout
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 12

                        Text {
                            text: "RAM Indicator"
                            color: Theme.textPrimary
                            font.pixelSize: Theme.fontSizeNormal
                            font.family: Theme.fontFamily
                            font.weight: Font.Medium
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2
                            columnSpacing: 20
                            rowSpacing: 8

                            StandardCheckBox {
                                text: "Show usage bar"
                                enabled: statusBarSettings.showRam
                                checked: statusBarSettings.showRamBar
                                onToggled: statusBarSettings.showRamBar = checked
                            }

                            StandardCheckBox {
                                text: "Show number"
                                enabled: statusBarSettings.showRam
                                checked: statusBarSettings.showRamText
                                onToggled: statusBarSettings.showRamText = checked
                            }

                            StandardCheckBox {
                                text: "Turn red at threshold"
                                enabled: statusBarSettings.showRam
                                checked: statusBarSettings.ramWarningEnabled
                                onToggled: statusBarSettings.ramWarningEnabled = checked
                            }

                            StandardCheckBox {
                                text: "Blink when high"
                                enabled: statusBarSettings.showRam && statusBarSettings.ramWarningEnabled
                                checked: statusBarSettings.ramBlinkOnHigh
                                onToggled: statusBarSettings.ramBlinkOnHigh = checked
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            StandardSpinBox {
                                Layout.preferredWidth: 180
                                labelText: "Warning threshold (%)"
                                enabled: statusBarSettings.showRam && statusBarSettings.ramWarningEnabled
                                from: 1
                                to: 100
                                value: statusBarSettings.ramWarningThreshold
                                onValueChanged: statusBarSettings.ramWarningThreshold = value
                            }

                            Text {
                                Layout.fillWidth: true
                                text: "The Status Bar turns the RAM bar red when usage is at or above this value."
                                color: Theme.textSecondary
                                font.pixelSize: Theme.fontSizeSmall
                                font.family: Theme.fontFamily
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: 24
                    Layout.rightMargin: 24
                    Layout.preferredHeight: dateTimeLayout.implicitHeight + 24
                    color: Theme.searchBackground2
                    radius: Theme.borderRadius
                    border.width: Theme.borderWidth
                    border.color: Theme.borderColor

                    ColumnLayout {
                        id: dateTimeLayout
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 12

                        Text {
                            text: "Date and Time"
                            color: Theme.textPrimary
                            font.pixelSize: Theme.fontSizeNormal
                            font.family: Theme.fontFamily
                            font.weight: Font.Medium
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            StandardComboBox {
                                Layout.preferredWidth: 220
                                labelText: "Format source"
                                model: [
                                    "Regional format",
                                    "Custom format"
                                ]
                                currentIndex: statusBarSettings.dateTimeFormatMode
                                onCurrentIndexChanged: statusBarSettings.dateTimeFormatMode = currentIndex
                            }

                            Text {
                                Layout.fillWidth: true
                                text: "Regional format follows the user's current system locale. Custom format uses Qt date/time patterns."
                                color: Theme.textSecondary
                                font.pixelSize: Theme.fontSizeSmall
                                font.family: Theme.fontFamily
                                wrapMode: Text.WordWrap
                            }
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2
                            columnSpacing: 12
                            rowSpacing: 8

                            StandardTextField {
                                Layout.fillWidth: true
                                labelText: "Custom date format"
                                enabled: statusBarSettings.dateTimeFormatMode === 1
                                text: statusBarSettings.customDateFormat
                                placeholderText: "dd/MM/yyyy"
                                onTextEdited: function(value) {
                                    statusBarSettings.customDateFormat = value
                                }
                            }

                            StandardTextField {
                                Layout.fillWidth: true
                                labelText: "Custom time format"
                                enabled: statusBarSettings.dateTimeFormatMode === 1
                                text: statusBarSettings.customTimeFormat
                                placeholderText: "HH:mm"
                                onTextEdited: function(value) {
                                    statusBarSettings.customTimeFormat = value
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "Preview: " + settingsView.statusBarPreviewDate() + " " + settingsView.statusBarPreviewTime()
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: Theme.fontFamily
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 8
                }
            }
        }
    }

    Item {
        anchors.fill: parent
        visible: settingsView.activeSettingKey !== ""
                 && settingsView.activeSettingKey !== "theme"
                 && settingsView.activeSettingKey !== "statusbar"

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
