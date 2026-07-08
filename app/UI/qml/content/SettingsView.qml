pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

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
        running: settingsView.isAppearanceSetting
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
                            text: qsTr("Appearance")
                            color: Theme.textPrimary
                            font.pixelSize: Theme.fontSizeLarge
                            font.family: Theme.fontFamily
                            font.weight: Font.Bold
                        }

                        Text {
                            Layout.fillWidth: true
                            text: qsTr("Customize the accent color, Status Bar, Activity Bar, and sidebar treatment.")
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

                    ColumnLayout {
                        id: themeModeLayout
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
                                    text: qsTr("Theme Mode")
                                    color: Theme.textPrimary
                                    font.pixelSize: Theme.fontSizeNormal
                                    font.family: Theme.fontFamily
                                    font.weight: Font.Medium
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: qsTr("Choose the base color scheme and sidebar treatment for the app.")
                                    color: Theme.textSecondary
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.family: Theme.fontFamily
                                    wrapMode: Text.WordWrap
                                }
                            }

                            StandardComboBox {
                                Layout.preferredWidth: 230
                                model: [
                                    qsTr("System"),
                                    qsTr("Light"),
                                    qsTr("Dark"),
                                    qsTr("Light High Contrast"),
                                    qsTr("Dark High Contrast")
                                ]
                                currentIndex: ThemeState.themeMode
                                onCurrentIndexChanged: ThemeState.themeMode = currentIndex
                            }
                        }

                        StandardToggleButton {
                            Layout.fillWidth: true
                            text: qsTr("Dark Side Bar")
                            description: qsTr("Use dark Activity Bar and Panel Side Bar with the current Light, Dark, or High Contrast theme.")
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
                                    text: qsTr("Accent Color")
                                    color: Theme.textPrimary
                                    font.pixelSize: Theme.fontSizeNormal
                                    font.family: Theme.fontFamily
                                    font.weight: Font.Medium
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: qsTr("Applies to the Activity Bar indicator, selected states, Status Bar, Panel split handle, and highlighted controls.")
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
                                    text: ThemeState.accentNameLabel(ThemeState.currentAccent.name)
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

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: customAccentLayout.implicitHeight + 20
                            radius: Theme.radiusSmall
                            color: Theme.contentSurface
                            border.width: Theme.borderWidth
                            border.color: Theme.borderColor

                            ColumnLayout {
                                id: customAccentLayout
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 10

                                StandardCheckBox {
                                    text: qsTr("Use custom accent color")
                                    checked: ThemeState.useCustomAccentColor
                                    onToggled: ThemeState.useCustomAccentColor = checked
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 12

                                    Rectangle {
                                        Layout.alignment: Qt.AlignVCenter
                                        Layout.preferredWidth: 32
                                        Layout.preferredHeight: 32
                                        radius: Theme.radiusSmall
                                        color: ThemeState.normalizeHexColor(ThemeState.customAccentColor)
                                        border.width: Theme.borderWidth
                                        border.color: Theme.accentEmphasis
                                    }

                                    StandardTextField {
                                        Layout.preferredWidth: 180
                                        labelText: qsTr("Custom color")
                                        enabled: ThemeState.useCustomAccentColor
                                        text: ThemeState.customAccentColor
                                        placeholderText: qsTr("#356FD6")
                                        onTextEdited: function(value) {
                                            ThemeState.customAccentColor = value
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: ThemeState.useCustomAccentColor
                                              ? (ThemeState.isValidAccentColor(ThemeState.customAccentColor)
                                                 ? qsTr("Derived shades are generated automatically for light, dark, and contrast themes.")
                                                 : qsTr("Use #RGB or #RRGGBB. Invalid input falls back to the default accent preview."))
                                              : qsTr("Select a preset below or enable custom input.")
                                        color: ThemeState.useCustomAccentColor && !ThemeState.isValidAccentColor(ThemeState.customAccentColor)
                                               ? Theme.alertError
                                               : Theme.textSecondary
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.family: Theme.fontFamily
                                        wrapMode: Text.WordWrap
                                    }
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
                                            text: ThemeState.accentGroupLabel(accentGroupDelegate.groupName)
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
                                                                             && !ThemeState.useCustomAccentColor
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
                                                        text: option !== undefined ? ThemeState.accentNameLabel(option.name) : ""
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
                                                        onTapped: {
                                                            ThemeState.useCustomAccentColor = false
                                                            ThemeState.accentColorIndex = option.index
                                                        }
                                                    }

                                                    ToolTip.visible: swatchHover.hovered
                                                    ToolTip.text: option !== undefined
                                                                  ? ThemeState.accentGroupLabel(option.group) + " - " + ThemeState.accentNameLabel(option.name)
                                                                  : ""
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

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 24
                    Layout.rightMargin: 24
                    spacing: 12

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            text: qsTr("Status Bar")
                            color: Theme.textPrimary
                            font.pixelSize: Theme.fontSizeLarge
                            font.family: Theme.fontFamily
                            font.weight: Font.Bold
                        }

                        Text {
                            Layout.fillWidth: true
                            text: qsTr("Configure the bottom Status Bar and the indicators shown inside it.")
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: Theme.fontFamily
                            wrapMode: Text.WordWrap
                        }
                    }

                    StandardButton {
                        visible: StatusBarState.hasCustomSettings
                        text: qsTr("Reset")
                        type: "Secondary"
                        onClicked: settingsView.resetStatusBarDefaults()
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: 24
                    Layout.rightMargin: 24
                    Layout.preferredHeight: statusBarLayout.implicitHeight + 24
                    color: Theme.searchBackground2
                    radius: Theme.borderRadius
                    border.width: Theme.borderWidth
                    border.color: Theme.borderColor

                    ColumnLayout {
                        id: statusBarLayout
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 12

                        StandardToggleButton {
                            Layout.fillWidth: true
                            text: qsTr("Show Status Bar")
                            description: qsTr("Hide or show the entire bottom Status Bar while keeping the indicator choices below.")
                            checked: StatusBarState.showStatusBar
                            onToggled: StatusBarState.showStatusBar = checked
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: StatusBarState.showStatusBar && !StatusBarState.hasVisibleContent
                            text: qsTr("The Status Bar is hidden because no indicators are enabled.")
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: Theme.fontFamily
                            wrapMode: Text.WordWrap
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Theme.borderWidth
                            color: Theme.borderColor
                        }

                        StandardCheckBox {
                            text: qsTr("Python Status")
                            checked: StatusBarState.showPythonStatus
                            onToggled: StatusBarState.showPythonStatus = checked
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Theme.borderWidth
                            color: Theme.borderColor
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 20

                                StandardCheckBox {
                                    Layout.preferredWidth: 160
                                    text: qsTr("Network")
                                    checked: StatusBarState.showNetwork
                                    onToggled: StatusBarState.showNetwork = checked
                                }

                                StandardCheckBox {
                                    Layout.preferredWidth: 180
                                    text: qsTr("Network Name")
                                    enabled: StatusBarState.showNetwork
                                    checked: StatusBarState.showNetworkName
                                    onToggled: StatusBarState.showNetworkName = checked
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: StatusBarState.showNetwork
                                text: qsTr("Example: ") + (StatusBarState.showNetworkName ? qsTr("Wi-Fi - PTIT.HCM_SV") : qsTr("Wi-Fi or Ethernet"))
                                color: Theme.textSecondary
                                font.pixelSize: Theme.fontSizeSmall
                                font.family: Theme.fontFamily
                                wrapMode: Text.WordWrap
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Theme.borderWidth
                            color: Theme.borderColor
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            StandardCheckBox {
                                text: qsTr("RAM")
                                checked: StatusBarState.showRam
                                onToggled: StatusBarState.showRam = checked
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                visible: StatusBarState.showRam
                                spacing: 10

                                GridLayout {
                                    Layout.fillWidth: true
                                    columns: 2
                                    columnSpacing: 20
                                    rowSpacing: 8

                                    StandardCheckBox {
                                        text: qsTr("Show usage bar")
                                        checked: StatusBarState.showRamBar
                                        onToggled: StatusBarState.showRamBar = checked
                                    }

                                    StandardCheckBox {
                                        text: qsTr("Show number")
                                        checked: StatusBarState.showRamText
                                        onToggled: StatusBarState.showRamText = checked
                                    }

                                    StandardCheckBox {
                                        text: qsTr("Turn red at threshold")
                                        checked: StatusBarState.ramWarningEnabled
                                        onToggled: StatusBarState.ramWarningEnabled = checked
                                    }

                                    StandardCheckBox {
                                        text: qsTr("Blink when high")
                                        enabled: StatusBarState.ramWarningEnabled
                                        checked: StatusBarState.ramBlinkOnHigh
                                        onToggled: StatusBarState.ramBlinkOnHigh = checked
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 12

                                    StandardSpinBox {
                                        Layout.preferredWidth: 180
                                        labelText: qsTr("Warning threshold (%)")
                                        enabled: StatusBarState.ramWarningEnabled
                                        from: 1
                                        to: 100
                                        value: StatusBarState.ramWarningThreshold
                                        onValueChanged: StatusBarState.ramWarningThreshold = value
                                    }

                                    Rectangle {
                                        Layout.alignment: Qt.AlignVCenter
                                        Layout.preferredWidth: 92
                                        Layout.preferredHeight: 8
                                        radius: height / 2
                                        color: Theme.statusBarSepColor
                                        clip: true

                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.top: parent.top
                                            anchors.bottom: parent.bottom
                                            width: parent.width * 0.58
                                            radius: height / 2
                                            color: Theme.buttonTextSolid
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: qsTr("Normal RAM color matches Status Bar text; high usage still uses the warning color.")
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
                            Layout.preferredHeight: Theme.borderWidth
                            color: Theme.borderColor
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 20

                                StandardCheckBox {
                                    Layout.preferredWidth: 160
                                    text: qsTr("Date")
                                    checked: StatusBarState.showDate
                                    onToggled: StatusBarState.showDate = checked
                                }

                                StandardCheckBox {
                                    Layout.preferredWidth: 160
                                    text: qsTr("Time")
                                    checked: StatusBarState.showTime
                                    onToggled: StatusBarState.showTime = checked
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                visible: StatusBarState.showDate || StatusBarState.showTime
                                spacing: 10

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 12

                                    StandardComboBox {
                                        Layout.preferredWidth: 220
                                        labelText: qsTr("Format source")
                                        model: [
                                            qsTr("Regional format"),
                                            qsTr("Custom format")
                                        ]
                                        currentIndex: StatusBarState.dateTimeFormatMode
                                        onCurrentIndexChanged: StatusBarState.dateTimeFormatMode = currentIndex
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: qsTr("Regional format follows the current system locale. Custom format uses Qt date/time patterns.")
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
                                    visible: StatusBarState.dateTimeFormatMode === 1

                                    StandardTextField {
                                        Layout.fillWidth: true
                                        labelText: qsTr("Custom date format")
                                        enabled: StatusBarState.showDate
                                        text: StatusBarState.customDateFormat
                                        placeholderText: qsTr("dd/MM/yyyy")
                                        onTextEdited: function(value) {
                                            StatusBarState.customDateFormat = value
                                        }
                                    }

                                    StandardTextField {
                                        Layout.fillWidth: true
                                        labelText: qsTr("Custom time format")
                                        enabled: StatusBarState.showTime
                                        text: StatusBarState.customTimeFormat
                                        placeholderText: qsTr("HH:mm")
                                        onTextEdited: function(value) {
                                            StatusBarState.customTimeFormat = value
                                        }
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: qsTr("Preview: ")
                                          + (StatusBarState.showDate ? settingsView.statusBarPreviewDate() : "")
                                          + (StatusBarState.showDate && StatusBarState.showTime ? " " : "")
                                          + (StatusBarState.showTime ? settingsView.statusBarPreviewTime() : "")
                                    color: Theme.textSecondary
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.family: Theme.fontFamily
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Theme.borderWidth
                            color: Theme.borderColor
                        }

                        StandardCheckBox {
                            text: qsTr("Notifications")
                            checked: StatusBarState.showNotifications
                            onToggled: StatusBarState.showNotifications = checked
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

        Text {
            anchors.centerIn: parent
            text: qsTr("Settings group '%1' is not implemented yet.").arg(settingsView.activeSettingKey)
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
            text: qsTr("Select a settings group from the left panel.")
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeNormal
        }
    }
}
