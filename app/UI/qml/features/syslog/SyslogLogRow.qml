pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import UI

DataTableRow {
    id: root

    required property var rowData
    property bool compactColumns: false
    property bool narrowColumns: false
    signal selectedRequested()
    signal activated(var rowData)

    readonly property int severity: Number(rowData.severity === undefined ? 6 : rowData.severity)
    readonly property color severityColor: severity <= 3 ? Theme.alertError
                                           : severity === 4 ? Theme.alertWarning
                                           : severity === 5 ? Theme.accentColor
                                           : Theme.textSecondary
    readonly property var severityNames: [
        "Emergency", "Alert", "Critical", "Error",
        "Warning", "Notice", "Info", "Debug"
    ]

    height: Theme.tableRowHeight

    RowLayout {
        anchors.fill: parent
        spacing: Theme.spacing8

        DataTableCell {
            visible: !root.narrowColumns
            Layout.preferredWidth: root.compactColumns ? 110 : 150
            monospaced: true
            text: String(root.rowData.device_time || root.rowData.received_at || "—")
        }
        DataTableCell {
            Layout.preferredWidth: root.compactColumns ? 104 : 120
            primary: true
            text: String(root.rowData.device_host || root.rowData.source_ip || "—")
        }
        DataTableCell {
            visible: !root.compactColumns
            Layout.preferredWidth: 120
            monospaced: true
            text: String(root.rowData.source_ip || "—")
        }
        DataTableCell {
            Layout.preferredWidth: root.compactColumns ? 116 : 132
            color: root.severityColor
            text: "%1 / %2 %3".arg(root.rowData.facility || "—")
                               .arg(root.severity)
                               .arg(root.severityNames[root.severity] || "Unknown")
        }
        DataTableCell {
            visible: !root.compactColumns
            Layout.preferredWidth: 120
            monospaced: true
            text: String(root.rowData.mnemonic || "—")
        }
        DataTableCell {
            Layout.fillWidth: true
            primary: true
            text: String(root.rowData.message || "—")
        }
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton
        onTapped: root.selectedRequested()
        onDoubleTapped: root.activated(root.rowData)
    }
}
