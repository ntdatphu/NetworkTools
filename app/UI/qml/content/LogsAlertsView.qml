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
    property bool previousSessionExpanded: false
    readonly property var defaultStatusFilters: ["INFO", "SUCCESS", "WARNING", "ERROR", "CRITICAL"]
    readonly property var defaultCategoryFilters: ["ACTIVITY", "VALIDATION", "CONFIGURATION", "SYSTEM"]
    readonly property bool loggerReady: typeof appLogger !== "undefined" && appLogger !== null
    property var allEntries: []
    readonly property string currentSessionStartedAt: loggerReady ? appLogger.sessionStartedAt : ""
    property var currentSessionEntries: []
    property var previousSessionEntries: []
    property var visibleEntries: []
    property var logListEntries: []
    readonly property string sectionTitle: activeSectionKey === "alerts" ? qsTr("Alerts") : qsTr("Logs")
    readonly property bool filtersActive: !sameFilters(activeStatusFilters, defaultStatusFilters)
                                          || !sameFilters(activeCategoryFilters, defaultCategoryFilters)
    readonly property string filterSummary: qsTr("Severity: ") + filterLabel(activeStatusFilters, statusOptions, defaultStatusFilters, qsTr("All"))
                                            + qsTr("; Category: ") + filterLabel(activeCategoryFilters, categoryOptions, defaultCategoryFilters, qsTr("Default"))
    readonly property var statusOptions: [
        { "key": "INFO", "label": qsTr("Info"), "icon": AppAssets.resource("resources/statusbar/info.svg") },
        { "key": "SUCCESS", "label": qsTr("Success"), "icon": AppAssets.resource("resources/statusbar/check.svg") },
        { "key": "WARNING", "label": qsTr("Warning"), "icon": AppAssets.resource("resources/statusbar/warning.svg") },
        { "key": "ERROR", "label": qsTr("Error"), "icon": AppAssets.resource("resources/statusbar/error.svg") },
        { "key": "CRITICAL", "label": qsTr("Critical"), "icon": AppAssets.resource("resources/statusbar/error.svg") }
    ]
    readonly property var categoryOptions: [
        { "key": "ACTIVITY", "label": qsTr("Activity"), "icon": AppAssets.resource("resources/activitybar/dashboard.svg") },
        { "key": "VALIDATION", "label": qsTr("Validation"), "icon": AppAssets.resource("resources/statusbar/warning.svg") },
        { "key": "CONFIGURATION", "label": qsTr("Config"), "icon": AppAssets.resource("resources/featurebar/terminal.svg") },
        { "key": "SYSTEM", "label": qsTr("System"), "icon": AppAssets.resource("resources/activitybar/python.svg") },
        { "key": "DEVELOPER", "label": qsTr("Developer"), "icon": AppAssets.resource("resources/activitybar/settings.svg") }
    ]
    readonly property int logStatusColumnWidth: 116
    readonly property int logMetaColumnWidth: 220
    readonly property int logActionColumnWidth: 88
    readonly property int logColumnSpacing: 14
    readonly property int logRowHorizontalPadding: 12
    readonly property int logRowMinHeight: 58
    readonly property int logStatusColumnX: logRowHorizontalPadding
    readonly property int logMetaColumnX: logStatusColumnX + logStatusColumnWidth + logColumnSpacing
    readonly property int logMessageColumnX: logMetaColumnX + logMetaColumnWidth + logColumnSpacing

    function copyEntriesSnapshot(entries) {
        const rows = []
        const source = entries || []
        for (let i = 0; i < source.length; i++)
            rows.push(source[i])
        return rows
    }

    function reloadEntries() {
        logsAlertsView.allEntries = logsAlertsView.loggerReady
                ? copyEntriesSnapshot(appLogger.logs)
                : []
        logsAlertsView.refreshLogRows()
    }

    function refreshLogRows() {
        const currentRows = filteredEntries(
                    logsAlertsView.allEntries,
                    logsAlertsView.activeStatusFilters,
                    logsAlertsView.activeCategoryFilters,
                    logsAlertsView.activeSectionKey,
                    false,
                    logsAlertsView.currentSessionStartedAt)
        const previousRows = filteredEntries(
                    logsAlertsView.allEntries,
                    logsAlertsView.activeStatusFilters,
                    logsAlertsView.activeCategoryFilters,
                    logsAlertsView.activeSectionKey,
                    true,
                    logsAlertsView.currentSessionStartedAt)
        logsAlertsView.currentSessionEntries = currentRows
        logsAlertsView.previousSessionEntries = previousRows
        logsAlertsView.visibleEntries = logsAlertsView.previousSessionExpanded
                ? currentRows.concat(previousRows)
                : currentRows.slice()
        logsAlertsView.logListEntries = groupedLogEntries(
                    currentRows,
                    previousRows,
                    logsAlertsView.previousSessionExpanded)
    }

    function logMessageColumnWidth(rowWidth) {
        const width = rowWidth - logMessageColumnX - logColumnSpacing - logActionColumnWidth - logRowHorizontalPadding
        return Math.max(160, width)
    }

    function numericCount(value) {
        const count = Number(value || 0)
        return isNaN(count) ? 0 : count
    }

    function isPreviousSessionEntry(entry, boundary) {
        const entryTime = String((entry || {}).time || "")
        return boundary !== "" && entryTime !== "" && entryTime < boundary
    }

    function filteredEntries(entries, statusFilters, categoryFilters, sectionKey, previousSessionOnly, sessionBoundary) {
        const rows = []
        const source = entries || []
        const statuses = statusFilters || []
        const categories = categoryFilters || []
        const boundary = sessionBoundary || ""
        for (let i = source.length - 1; i >= 0; i--) {
            const item = source[i]
            if (isPreviousSessionEntry(item, boundary) !== previousSessionOnly)
                continue
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

    function groupedLogEntries(currentEntries, previousEntries, expanded) {
        const rows = (currentEntries || []).slice()
        const oldRows = previousEntries || []
        if (oldRows.length > 0) {
            rows.push({
                "rowType": "previousSessionHeader",
                "count": oldRows.length
            })
            if (expanded) {
                for (let i = 0; i < oldRows.length; i++)
                    rows.push(oldRows[i])
            }
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
            return qsTr("None")
        if (defaultText !== "" && sameFilters(selected, defaultFilters || []))
            return defaultText
        if (selected.length === options.length)
            return qsTr("All")

        const labels = []
        for (let i = 0; i < options.length; i++) {
            if (selected.indexOf(options[i].key) !== -1)
                labels.push(options[i].label)
        }

        if (labels.length <= 2)
            return labels.join(", ")
        return qsTr("%1 selected").arg(labels.length)
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
            actionMessage = qsTr("Copied %1 item(s) as plain text.").arg(logsAlertsView.visibleEntries.length)
    }

    onActiveSectionKeyChanged: logsAlertsView.refreshLogRows()
    onActiveStatusFiltersChanged: logsAlertsView.refreshLogRows()
    onActiveCategoryFiltersChanged: logsAlertsView.refreshLogRows()
    onPreviousSessionExpandedChanged: logsAlertsView.refreshLogRows()
    onCurrentSessionStartedAtChanged: logsAlertsView.refreshLogRows()

    Component.onCompleted: logsAlertsView.reloadEntries()

    Connections {
        target: logsAlertsView.loggerReady ? appLogger : null

        function onLogsChanged() {
            logsAlertsView.reloadEntries()
        }
    }

    function openExportDialog(format) {
        logsAlertsView.exportFormat = format
        exportDialog.defaultSuffix = format
        exportDialog.nameFilters = format === "json" ? [qsTr("JSON file (*.json)")] : [qsTr("Text file (*.txt)")]
        exportDialog.selectedFile = logsAlertsView.defaultExportName()
        exportDialog.open()
    }

    FileDialog {
        id: exportDialog
        title: qsTr("Export ") + logsAlertsView.sectionTitle
        fileMode: FileDialog.SaveFile
        defaultSuffix: logsAlertsView.exportFormat
        nameFilters: [qsTr("Text file (*.txt)"), qsTr("JSON file (*.json)")]
        onAccepted: {
            if (!logsAlertsView.loggerReady)
                return
            const result = appLogger.exportEntries(selectedFile, logsAlertsView.visibleEntries, logsAlertsView.exportFormat)
            logsAlertsView.actionMessage = result.ok ? result.message + " " + result.path : qsTr("Export failed: ") + result.message
        }
    }

    StandardValidationDialog {
        id: clearDialog
        titleText: qsTr("Clear ") + logsAlertsView.sectionTitle
        messageText: logsAlertsView.activeSectionKey === "alerts"
                     ? qsTr("Clear the currently visible alert entries?")
                     : qsTr("Clear the currently visible log entries?")
        acceptText: qsTr("Clear")
        rejectText: qsTr("Cancel")
        showCancel: true
        onAccepted: {
            if (!logsAlertsView.loggerReady)
                return
            const result = appLogger.clearEntries(logsAlertsView.visibleEntries)
            logsAlertsView.actionMessage = result.ok ? result.message : qsTr("Clear failed: ") + result.message
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
                    text: qsTr("Filters")
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeNormal
                    font.weight: Font.Bold
                }

                StandardButton {
                    text: qsTr("Reset")
                    type: "Ghost"
                    tooltip: qsTr("Restore default filters")
                    enabled: logsAlertsView.filtersActive
                    onClicked: logsAlertsView.resetFilters()
                }
            }

            Text {
                Layout.fillWidth: true
                text: qsTr("SEVERITY")
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
                text: qsTr("CATEGORY")
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
        padding: 18
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
                    text: logsAlertsView.activeSectionKey === "alerts" ? qsTr("Alert Details") : qsTr("Log Details")
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeTitle
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                }

                StandardButton {
                    text: qsTr("Close")
                    type: "Secondary"
                    onClicked: detailDialog.close()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: detailMetaGrid.implicitHeight + 24
                color: Theme.contentPanelSurface
                radius: Theme.radiusSmall
                border.color: Theme.borderColor
                border.width: Theme.borderWidth

                GridLayout {
                    id: detailMetaGrid
                    anchors.fill: parent
                    anchors.margins: 12
                    columns: 4
                    columnSpacing: 12
                    rowSpacing: 8

                    Text {
                        Layout.preferredWidth: 72
                        text: qsTr("Status")
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeCaption
                        font.weight: Font.Bold
                    }

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
                        Layout.preferredWidth: 72
                        text: qsTr("Time")
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeCaption
                        font.weight: Font.Bold
                    }

                    Text {
                        Layout.fillWidth: true
                        text: logsAlertsView.formatTime(logsAlertsView.detailEntry.time)
                        color: Theme.textPrimary
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                    }

                    Text {
                        Layout.preferredWidth: 72
                        text: qsTr("Category")
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeCaption
                        font.weight: Font.Bold
                    }

                    Text {
                        Layout.preferredWidth: 110
                        text: logsAlertsView.detailEntry.category || "SYSTEM"
                        color: Theme.textPrimary
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Text {
                        Layout.preferredWidth: 72
                        text: qsTr("Source")
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeCaption
                        font.weight: Font.Bold
                    }

                    Text {
                        Layout.fillWidth: true
                        text: logsAlertsView.detailEntry.source || "app"
                        color: Theme.textPrimary
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: qsTr("MESSAGE")
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeCaption
                font.weight: Font.Bold
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
                    anchors.margins: 12
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
                    text: qsTr("Copy")
                    type: "Secondary"
                    enabled: logsAlertsView.loggerReady
                    icon.source: AppAssets.resource("resources/logs_alerts/copy.svg")
                    onClicked: {
                        if (logsAlertsView.loggerReady && appLogger.copyEntries([logsAlertsView.detailEntry]))
                            logsAlertsView.actionMessage = qsTr("Copied selected item as plain text.")
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
                          ? qsTr("Current-session warnings, errors, and critical issues are shown first. Previous-session alerts are collapsed by default.")
                          : qsTr("Current-session activity, validation, configuration, and system events are shown first. Previous-session logs are collapsed by default.")
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontSizeSmall
                    font.family: Theme.fontFamily
                }
            }

            StandardButton {
                text: qsTr("Refresh")
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
                        text: logsAlertsView.filtersActive ? qsTr("Filter On") : qsTr("Filter")
                        type: "Secondary"
                        checkable: true
                        checked: filterPopup.visible
                        icon.source: AppAssets.resource("resources/sidebar/filter.svg")
                        tooltip: qsTr("Open log filters")
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
                        text: qsTr("Reset")
                        type: "Ghost"
                        visible: logsAlertsView.filtersActive
                        tooltip: qsTr("Restore default filters")
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
                        text: qsTr("%n item(s)", "", logsAlertsView.visibleEntries.length)
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
                        text: qsTr("Copy")
                        type: "Secondary"
                        tooltip: qsTr("Copy visible items as plain text")
                        enabled: logsAlertsView.visibleEntries.length > 0
                        icon.source: AppAssets.resource("resources/logs_alerts/copy.svg")
                        onClicked: logsAlertsView.copyVisibleEntries()
                    }

                    StandardButton {
                        id: exportButton
                        text: qsTr("Export TXT")
                        type: "Secondary"
                        tooltip: qsTr("Export visible items as a text file")
                        enabled: logsAlertsView.visibleEntries.length > 0
                        icon.source: AppAssets.resource("resources/logs_alerts/file-text.svg")
                        onClicked: logsAlertsView.openExportDialog("txt")
                    }

                    StandardButton {
                        text: qsTr("Export JSON")
                        type: "Secondary"
                        tooltip: qsTr("Export visible items as a JSON file")
                        enabled: logsAlertsView.visibleEntries.length > 0
                        icon.source: AppAssets.resource("resources/logs_alerts/file-text.svg")
                        onClicked: logsAlertsView.openExportDialog("json")
                    }

                    StandardButton {
                        text: qsTr("Clear")
                        type: "Danger"
                        tooltip: qsTr("Clear visible section")
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

                Item {
                    id: logHeader
                    Layout.fillWidth: true
                    Layout.preferredHeight: 22

                    Text {
                        x: logsAlertsView.logStatusColumnX
                        width: logsAlertsView.logStatusColumnWidth
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("STATUS")
                        color: Theme.textSecondary
                        horizontalAlignment: Text.AlignLeft
                        verticalAlignment: Text.AlignVCenter
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeCaption
                        font.weight: Font.Bold
                    }

                    Text {
                        x: logsAlertsView.logMetaColumnX
                        width: logsAlertsView.logMetaColumnWidth
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("TIME / SOURCE")
                        color: Theme.textSecondary
                        horizontalAlignment: Text.AlignLeft
                        verticalAlignment: Text.AlignVCenter
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeCaption
                        font.weight: Font.Bold
                    }

                    Text {
                        x: logsAlertsView.logMessageColumnX
                        width: logsAlertsView.logMessageColumnWidth(logHeader.width)
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("MESSAGE")
                        color: Theme.textSecondary
                        horizontalAlignment: Text.AlignLeft
                        verticalAlignment: Text.AlignVCenter
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeCaption
                        font.weight: Font.Bold
                    }
                }

                ListView {
                    id: logList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 6
                    model: logsAlertsView.logListEntries

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                    }

                    delegate: Rectangle {
                        id: logRow
                        required property var modelData
                        readonly property bool isPreviousHeader: modelData.rowType === "previousSessionHeader"

                        width: logList.width
                        implicitHeight: isPreviousHeader ? 40 : Math.max(logsAlertsView.logRowMinHeight, messageText.implicitHeight + 24)
                        radius: Theme.radiusSmall
                        color: isPreviousHeader ? (rowHover.hovered ? Theme.sideBarItemHover : "transparent")
                                                : (rowHover.hovered ? Theme.searchBackground : Theme.searchBackground2)
                        border.width: Theme.borderWidth
                        border.color: isPreviousHeader ? Theme.borderColor
                                                       : (rowHover.hovered ? Theme.accentColor : Theme.borderColor)

                        HoverHandler {
                            id: rowHover
                            cursorShape: logRow.isPreviousHeader ? Qt.PointingHandCursor : Qt.ArrowCursor
                        }

                        TapHandler {
                            enabled: logRow.isPreviousHeader
                            onTapped: logsAlertsView.previousSessionExpanded = !logsAlertsView.previousSessionExpanded
                        }

                        RowLayout {
                            visible: logRow.isPreviousHeader
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 8

                            ThemedIcon {
                                iconSource: AppAssets.resource(logsAlertsView.previousSessionExpanded
                                                               ? "resources/general/chevron-down.svg"
                                                               : "resources/general/chevron-right.svg")
                                iconSize: Theme.iconSizeSmall
                                iconColor: Theme.textSecondary
                                Layout.preferredWidth: 18
                            }

                            Text {
                                Layout.fillWidth: true
                                text: qsTr("Previous session logs")
                                color: Theme.textSecondary
                                elide: Text.ElideRight
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                            }

                            Text {
                                text: qsTr("%n item(s)", "", logsAlertsView.numericCount(modelData.count))
                                color: Theme.textSecondary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeCaption
                            }
                        }

                        Rectangle {
                            id: statusBadge
                            visible: !logRow.isPreviousHeader
                            x: logsAlertsView.logStatusColumnX
                            y: Math.round((parent.height - height) / 2)
                            width: logsAlertsView.logStatusColumnWidth
                            height: 26
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

                        Column {
                            id: metaColumn
                            visible: !logRow.isPreviousHeader
                            x: logsAlertsView.logMetaColumnX
                            width: logsAlertsView.logMetaColumnWidth
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            Text {
                                width: parent.width
                                text: logsAlertsView.formatTime(modelData.time)
                                color: Theme.textPrimary
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignLeft
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                            }

                            Text {
                                width: parent.width
                                text: (modelData.category || "SYSTEM") + " / " + (modelData.source || "app")
                                color: Theme.textSecondary
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignLeft
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeCaption
                            }
                        }

                        Text {
                            id: messageText
                            visible: !logRow.isPreviousHeader
                            x: logsAlertsView.logMessageColumnX
                            width: logsAlertsView.logMessageColumnWidth(logRow.width)
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.message || ""
                            color: Theme.textPrimary
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignLeft
                            verticalAlignment: Text.AlignVCenter
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                        }

                        StandardButton {
                            visible: !logRow.isPreviousHeader
                            x: logRow.width - logsAlertsView.logRowHorizontalPadding - width
                            y: Math.round((parent.height - height) / 2)
                            width: logsAlertsView.logActionColumnWidth
                            height: 32
                            text: qsTr("Details")
                            type: "Ghost"
                            tooltip: qsTr("View full entry details")
                            onClicked: logsAlertsView.openEntryDetails(modelData)
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: logList.count === 0
                        text: logsAlertsView.activeSectionKey === "alerts"
                              ? qsTr("No alerts have been recorded.")
                              : qsTr("No logs have been recorded.")
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeNormal
                    }
                }
            }
        }
    }
}
