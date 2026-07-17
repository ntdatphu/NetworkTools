pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI
import UI as App

Item {
    id: root

    required property string host
    property int formMode: 0
    property int selectedIndex: -1
    property bool dirty: false
    property bool saving: false
    property var draftData: ({})
    property string message: ""
    property bool messageError: false
    readonly property bool compactLayout: width < Theme.dataWorkspaceBreakpoint
    readonly property bool hasDetail: formMode !== 0 || rowAt(selectedIndex) !== null

    ListModel { id: vlanModel }

    function clone(value) { return JSON.parse(JSON.stringify(value || {})) }
    function rowAt(index) {
        return index >= 0 && index < vlanModel.count ? vlanModel.get(index) : null
    }
    function load() {
        vlanModel.clear()
        const rows = dbManager.getSwitchVlans(host)
        for (let i = 0; i < rows.length; i++)
            vlanModel.append(rows[i])
        selectedIndex = vlanModel.count > 0
                      ? Math.min(Math.max(selectedIndex, 0), vlanModel.count - 1)
                      : -1
        formMode = 0
        dirty = false
        draftData = rowAt(selectedIndex) ? clone(rowAt(selectedIndex)) : ({})
    }
    function beginCreate() {
        draftData = { id: 0, vlan_id: "", vlan_name: "", state: "active" }
        formMode = 1
        dirty = false
    }
    function beginEdit() {
        const row = rowAt(selectedIndex)
        if (!row) return
        draftData = clone(row)
        formMode = 2
        dirty = false
    }
    function updateDraft(name, value) {
        draftData[name] = value
        dirty = true
        draftDataChanged()
    }
    function save() {
        saving = true
        const result = dbManager.saveSwitchVlan(host, draftData)
        saving = false
        message = String(result.message || "")
        messageError = !result.ok
        if (result.ok) load()
    }
    function cancel() {
        formMode = 0
        dirty = false
        draftData = rowAt(selectedIndex) ? clone(rowAt(selectedIndex)) : ({})
    }

    Component.onCompleted: load()
    onHostChanged: load()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacing16
        spacing: Theme.spacing12

        WorkspaceHeader {
            Layout.fillWidth: true
            title: "VLAN Database"
            subtitle: "Manage VLAN desired state and review access-port usage."

            App.CrudFormActions {
                formMode: root.formMode
                hasSelection: root.selectedIndex >= 0
                dirty: root.dirty
                valid: String(root.draftData.vlan_id || "") !== ""
                saving: root.saving
                onAddRequested: root.beginCreate()
                onEditRequested: root.beginEdit()
                onRefreshRequested: root.load()
                onSaveRequested: root.save()
                onCancelRequested: root.cancel()
            }
        }

        InlineMessage {
            Layout.fillWidth: true
            message: root.message
            severity: root.messageError ? "error" : "success"
        }

        SplitView {
            id: vlanSplit
            Layout.fillWidth: true
            Layout.fillHeight: true
            orientation: root.compactLayout ? Qt.Vertical : Qt.Horizontal
            handle: StandardSplitHandle { orientation: vlanSplit.orientation }

            DataTable {
                SplitView.fillWidth: !root.compactLayout
                SplitView.fillHeight: root.compactLayout
                SplitView.minimumWidth: root.compactLayout ? 0 : 390
                SplitView.minimumHeight: root.compactLayout ? 220 : 0
                SplitView.preferredHeight: root.compactLayout
                                           ? Math.max(240, vlanSplit.height * 0.52)
                                           : vlanSplit.height
                count: vlanModel.count
                bodyMargins: 0
                emptyTitle: "No VLANs"
                emptyDescription: "Use Add to create the first VLAN desired-state entry."
                headerComponent: Component {
                    DataTableHeader {
                        RowLayout {
                            anchors.fill: parent
                            spacing: Theme.spacing8
                            DataTableCell { Layout.preferredWidth: 80; header: true; text: "VLAN" }
                            DataTableCell { Layout.fillWidth: true; header: true; text: "Name" }
                            DataTableCell { Layout.preferredWidth: 90; header: true; text: "Usage" }
                            DataTableCell { Layout.preferredWidth: 84; header: true; text: "State" }
                        }
                    }
                }

                ListView {
                    id: vlanList
                    anchors.fill: parent
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: vlanModel
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                    delegate: DataTableRow {
                        id: row
                        required property int index
                        required property int vlan_id
                        required property string vlan_name
                        required property string state
                        required property int access_port_count

                        width: ListView.view.width
                        height: Theme.tableRowHeight
                        rowIndex: index
                        selected: root.selectedIndex === index
                        interactive: root.formMode === 0

                        RowLayout {
                            anchors.fill: parent
                            spacing: Theme.spacing8
                            DataTableCell { Layout.preferredWidth: 80; primary: true; text: row.vlan_id }
                            DataTableCell { Layout.fillWidth: true; primary: true; text: row.vlan_name || "—" }
                            DataTableCell { Layout.preferredWidth: 90; text: row.access_port_count + " ports" }
                            App.StatusBadge { Layout.preferredWidth: 84; value: row.state }
                        }
                        TapHandler {
                            enabled: root.formMode === 0
                            onTapped: {
                                root.selectedIndex = row.index
                                root.draftData = root.clone(root.rowAt(row.index))
                            }
                        }
                    }
                }
            }

            DataTableFrame {
                SplitView.fillWidth: root.compactLayout
                SplitView.fillHeight: !root.compactLayout
                SplitView.preferredWidth: root.compactLayout ? vlanSplit.width
                                                             : Math.min(430, root.width * 0.4)
                SplitView.minimumWidth: root.compactLayout ? 0 : 330
                SplitView.minimumHeight: root.compactLayout ? 220 : 0

                ScrollView {
                    anchors.fill: parent
                    clip: true
                    contentWidth: availableWidth
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                    Item {
                        width: parent.width
                        implicitHeight: root.hasDetail
                                        ? detailLayout.implicitHeight + Theme.spacing16
                                        : parent.height

                        EmptyState {
                            anchors.fill: parent
                            visible: !root.hasDetail
                            title: "No VLAN selected"
                            description: "Select a table row or choose Add to create a VLAN."
                        }

                        ColumnLayout {
                            id: detailLayout
                            visible: root.hasDetail
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: Theme.spacing8
                            spacing: Theme.spacing12

                            FormSection {
                                Layout.fillWidth: true
                                title: root.formMode === 1 ? "Create VLAN" : "VLAN Details"

                                StandardTextField {
                                    Layout.fillWidth: true
                                    labelText: "VLAN ID"
                                    placeholderText: "1–4094"
                                    readOnly: root.formMode === 0
                                    text: root.formMode === 0 && root.rowAt(root.selectedIndex)
                                          ? String(root.rowAt(root.selectedIndex).vlan_id)
                                          : String(root.draftData.vlan_id || "")
                                    onTextEdited: value => root.updateDraft("vlan_id", value)
                                }
                                StandardTextField {
                                    Layout.fillWidth: true
                                    labelText: "Name"
                                    readOnly: root.formMode === 0
                                    text: root.formMode === 0 && root.rowAt(root.selectedIndex)
                                          ? root.rowAt(root.selectedIndex).vlan_name
                                          : String(root.draftData.vlan_name || "")
                                    onTextEdited: value => root.updateDraft("vlan_name", value)
                                }
                                StandardComboBox {
                                    Layout.fillWidth: true
                                    labelText: "State"
                                    model: ["active", "suspend"]
                                    enabled: root.formMode !== 0
                                    currentIndex: {
                                        const value = root.formMode === 0 && root.rowAt(root.selectedIndex)
                                            ? root.rowAt(root.selectedIndex).state
                                            : String(root.draftData.state || "active")
                                        return value === "suspend" ? 1 : 0
                                    }
                                    onActivated: index => root.updateDraft("state", model[index])
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
