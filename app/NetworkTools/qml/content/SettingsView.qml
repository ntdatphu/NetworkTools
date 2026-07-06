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
    readonly property bool isAppearanceSetting: activeSettingKey === "theme"

    function statusBarPreviewDate() {
        const customFormat = (StatusBarState.customDateFormat || "").trim()
        if (StatusBarState.dateTimeFormatMode === 1 && customFormat !== "")
            return Qt.formatDate(statusBarPreviewDateTime, customFormat)
        return statusBarPreviewDateTime.toLocaleDateString(Qt.locale())
    }

    function statusBarPreviewTime() {
        const customFormat = (StatusBarState.customTimeFormat || "").trim()
        if (StatusBarState.dateTimeFormatMode === 1 && customFormat !== "")
            return Qt.formatTime(statusBarPreviewDateTime, customFormat)
        return statusBarPreviewDateTime.toLocaleTimeString(Qt.locale())
    }

    function resetStatusBarDefaults() {
        StatusBarState.resetDefaults()
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
                            text: "Appearance"
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
                            text: "Dark Side Bar"
                            description: "Use dark Activity Bar and Panel Side Bar with the current Light, Dark, or High Contrast theme."
                            checked: ThemeState.lightDarkSideBar
                            onToggled: ThemeState.lightDarkSideBar = checked
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

                        Flow {
                            id: accentGroupsFlow
                            Layout.fillWidth: true
                            Layout.preferredHeight: childrenRect.height
                            spacing: 14

                            Repeater {
                                model: ThemeState.accentGroups.length

                                delegate: Item {
                                    id: accentGroupDelegate
                                    required property int index
                                    property string groupName: ThemeState.accentGroups[index]
                                    property var groupOptions: ThemeState.accentOptionsForGroup(groupName)

                                    width: 132
                                    height: accentGroupColumn.implicitHeight

                                    Column {
                                        id: accentGroupColumn
                                        width: parent.width
                                        spacing: 8

                                        Text {
                                            width: parent.width
                                            text: accentGroupDelegate.groupName
                                            color: Theme.textSecondary
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.family: Theme.fontFamily
                                            font.capitalization: Font.AllUppercase
                                            font.weight: Font.Medium
                                            elide: Text.ElideRight
                                        }

                                        Row {
                                            spacing: 8

                                            Repeater {
                                                model: accentGroupDelegate.groupOptions.length

                                                delegate: Item {
                                                    required property int index
                                                    property var option: accentGroupDelegate.groupOptions[index]
                                                    readonly property bool selected: option !== undefined
                                                                             && ThemeState.accentColorIndex === option.index

                                                    width: 56
                                                    height: 56

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
                                                        anchors.topMargin: 5
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                        width: 28
                                                        height: 28
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
                            text: "Choose whether the Status Bar is shown, which indicators are visible, and how RAM and time are formatted."
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

                        StandardToggleButton {
                            Layout.fillWidth: true
                            text: "Show Status Bar"
                            description: "Hide or show the entire bottom Status Bar while keeping the indicator choices below."
                            checked: StatusBarState.showStatusBar
                            onToggled: StatusBarState.showStatusBar = checked
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: StatusBarState.showStatusBar && !StatusBarState.hasVisibleContent
                            text: "The Status Bar is hidden because no indicators are enabled."
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: Theme.fontFamily
                            wrapMode: Text.WordWrap
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2
                            columnSpacing: 20
                            rowSpacing: 8

                            StandardCheckBox {
                                text: "Python status"
                                checked: StatusBarState.showPythonStatus
                                onToggled: StatusBarState.showPythonStatus = checked
                            }

                            StandardCheckBox {
                                text: "Network"
                                checked: StatusBarState.showNetwork
                                onToggled: StatusBarState.showNetwork = checked
                            }

                            StandardCheckBox {
                                text: "Network name"
                                enabled: StatusBarState.showNetwork
                                checked: StatusBarState.showNetworkName
                                onToggled: StatusBarState.showNetworkName = checked
                            }

                            StandardCheckBox {
                                text: "RAM"
                                checked: StatusBarState.showRam
                                onToggled: StatusBarState.showRam = checked
                            }

                            StandardCheckBox {
                                text: "Date"
                                checked: StatusBarState.showDate
                                onToggled: StatusBarState.showDate = checked
                            }

                            StandardCheckBox {
                                text: "Time"
                                checked: StatusBarState.showTime
                                onToggled: StatusBarState.showTime = checked
                            }

                            StandardCheckBox {
                                text: "Notifications"
                                checked: StatusBarState.showNotifications
                                onToggled: StatusBarState.showNotifications = checked
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
                                enabled: StatusBarState.showRam
                                checked: StatusBarState.showRamBar
                                onToggled: StatusBarState.showRamBar = checked
                            }

                            StandardCheckBox {
                                text: "Show number"
                                enabled: StatusBarState.showRam
                                checked: StatusBarState.showRamText
                                onToggled: StatusBarState.showRamText = checked
                            }

                            StandardCheckBox {
                                text: "Turn red at threshold"
                                enabled: StatusBarState.showRam
                                checked: StatusBarState.ramWarningEnabled
                                onToggled: StatusBarState.ramWarningEnabled = checked
                            }

                            StandardCheckBox {
                                text: "Blink when high"
                                enabled: StatusBarState.showRam && StatusBarState.ramWarningEnabled
                                checked: StatusBarState.ramBlinkOnHigh
                                onToggled: StatusBarState.ramBlinkOnHigh = checked
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            StandardSpinBox {
                                Layout.preferredWidth: 180
                                labelText: "Warning threshold (%)"
                                enabled: StatusBarState.showRam && StatusBarState.ramWarningEnabled
                                from: 1
                                to: 100
                                value: StatusBarState.ramWarningThreshold
                                onValueChanged: StatusBarState.ramWarningThreshold = value
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
                                currentIndex: StatusBarState.dateTimeFormatMode
                                onCurrentIndexChanged: StatusBarState.dateTimeFormatMode = currentIndex
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
                                enabled: StatusBarState.dateTimeFormatMode === 1
                                text: StatusBarState.customDateFormat
                                placeholderText: "dd/MM/yyyy"
                                onTextEdited: function(value) {
                                    StatusBarState.customDateFormat = value
                                }
                            }

                            StandardTextField {
                                Layout.fillWidth: true
                                labelText: "Custom time format"
                                enabled: StatusBarState.dateTimeFormatMode === 1
                                text: StatusBarState.customTimeFormat
                                placeholderText: "HH:mm"
                                onTextEdited: function(value) {
                                    StatusBarState.customTimeFormat = value
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
