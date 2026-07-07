pragma ComponentBehavior: Bound

import QtQuick
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
    readonly property var allEntries: typeof appLogger !== "undefined" ? appLogger.logs : []
    readonly property var visibleEntries: filteredEntries(allEntries, activeStatusFilters, activeCategoryFilters, activeSectionKey)
    readonly property string sectionTitle: activeSectionKey === "alerts" ? "Alerts" : "Logs"
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
            if (statusFilters.indexOf(status) === -1)
                continue
            if (categoryFilters.indexOf(category) === -1)
                continue
            rows.push(item)
        }
        return rows
    }

    function filterEnabled(filters, key) {
        return filters.indexOf(key) !== -1
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
        logsAlertsView.activeStatusFilters = ["INFO", "SUCCESS", "WARNING", "ERROR", "CRITICAL"]
        logsAlertsView.activeCategoryFilters = ["ACTIVITY", "VALIDATION", "CONFIGURATION", "SYSTEM"]
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
        if (typeof appLogger === "undefined")
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
            if (typeof appLogger === "undefined")
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
            if (typeof appLogger === "undefined")
                return
            const result = appLogger.clearEntries(logsAlertsView.visibleEntries)
            logsAlertsView.actionMessage = result.ok ? result.message : "Clear failed: " + result.message
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
                    if (typeof appLogger !== "undefined")
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

                Flow {
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        model: logsAlertsView.statusOptions

                        delegate: StandardButton {
                            required property var modelData

                            text: modelData.label
                            type: "Secondary"
                            checkable: true
                            checked: logsAlertsView.filterEnabled(logsAlertsView.activeStatusFilters, modelData.key)
                            icon.source: modelData.icon
                            tooltip: "Toggle " + modelData.label + " logs"
                            onClicked: logsAlertsView.toggleStatusFilter(modelData.key)
                        }
                    }

                    Repeater {
                        model: logsAlertsView.categoryOptions

                        delegate: StandardButton {
                            required property var modelData

                            text: modelData.label
                            type: "Secondary"
                            checkable: true
                            checked: logsAlertsView.filterEnabled(logsAlertsView.activeCategoryFilters, modelData.key)
                            icon.source: modelData.icon
                            tooltip: modelData.key === "DEVELOPER"
                                     ? "Toggle developer diagnostics"
                                     : "Toggle " + modelData.label + " logs"
                            onClicked: logsAlertsView.toggleCategoryFilter(modelData.key)
                        }
                    }

                    StandardButton {
                        text: "Reset Filters"
                        type: "Secondary"
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
                        text: typeof appLogger !== "undefined" ? appLogger.logPath : ""
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
                        color: Theme.searchBackground2
                        border.width: Theme.borderWidth
                        border.color: Theme.borderColor

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
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
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
