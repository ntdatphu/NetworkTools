pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

Item {
    id: root

    required property string host
    property string viewName: "portCounters"

    readonly property bool showingMacTable: viewName === "macTable"
    readonly property string pageTitle: showingMacTable ? "MAC Address Table" : "Port Counters"
    readonly property string pageSubtitle: showingMacTable
        ? "Review learned addresses, VLAN membership, and source interfaces."
        : "Review interface traffic, error totals, and the latest link transition."

    ListModel { id: rowsModel }

    function load() {
        rowsModel.clear()
        const rows = showingMacTable
                   ? dbManager.getSwitchMacTable(host)
                   : dbManager.getSwitchPortCounters(host)
        for (let i = 0; i < rows.length; i++)
            rowsModel.append(rows[i])
    }

    Component.onCompleted: load()
    onHostChanged: load()
    onViewNameChanged: load()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacing16
        spacing: Theme.spacing12

        WorkspaceHeader {
            Layout.fillWidth: true
            title: root.pageTitle
            subtitle: root.pageSubtitle

            StandardButton {
                text: "Reload"
                icon.source: AppAssets.resource("resources/general/database-reload.svg")
                onClicked: root.load()
            }
        }

        DataTable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            count: rowsModel.count
            bodyMargins: 0
            emptyTitle: root.showingMacTable ? "No learned MAC addresses" : "No port counters"
            emptyDescription: "Reload after the selected device has produced monitoring data."
            headerComponent: Component {
                DataTableHeader {
                    RowLayout {
                        anchors.fill: parent
                        spacing: Theme.spacing8

                        DataTableCell {
                            Layout.preferredWidth: 150
                            header: true
                            text: "Interface"
                        }
                        DataTableCell {
                            Layout.preferredWidth: 170
                            header: true
                            text: root.showingMacTable ? "MAC Address" : "Inbound"
                        }
                        DataTableCell {
                            Layout.preferredWidth: 130
                            header: true
                            text: root.showingMacTable ? "VLAN" : "Outbound"
                        }
                        DataTableCell {
                            Layout.fillWidth: true
                            header: true
                            text: root.showingMacTable ? "Type" : "Errors"
                        }
                        DataTableCell {
                            Layout.preferredWidth: 170
                            header: true
                            text: root.showingMacTable ? "Learned At" : "Last Flap"
                        }
                    }
                }
            }

            ListView {
                anchors.fill: parent
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: rowsModel
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                delegate: DataTableRow {
                    id: row

                    required property int index
                    required property var model

                    width: ListView.view.width
                    height: Theme.tableRowHeight
                    rowIndex: index
                    interactive: false

                    RowLayout {
                        anchors.fill: parent
                        spacing: Theme.spacing8

                        DataTableCell {
                            Layout.preferredWidth: 150
                            primary: true
                            text: String(row.model.if_name || "—")
                        }
                        DataTableCell {
                            Layout.preferredWidth: 170
                            primary: true
                            monospaced: root.showingMacTable
                            text: root.showingMacTable
                                ? String(row.model.mac_addr || "—")
                                : String(row.model.in_octets || 0)
                        }
                        DataTableCell {
                            Layout.preferredWidth: 130
                            text: root.showingMacTable
                                ? String(row.model.vlan_id || "—")
                                : String(row.model.out_octets || 0)
                        }
                        DataTableCell {
                            Layout.fillWidth: true
                            text: root.showingMacTable
                                ? String(row.model.mac_type || "—")
                                : String((row.model.in_errors || 0) + (row.model.out_errors || 0))
                        }
                        DataTableCell {
                            Layout.preferredWidth: 170
                            text: root.showingMacTable
                                ? String(row.model.learned_at || "—")
                                : String(row.model.last_flap || "Never")
                        }
                    }
                }
            }
        }
    }
}
