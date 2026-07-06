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
    readonly property bool isAppearanceSetting: activeSettingKey === "theme" || activeSettingKey === "colors"

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
        visible: settingsView.isAppearanceSetting

        ScrollView {
            id: appearanceScroll
            anchors.fill: parent
            clip: true
            contentWidth: availableWidth
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.policy: ScrollBar.AsNeeded

            ColumnLayout {
                width: appearanceScroll.availableWidth
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
                            text: settingsView.activeSettingKey === "colors" ? "Colors" : "Appearance"
                            color: Theme.textPrimary
                            font.pixelSize: Theme.fontSizeLarge
                            font.family: Theme.fontFamily
                            font.weight: Font.Bold
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "Customize the accent color, Status Bar, Activity Bar, and sidebar treatment."
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: Theme.fontFamily
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: 24
                    Layout.rightMargin: 24
                    Layout.preferredHeight: quickAccentLayout.implicitHeight + 24
                    color: Theme.searchBackground2
                    radius: Theme.borderRadius
                    border.width: Theme.borderWidth
                    border.color: Theme.borderColor

                    ColumnLayout {
                        id: quickAccentLayout
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 12

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                Text {
                                    text: "Color Palette"
                                    color: Theme.textPrimary
                                    font.pixelSize: Theme.fontSizeNormal
                                    font.family: Theme.fontFamily
                                    font.weight: Font.Medium
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: "Pick a color square to update the app accent immediately."
                                    color: Theme.textSecondary
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.family: Theme.fontFamily
                                    wrapMode: Text.WordWrap
                                }
                            }

                            Rectangle {
                                Layout.alignment: Qt.AlignVCenter
                                Layout.preferredWidth: 96
                                Layout.preferredHeight: 32
                                radius: Theme.radiusSmall
                                color: Theme.statusBarBackground

                                Text {
                                    anchors.centerIn: parent
                                    text: ThemeState.currentAccent.name
                                    color: Theme.buttonTextSolid
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.family: Theme.fontFamily
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        Flow {
                            Layout.fillWidth: true
                            Layout.preferredHeight: childrenRect.height
                            spacing: 8

                            Repeater {
                                model: ThemeState.accentPalette.length

                                delegate: Rectangle {
                                    required property int index
                                    property var option: ThemeState.accentPalette[index]
                                    readonly property bool selected: option !== undefined
                                                             && ThemeState.accentColorIndex === option.index

                                    width: 34
                                    height: 34
                                    radius: 6
                                    color: option !== undefined ? option.color : "transparent"
                                    border.width: selected ? 3 : Theme.borderWidth
                                    border.color: selected ? Theme.textPrimary
                                                           : (option !== undefined ? option.emphasis : Theme.borderColor)

                                    Rectangle {
                                        visible: selected
                                        anchors.centerIn: parent
                                        width: 10
                                        height: 10
                                        radius: 5
                                        color: Theme.buttonTextSolid
                                    }

                                    HoverHandler {
                                        id: quickSwatchHover
                                        cursorShape: Qt.PointingHandCursor
                                    }

                                    TapHandler {
                                        enabled: option !== undefined
                                        onTapped: ThemeState.accentColorIndex = option.index
                                    }

                                    ToolTip.visible: quickSwatchHover.hovered
                                    ToolTip.text: option !== undefined ? option.group + " - " + option.name : ""
                                    ToolTip.delay: 400
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: 24
                    Layout.rightMargin: 24
                    Layout.preferredHeight: themeModeLayout.implicitHeight + 24
                    color: Theme.searchBackground2
                    radius: Theme.borderRadius
                    border.width: Theme.borderWidth
                    border.color: Theme.borderColor

                    RowLayout {
                        id: themeModeLayout
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
                                Layout.fillWidth: true
                                text: "Choose the base color scheme for the app."
                                color: Theme.textSecondary
                                font.pixelSize: Theme.fontSizeSmall
                                font.family: Theme.fontFamily
                                wrapMode: Text.WordWrap
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

                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: 24
                    Layout.rightMargin: 24
                    Layout.preferredHeight: darkSidebarLayout.implicitHeight + 24
                    color: Theme.searchBackground2
                    radius: Theme.borderRadius
                    border.width: Theme.borderWidth
                    border.color: Theme.borderColor

                    ColumnLayout {
                        id: darkSidebarLayout
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 12

                        StandardToggleButton {
                            Layout.fillWidth: true
                            text: "Dark Side Bar in Light"
                            description: "Use a Discord-like Light theme: dark Activity Bar and Panel Side Bar, light content area."
                            checked: ThemeState.lightDarkSideBar
                            enabled: ThemeState.effectiveThemeMode === ThemeState.light
                            onToggled: ThemeState.lightDarkSideBar = checked
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: ThemeState.effectiveThemeMode !== ThemeState.light
                            text: "This option is available when the effective theme is Light."
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: Theme.fontFamily
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: 24
                    Layout.rightMargin: 24
                    Layout.preferredHeight: accentLayout.implicitHeight + 24
                    color: Theme.searchBackground2
                    radius: Theme.borderRadius
                    border.width: Theme.borderWidth
                    border.color: Theme.borderColor

                    ColumnLayout {
                        id: accentLayout
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 14

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                Text {
                                    text: "Accent Color"
                                    color: Theme.textPrimary
                                    font.pixelSize: Theme.fontSizeNormal
                                    font.family: Theme.fontFamily
                                    font.weight: Font.Medium
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: "Applies to the Activity Bar indicator, selected states, Status Bar, Panel split handle, and highlighted controls."
                                    color: Theme.textSecondary
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.family: Theme.fontFamily
                                    wrapMode: Text.WordWrap
                                }
                            }

                            Rectangle {
                                Layout.alignment: Qt.AlignVCenter
                                Layout.preferredWidth: 88
                                Layout.preferredHeight: 32
                                radius: Theme.radiusSmall
                                color: Theme.statusBarBackground

                                Text {
                                    anchors.centerIn: parent
                                    text: ThemeState.currentAccent.name
                                    color: Theme.buttonTextSolid
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.family: Theme.fontFamily
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 58
                            radius: Theme.radiusSmall
                            color: Theme.contentSurface
                            border.width: Theme.borderWidth
                            border.color: Theme.borderColor

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 0

                                Rectangle {
                                    Layout.fillHeight: true
                                    Layout.preferredWidth: 20
                                    color: Theme.activityBarBackground

                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 3
                                        height: parent.height - 10
                                        color: Theme.accentColor
                                    }
                                }

                                Rectangle {
                                    Layout.fillHeight: true
                                    Layout.preferredWidth: 80
                                    color: Theme.panelSideBarBackground

                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.margins: 8
                                        height: 20
                                        radius: Theme.radiusSmall
                                        color: Theme.panelSideBarItemSelected
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    color: Theme.contentBackground
                                }

                                Rectangle {
                                    Layout.fillHeight: true
                                    Layout.preferredWidth: 4
                                    color: Theme.statusBarBackground
                                }
                            }
                        }

                        Repeater {
                            model: ThemeState.accentGroups.length

                            delegate: ColumnLayout {
                                id: accentGroupDelegate
                                required property int index
                                property string groupName: ThemeState.accentGroups[index]
                                property var groupOptions: ThemeState.accentOptionsForGroup(groupName)

                                Layout.fillWidth: true
                                spacing: 8

                                Text {
                                    text: groupName
                                    color: Theme.textSecondary
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.family: Theme.fontFamily
                                    font.capitalization: Font.AllUppercase
                                    font.weight: Font.Medium
                                }

                                Flow {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: childrenRect.height
                                    spacing: 10

                                    Repeater {
                                        model: accentGroupDelegate.groupOptions.length

                                        delegate: Item {
                                            required property int index
                                            property var option: accentGroupDelegate.groupOptions[index]
                                            readonly property bool selected: option !== undefined
                                                                     && ThemeState.accentColorIndex === option.index

                                            width: 62
                                            height: 58

                                            Rectangle {
                                                anchors.fill: parent
                                                radius: Theme.radiusSmall
                                                color: selected ? Theme.sideBarItemSelected
                                                                : (swatchHover.hovered ? Theme.sideBarItemHover : "transparent")
                                                border.width: selected ? Theme.borderWidth : 0
                                                border.color: selected ? Theme.accentColor : "transparent"
                                            }

                                            Rectangle {
                                                id: swatchSquare
                                                anchors.top: parent.top
                                                anchors.topMargin: 6
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                width: 30
                                                height: 30
                                                radius: 5
                                                color: option !== undefined ? option.color : "transparent"
                                                border.width: Theme.borderWidth
                                                border.color: option !== undefined ? option.emphasis : Theme.borderColor

                                                Rectangle {
                                                    visible: selected
                                                    anchors.centerIn: parent
                                                    width: 8
                                                    height: 8
                                                    radius: 4
                                                    color: Theme.buttonTextSolid
                                                }
                                            }

                                            Text {
                                                anchors.top: swatchSquare.bottom
                                                anchors.topMargin: 4
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                text: option !== undefined ? option.name : ""
                                                color: selected ? Theme.textPrimary : Theme.textSecondary
                                                font.pixelSize: Theme.fontSizeCaption
                                                font.family: Theme.fontFamily
                                                horizontalAlignment: Text.AlignHCenter
                                                elide: Text.ElideRight
                                            }

                                            HoverHandler {
                                                id: swatchHover
                                                cursorShape: Qt.PointingHandCursor
                                            }

                                            TapHandler {
                                                enabled: option !== undefined
                                                onTapped: ThemeState.accentColorIndex = option.index
                                            }

                                            ToolTip.visible: swatchHover.hovered
                                            ToolTip.text: option !== undefined ? option.group + " - " + option.name : ""
                                            ToolTip.delay: 400
                                        }
                                    }
                                }
                            }
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
                 && !settingsView.isAppearanceSetting
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
