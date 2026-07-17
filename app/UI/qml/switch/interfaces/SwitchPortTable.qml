pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI
import UI as App

DataTable {
    id: root

    required property var sourceModel
    property int selectedIndex: -1
    property bool selectionEnabled: true

    signal rowSelected(int index)

    count: sourceModel ? sourceModel.count : 0
    bodyMargins: 0
    emptyTitle: "No switch ports"
    emptyDescription: "Use Add to create the first desired-state entry."
    headerComponent: Component {
        DataTableHeader {
            RowLayout {
                anchors.fill: parent
                spacing: Theme.spacing8

                DataTableCell { Layout.preferredWidth: 150; header: true; text: "Interface" }
                DataTableCell { Layout.preferredWidth: 80; header: true; text: "Mode" }
                DataTableCell { Layout.preferredWidth: 80; header: true; text: "VLAN" }
                DataTableCell { Layout.fillWidth: true; header: true; text: "Description" }
                DataTableCell { Layout.preferredWidth: 90; header: true; text: "Status" }
            }
        }
    }

    ListView {
        id: portList
        anchors.fill: parent
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: root.sourceModel
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        delegate: DataTableRow {
            id: row

            required property int index
            required property string if_name
            required property string description
            required property string mode
            required property string oper_status
            required property var access_vlan
            required property var native_vlan

            width: ListView.view.width
            height: Theme.tableRowHeight
            rowIndex: index
            selected: root.selectedIndex === index
            interactive: root.selectionEnabled

            RowLayout {
                anchors.fill: parent
                spacing: Theme.spacing8

                DataTableCell { Layout.preferredWidth: 150; primary: true; text: row.if_name }
                DataTableCell { Layout.preferredWidth: 80; primary: true; text: row.mode }
                DataTableCell {
                    Layout.preferredWidth: 80
                    text: row.mode === "access" ? (row.access_vlan || "—")
                                                    : (row.native_vlan || "—")
                }
                DataTableCell { Layout.fillWidth: true; text: row.description || "—" }
                App.StatusBadge { Layout.preferredWidth: 90; value: row.oper_status }
            }

            TapHandler {
                enabled: root.selectionEnabled
                onTapped: root.rowSelected(row.index)
            }
        }
    }
}
