pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Basic
import QtQuick.Dialogs
import QtQuick.Layouts
import UI

Rectangle {
    id: logsAlertsView
    color: Theme.contentBackground

    property string activeSectionKey: "logs"
    property string exportFormat: "txt"
    property string actionMessage: ""
    property var activeStatusFilters: ["INFO", "SUCCESS", "WARNING", "ERROR", "CRITICAL"]
    property var activeCategoryFilters: ["ACTIVITY", "VALIDATION", "CONFIGURATION", "SYSTEM"]
    property var detailEntry: ({})
    readonly property var defaultStatusFilters: ["INFO", "SUCCESS", "WARNING", "ERROR", "CRITICAL"]
    readonly property var defaultCategoryFilters: ["ACTIVITY", "VALIDATION", "CONFIGURATION", "SYSTEM"]
    readonly property bool loggerReady: typeof appLogger !== "undefined" && appLogger !== null
    readonly property var allEntries: loggerReady ? appLogger.logs : []
    readonly property var visibleEntries: filteredEntries(allEntries, activeStatusFilters, activeCategoryFilters, activeSectionKey)
    readonly property string sectionTitle: activeSectionKey === "alerts" ? "Alerts" : "Logs"
    readonly property bool filtersActive: !sameFilters(activeStatusFilters, defaultStatusFilters)
                                          || !sameFilters(activeCategoryFilters, defaultCategoryFilters)
    readonly property string filterSummary: "Severity: " + filterLabel(activeStatusFilters, statusOptions, defaultStatusFilters, "All")
                                            + "; Category: " + filterLabel(activeCategoryFilters, categoryOptions, defaultCategoryFilters, "Default")
    readonly property var statusOptions: [
        { "key": "INFO", "label": "Info", "icon": AppAssets.resource("resources/statusbar/info.svg") },
        { "key": "SUCCESS", "label": "Success", "icon": AppAssets.resource("resources/statusbar/check.svg") },
        { "key": "WARNING", "label": "Warning", "icon": AppAssets.resource("resources/statusbar/warning.svg") },
        { "key": "ERROR", "label": "Error", "icon": AppAssets.resource("resources/statusbar/error.svg") },
        { "key": "CRITICAL", "label": "Critical", "icon": AppAssets.resource("resources/statusbar/error.svg") }
    ]
    readonly property var categoryOptions: [
        { "key": "ACTIVITY", "label": "Activity", "icon": AppAssets.resource("resources/activitybar/dashboard.svg") },
        { "key": "VALIDATION", "label": "Validation", "icon": AppAssets.resource("resources/statusbar/warning.svg") },
        { "key": "CONFIGURATION", "label": "Config", "icon": AppAssets.resource("resources/featurebar/terminal.svg") },
        { "key": "SYSTEM", "label": "System", "icon": AppAssets.resource("resources/activitybar/python.svg") },
        { "key": "DEVELOPER", "label": "Developer", "icon": AppAssets.resource("resources/activitybar/settings.svg") }
    ]

    function filteredEntries(entries, statusFilters, categoryFilters, sectionKey) {
        const rows = []
        const source = entries || []
        const statuses = statusFilters || []
        const categories = categoryFilters || []
        for (let i = source.length - 1; i >= 0; i--) {
            const item = source[i]
            const status = String(item.status || "INFO").toUpperCase()
            const category = String(item.category || "SYSTEM").toUpperCase()
            if (sectionKey === "alerts"
                    && status !== "WARNING"
                    && status !== "ERROR"
                    && status !== "CRITICAL") {
                continue
            }
            if (statuses.indexOf(status) === -1)
                continue
            if (categories.indexOf(category) === -1)
                continue
            rows.push(item)
        }
        return rows
    }

    function filterEnabled(filters, key) {
        return (filters || []).indexOf(key) !== -1
    }

    function sameFilters(left, right) {
        const a = (left || []).slice().sort()
        const b = (right || []).slice().sort()
        if (a.length !== b.length)
            return false
        for (let i = 0; i < a.length; i++) {
            if (a[i] !== b[i])
                return false
        }
        return true
    }

    function filterLabel(filters, options, defaultFilters, defaultText) {
        const selected = filters || []
        if (selected.length === 0)
            return "None"
        if (defaultText !== "" && sameFilters(selected, defaultFilters || []))
            return defaultText
        if (selected.length === options.length)
            return "All"

        const labels = []
        for (let i = 0; i < options.length; i++) {
            if (selected.indexOf(options[i].key) !== -1)
                labels.push(options[i].label)
        }

        if (labels.length <= 2)
            return labels.join(", ")
        return labels.length + " selected"
    }

    function toggleStatusFilter(key) {
        const filters = logsAlertsView.activeStatusFilters.slice()
        const idx = filters.indexOf(key)
        if (idx >= 0)
            filters.splice(idx, 1)
        else
            filters.push(key)
        logsAlertsView.activeStatusFilters = filters
    }

    function toggleCategoryFilter(key) {
        const filters = logsAlertsView.activeCategoryFilters.slice()
        const idx = filters.indexOf(key)
        if (idx >= 0)
            filters.splice(idx, 1)
        else
            filters.push(key)
        logsAlertsView.activeCategoryFilters = filters
    }

    function resetFilters() {
        logsAlertsView.activeStatusFilters = logsAlertsView.defaultStatusFilters.slice()
        logsAlertsView.activeCategoryFilters = logsAlertsView.defaultCategoryFilters.slice()
    }

    function openEntryDetails(entry) {
        logsAlertsView.detailEntry = entry || {}
        detailDialog.open()
    }

    function toggleFilterPopup() {
        if (filterPopup.visible) {
            filterPopup.close()
            return
        }

        const point = filterButton.mapToItem(logsAlertsView, 0, filterButton.height + 6)
        filterPopup.x = Math.min(Math.max(24, point.x), Math.max(24, logsAlertsView.width - filterPopup.width - 24))
        filterPopup.y = Math.min(point.y, Math.max(24, logsAlertsView.height - filterPopup.implicitHeight - 24))
        filterPopup.open()
    }

    function statusColor(status) {
        const normalized = String(status || "INFO").toUpperCase()
        if (normalized === "SUCCESS") return Theme.alertSuccess
        if (normalized === "WARNING") return Theme.alertWarning
        if (normalized === "ERROR" || normalized === "CRITICAL") return Theme.alertError
        return Theme.alertInfo
    }

    function statusBackground(status) {
        const normalized = String(status || "INFO").toUpperCase()
        if (normalized === "SUCCESS") return Theme.alertSuccessSubtle
        if (normalized === "WARNING") return Theme.alertWarningSubtle
        if (normalized === "ERROR" || normalized === "CRITICAL") return Theme.alertErrorSubtle
        return Theme.alertInfoSubtle
    }

    function formatTime(value) {
        const text = String(value || "")
        if (text.length < 19)
            return text
        return text.substring(0, 10) + " " + text.substring(11, 19)
    }

    function defaultExportName() {
        const stamp = Qt.formatDateTime(new Date(), "yyyyMMdd-HHmmss")
        return logsAlertsView.sectionTitle.toLowerCase() + "-" + stamp + "." + logsAlertsView.exportFormat
    }

    function copyVisibleEntries() {
        if (!loggerReady)
            return
        if (appLogger.copyEntries(logsAlertsView.visibleEntries))
            actionMessage = "Copied " + logsAlertsView.visibleEntries.length + " item(s) as plain text."
    }

    function openExportDialog(format) {
        logsAlertsView.exportFormat = format
        exportDialog.defaultSuffix = format
        exportDialog.nameFilters = format === "json" ? ["JSON file (*.json)"] : ["Text file (*.txt)"]
        exportDialog.selectedFile = logsAlertsView.defaultExportName()
        exportDialog.open()
    }

    FileDialog {
        id: exportDialog
        title: "Export " + logsAlertsView.sectionTitle
        fileMode: FileDialog.SaveFile
        defaultSuffix: logsAlertsView.exportFormat
        nameFilters: ["Text file (*.txt)", "JSON file (*.json)"]
        onAccepted: {
            if (!logsAlertsView.loggerReady)
                return
            const result = appLogger.exportEntries(selectedFile, logsAlertsView.visibleEntries, logsAlertsView.exportFormat)
            logsAlertsView.actionMessage = result.ok ? result.message + " " + result.path : "Export failed: " + result.message
        }
    }

    StandardValidationDialog {
        id: clearDialog
        titleText: "Clear " + logsAlertsView.sectionTitle
        messageText: logsAlertsView.activeSectionKey === "alerts"
                     ? "Clear the currently visible alert entries?"
                     : "Clear the currently visible log entries?"
        acceptText: "Clear"
        rejectText: "Cancel"
        showCancel: true
        onAccepted: {
            if (!logsAlertsView.loggerReady)
                return
            const result = appLogger.clearEntries(logsAlertsView.visibleEntries)
            logsAlertsView.actionMessage = result.ok ? result.message : "Clear failed: " + result.message
        }
    }

    Popup {
        id: filterPopup
        parent: logsAlertsView
        width: 340
        padding: 12
        modal: false
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            color: Theme.contentSurface
            radius: Theme.borderRadius
            border.color: Theme.borderColor
            border.width: Theme.borderWidth
        }

        contentItem: ColumnLayout {
            id: filterPopupContent
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: "Filters"
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeNormal
                    font.weight: Font.Bold
                }

                StandardButton {
                    text: "Reset"
                    type: "Ghost"
                    tooltip: "Restore default filters"
                    enabled: logsAlertsView.filtersActive
                    onClicked: logsAlertsView.resetFilters()
                }
            }

            Text {
                Layout.fillWidth: true
                text: "SEVERITY"
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeCaption
                font.weight: Font.Medium
            }

            Repeater {
                model: logsAlertsView.statusOptions

                delegate: Rectangle {
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    radius: Theme.radiusSmall
                    color: severityHover.hovered ? Theme.sideBarItemHover : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8

                        StandardCheckBox {
                            checked: logsAlertsView.filterEnabled(logsAlertsView.activeStatusFilters, modelData.key)
                            enabled: false
                            opacity: 1
                        }

                        ThemedIcon {
                            Layout.preferredWidth: Theme.iconSizeSmall
                            Layout.preferredHeight: Theme.iconSizeSmall
                            iconSource: modelData.icon
                            iconSize: Theme.iconSizeSmall
                            iconColor: logsAlertsView.statusColor(modelData.key)
                        }

                        Text {
                            Layout.fillWidth: true
                            text: modelData.label
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            elide: Text.ElideRight
                        }
                    }

                    HoverHandler {
                        id: severityHover
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: logsAlertsView.toggleStatusFilter(modelData.key)
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.borderWidth
                color: Theme.borderColor
            }

            Text {
                Layout.fillWidth: true
                text: "CATEGORY"
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeCaption
                font.weight: Font.Medium
            }

            Repeater {
                model: logsAlertsView.categoryOptions

                delegate: Rectangle {
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    radius: Theme.radiusSmall
                    color: categoryHover.hovered ? Theme.sideBarItemHover : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8

                        StandardCheckBox {
                            checked: logsAlertsView.filterEnabled(logsAlertsView.activeCategoryFilters, modelData.key)
                            enabled: false
                            opacity: 1
                        }

                        ThemedIcon {
                            Layout.preferredWidth: Theme.iconSizeSmall
                            Layout.preferredHeight: Theme.iconSizeSmall
                            iconSource: modelData.icon
                            iconSize: Theme.iconSizeSmall
                            iconColor: Theme.textSecondary
                        }

                        Text {
                            Layout.fillWidth: true
                            text: modelData.label
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            elide: Text.ElideRight
                        }
                    }

                    HoverHandler {
                        id: categoryHover
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: logsAlertsView.toggleCategoryFilter(modelData.key)
                    }
                }
            }
        }
    }

    Popup {
        id: detailDialog
        parent: logsAlertsView
        anchors.centerIn: parent
        width: Math.min(parent ? parent.width - 48 : 820, 860)
        height: Math.min(parent ? parent.height - 48 : 560, 620)
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        Overlay.modal: Rectangle {
            color: Theme.dialogOverlay
        }

        background: Rectangle {
            color: Theme.contentSurface
            radius: Theme.cardRadius
            border.color: Theme.borderColor
            border.width: Theme.borderWidth
        }

        contentItem: ColumnLayout {
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    Layout.fillWidth: true
                    text: logsAlertsView.activeSectionKey === "alerts" ? "Alert Details" : "Log Details"
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeTitle
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                }

                StandardButton {
                    text: "Close"
                    type: "Secondary"
                    onClicked: detailDialog.close()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    Layout.preferredWidth: 110
                    Layout.preferredHeight: 26
                    radius: Theme.radiusSmall
                    color: logsAlertsView.statusBackground(logsAlertsView.detailEntry.status)

                    Text {
                        anchors.centerIn: parent
                        text: String(logsAlertsView.detailEntry.status || "INFO").toUpperCase()
                        color: logsAlertsView.statusColor(logsAlertsView.detailEntry.status)
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Bold
                    }
                }

                Text {
                    text: logsAlertsView.formatTime(logsAlertsView.detailEntry.time)
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                }

                Rectangle {
                    Layout.preferredWidth: Theme.borderWidth
                    Layout.preferredHeight: 18
                    color: Theme.borderColor
                }

                Text {
                    Layout.fillWidth: true
                    text: (logsAlertsView.detailEntry.category || "SYSTEM") + " / " + (logsAlertsView.detailEntry.source || "app")
                    color: Theme.textSecondary
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Theme.contentBackground
                radius: Theme.radiusSmall
                border.color: Theme.borderColor
                border.width: Theme.borderWidth

                ScrollView {
                    anchors.fill: parent
                    anchors.margins: 10
                    clip: true

                    TextArea {
                        text: logsAlertsView.detailEntry.message || ""
                        readOnly: true
                        selectByMouse: true
                        wrapMode: TextEdit.NoWrap
                        color: Theme.textPrimary
                        selectedTextColor: Theme.buttonTextSolid
                        selectionColor: Theme.accentEmphasis
                        font.family: "Consolas"
                        font.pixelSize: Theme.fontSizeSmall
                        background: Rectangle {
                            color: "transparent"
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    Layout.fillWidth: true
                    text: logsAlertsView.loggerReady ? appLogger.logPath : ""
                    color: Theme.textSecondary
                    elide: Text.ElideMiddle
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                }

                StandardButton {
                    text: "Copy"
                    type: "Secondary"
                    enabled: logsAlertsView.loggerReady
                    icon.source: AppAssets.resource("resources/logs_alerts/copy.svg")
                    onClicked: {
                        if (logsAlertsView.loggerReady && appLogger.copyEntries([logsAlertsView.detailEntry]))
                            logsAlertsView.actionMessage = "Copied selected item as plain text."
                    }
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 16

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: logsAlertsView.sectionTitle
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSizeLarge
                    font.family: Theme.fontFamily
                    font.weight: Font.Bold
                }

                Text {
                    Layout.fillWidth: true
                    text: logsAlertsView.activeSectionKey === "alerts"
                          ? "Warnings, errors, and critical application issues are stored here. Developer diagnostics are hidden by default."
                          : "Timestamped user activity, validation, configuration, and system events are kept after restart. Developer diagnostics are hidden by default."
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontSizeSmall
                    font.family: Theme.fontFamily
                }
            }

            StandardButton {
                text: "Refresh"
                type: "Secondary"
                onClicked: {
                    if (logsAlertsView.loggerReady)
                        appLogger.refresh()
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Theme.contentPanelSurface
            radius: Theme.borderRadius
            border.width: Theme.borderWidth
            border.color: Theme.contentPanelBorder

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    spacing: 8

                    StandardButton {
                        id: filterButton
                        text: logsAlertsView.filtersActive ? "Filter On" : "Filter"
                        type: "Secondary"
                        checkable: true
                        checked: filterPopup.visible
                        icon.source: AppAssets.resource("resources/sidebar/filter.svg")
                        tooltip: "Open log filters"
                        onClicked: logsAlertsView.toggleFilterPopup()
                    }

                    Text {
                        Layout.fillWidth: true
                        text: logsAlertsView.filterSummary
                        color: logsAlertsView.filtersActive ? Theme.textPrimary : Theme.textSecondary
                        elide: Text.ElideRight
                        font.pixelSize: Theme.fontSizeSmall
                        font.family: Theme.fontFamily
                    }

                    StandardButton {
                        text: "Reset"
                        type: "Ghost"
                        visible: logsAlertsView.filtersActive
                        tooltip: "Restore default filters"
                        onClicked: logsAlertsView.resetFilters()
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.borderWidth
                    color: Theme.borderColor
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    spacing: 12

                    Text {
                        text: logsAlertsView.visibleEntries.length + " item"
                              + (logsAlertsView.visibleEntries.length === 1 ? "" : "s")
                        color: Theme.textPrimary
                        font.pixelSize: Theme.fontSizeNormal
                        font.family: Theme.fontFamily
                        font.weight: Font.Medium
                    }

                    Rectangle {
                        Layout.preferredWidth: Theme.borderWidth
                        Layout.preferredHeight: 18
                        color: Theme.borderColor
                    }

                    Text {
                        Layout.fillWidth: true
                        text: logsAlertsView.loggerReady ? appLogger.logPath : ""
                        elide: Text.ElideMiddle
                        color: Theme.textSecondary
                        font.pixelSize: Theme.fontSizeSmall
                        font.family: Theme.fontFamily
                    }

                    Text {
                        Layout.maximumWidth: 420
                        visible: logsAlertsView.actionMessage !== ""
                        text: logsAlertsView.actionMessage
                        elide: Text.ElideMiddle
                        color: Theme.textSecondary
                        font.pixelSize: Theme.fontSizeSmall
                        font.family: Theme.fontFamily
                    }

                    StandardButton {
                        text: "Copy"
                        type: "Secondary"
                        tooltip: "Copy visible items as plain text"
                        enabled: logsAlertsView.visibleEntries.length > 0
                        icon.source: AppAssets.resource("resources/logs_alerts/copy.svg")
                        onClicked: logsAlertsView.copyVisibleEntries()
                    }

                    StandardButton {
                        id: exportButton
                        text: "Export TXT"
                        type: "Secondary"
                        tooltip: "Export visible items as a text file"
                        enabled: logsAlertsView.visibleEntries.length > 0
                        icon.source: AppAssets.resource("resources/logs_alerts/file-text.svg")
                        onClicked: logsAlertsView.openExportDialog("txt")
                    }

                    StandardButton {
                        text: "Export JSON"
                        type: "Secondary"
                        tooltip: "Export visible items as a JSON file"
                        enabled: logsAlertsView.visibleEntries.length > 0
                        icon.source: AppAssets.resource("resources/logs_alerts/file-text.svg")
                        onClicked: logsAlertsView.openExportDialog("json")
                    }

                    StandardButton {
                        text: "Clear"
                        type: "Danger"
                        tooltip: "Clear visible section"
                        enabled: logsAlertsView.visibleEntries.length > 0
                        icon.source: AppAssets.resource("resources/logs_alerts/shredder.svg")
                        onClicked: clearDialog.open()
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.borderWidth
                    color: Theme.borderColor
                }

                ListView {
                    id: logList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 8
                    model: logsAlertsView.visibleEntries

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                    }

                    delegate: Rectangle {
                        required property var modelData

                        width: logList.width
                        implicitHeight: rowLayout.implicitHeight + 20
                        radius: Theme.radiusSmall
                        color: rowHover.hovered ? Theme.searchBackground : Theme.searchBackground2
                        border.width: Theme.borderWidth
                        border.color: rowHover.hovered ? Theme.accentColor : Theme.borderColor

                        HoverHandler {
                            id: rowHover
                        }

                        RowLayout {
                            id: rowLayout
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 10

                            Rectangle {
                                Layout.preferredWidth: 108
                                Layout.preferredHeight: 26
                                radius: Theme.radiusSmall
                                color: logsAlertsView.statusBackground(modelData.status)

                                Text {
                                    anchors.centerIn: parent
                                    text: String(modelData.status || "INFO").toUpperCase()
                                    color: logsAlertsView.statusColor(modelData.status)
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Bold
                                }
                            }

                            ColumnLayout {
                                Layout.preferredWidth: 184
                                spacing: 2

                                Text {
                                    Layout.fillWidth: true
                                    text: logsAlertsView.formatTime(modelData.time)
                                    color: Theme.textPrimary
                                    elide: Text.ElideRight
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Medium
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: (modelData.category || "SYSTEM") + " / " + (modelData.source || "app")
                                    color: Theme.textSecondary
                                    elide: Text.ElideRight
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeCaption
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.message || ""
                                color: Theme.textPrimary
                                wrapMode: Text.WordWrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                            }

                            StandardButton {
                                text: "Details"
                                type: "Ghost"
                                tooltip: "View full entry details"
                                onClicked: logsAlertsView.openEntryDetails(modelData)
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: logList.count === 0
                        text: logsAlertsView.activeSectionKey === "alerts"
                              ? "No alerts have been recorded."
                              : "No logs have been recorded."
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeNormal
                    }
                }
            }
        }
    }
}
