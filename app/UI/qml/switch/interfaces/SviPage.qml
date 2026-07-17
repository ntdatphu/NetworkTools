pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI
import UI as App

Item {
    id: root
    objectName: "loadedSwitchSviPage"

    required property string host
    property int formMode: 0
    property int selectedIndex: -1
    property bool dirty: false
    property bool ipRoutingEnabled: false
    property var draftData: ({})
    property string message: ""
    property bool messageError: false
    readonly property bool compactLayout: width < Theme.dataWorkspaceBreakpoint
    readonly property bool hasDetail: formMode !== 0 || selectedRow() !== null

    ListModel { id: sviModel }

    function clone(value) { return JSON.parse(JSON.stringify(value || {})) }
    function selectedRow() {
        return selectedIndex >= 0 && selectedIndex < sviModel.count
             ? sviModel.get(selectedIndex) : null
    }
    function activeData() { return formMode === 0 ? (selectedRow() || {}) : draftData }
    function load() {
        sviModel.clear()
        const rows = dbManager.getSwitchSvis(host)
        for (let i = 0; i < rows.length; i++) sviModel.append(rows[i])
        selectedIndex = sviModel.count
                      ? Math.min(Math.max(selectedIndex, 0), sviModel.count - 1) : -1
        formMode = 0
        dirty = false
        draftData = selectedRow() ? clone(selectedRow()) : ({})
        const routing = dbManager.getSwitchIpRouting(host)
        ipRoutingEnabled = Boolean(routing.ip_routing || false)
    }
    function beginCreate() {
        draftData = { id: 0, vlan_id: "", ip_address: "", subnet_mask: "", shutdown: false }
        formMode = 1
        dirty = false
    }
    function beginEdit() {
        if (!selectedRow()) return
        draftData = clone(selectedRow())
        formMode = 2
        dirty = false
    }
    function updateField(name, value) {
        draftData[name] = value
        dirty = true
        draftDataChanged()
    }
    function save() {
        const result = dbManager.saveSwitchSvi(host, draftData)
        message = String(result.message || "")
        messageError = !result.ok
        if (result.ok) load()
    }
    function cancel() {
        formMode = 0
        dirty = false
        draftData = selectedRow() ? clone(selectedRow()) : ({})
    }
    function toggleIpRouting() {
        const result = dbManager.saveSwitchIpRouting(host, !ipRoutingEnabled)
        message = String(result.message || "")
        messageError = !result.ok
        if (result.ok) ipRoutingEnabled = !ipRoutingEnabled
    }

    Component.onCompleted: load()
    onHostChanged: load()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacing16
        spacing: Theme.spacing12

        WorkspaceHeader {
            Layout.fillWidth: true
            title: "Switch Virtual Interfaces"
            subtitle: "Manage Layer 3 VLAN interfaces and device IP-routing state."

            StandardButton {
                text: "IP routing: " + (root.ipRoutingEnabled ? "Enabled" : "Disabled")
                type: root.ipRoutingEnabled ? "Secondary" : "Ghost"
                onClicked: root.toggleIpRouting()
            }
            App.CrudFormActions {
                formMode: root.formMode
                hasSelection: root.selectedIndex >= 0
                dirty: root.dirty
                valid: String(root.draftData.vlan_id || "") !== ""
                saving: false
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
            id: sviSplit
            Layout.fillWidth: true
            Layout.fillHeight: true
            orientation: root.compactLayout ? Qt.Vertical : Qt.Horizontal
            handle: StandardSplitHandle { orientation: sviSplit.orientation }

            DataTable {
                SplitView.fillWidth: !root.compactLayout
                SplitView.fillHeight: root.compactLayout
                SplitView.minimumWidth: root.compactLayout ? 0 : 420
                SplitView.minimumHeight: root.compactLayout ? 220 : 0
                SplitView.preferredHeight: root.compactLayout
                                           ? Math.max(240, sviSplit.height * 0.52)
                                           : sviSplit.height
                count: sviModel.count
                bodyMargins: 0
                emptyTitle: "No SVIs"
                emptyDescription: "Use Add to create the first Layer 3 VLAN interface."
                headerComponent: Component {
                    DataTableHeader {
                        RowLayout {
                            anchors.fill: parent
                            spacing: Theme.spacing8
                            DataTableCell { Layout.preferredWidth: 92; header: true; text: "Interface" }
                            DataTableCell { Layout.preferredWidth: 130; header: true; text: "VLAN Name" }
                            DataTableCell { Layout.fillWidth: true; header: true; text: "IP Address" }
                            DataTableCell { Layout.preferredWidth: 84; header: true; text: "Status" }
                        }
                    }
                }

                ListView {
                    id: sviList
                    anchors.fill: parent
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: sviModel
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                    delegate: DataTableRow {
                        id: row
                        required property int index
                        required property int vlan_id
                        required property string vlan_name
                        required property var ip_address
                        required property var subnet_mask
                        required property int shutdown

                        width: ListView.view.width
                        height: Theme.tableRowHeight
                        rowIndex: index
                        selected: root.selectedIndex === index
                        interactive: root.formMode === 0

                        RowLayout {
                            anchors.fill: parent
                            spacing: Theme.spacing8
                            DataTableCell { Layout.preferredWidth: 92; primary: true; text: "Vlan" + row.vlan_id }
                            DataTableCell { Layout.preferredWidth: 130; text: row.vlan_name || "—" }
                            DataTableCell {
                                Layout.fillWidth: true
                                primary: true
                                text: row.ip_address
                                      ? row.ip_address + " / " + (row.subnet_mask || "") : "No IP"
                            }
                            App.StatusBadge { Layout.preferredWidth: 84; value: row.shutdown ? "down" : "up" }
                        }
                        TapHandler {
                            enabled: root.formMode === 0
                            onTapped: {
                                root.selectedIndex = row.index
                                root.draftData = root.clone(root.selectedRow())
                            }
                        }
                    }
                }
            }

            DataTableFrame {
                SplitView.fillWidth: root.compactLayout
                SplitView.fillHeight: !root.compactLayout
                SplitView.preferredWidth: root.compactLayout ? sviSplit.width
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
                            title: "No SVI selected"
                            description: "Select a table row or choose Add to create an SVI."
                        }

                        ColumnLayout {
                            id: detailLayout
                            visible: root.hasDetail
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: Theme.spacing8

                            FormSection {
                                Layout.fillWidth: true
                                title: root.formMode === 1 ? "Create SVI" : "SVI Details"
                                StandardTextField {
                                    Layout.fillWidth: true
                                    labelText: "VLAN ID"
                                    readOnly: root.formMode === 0
                                    text: String(root.activeData().vlan_id || "")
                                    onTextEdited: value => root.updateField("vlan_id", value)
                                }
                                StandardTextField {
                                    Layout.fillWidth: true
                                    labelText: "IP address"
                                    readOnly: root.formMode === 0
                                    text: String(root.activeData().ip_address || "")
                                    onTextEdited: value => root.updateField("ip_address", value)
                                }
                                StandardTextField {
                                    Layout.fillWidth: true
                                    labelText: "Subnet mask"
                                    readOnly: root.formMode === 0
                                    text: String(root.activeData().subnet_mask || "")
                                    onTextEdited: value => root.updateField("subnet_mask", value)
                                }
                                StandardCheckBox {
                                    text: "Administratively shutdown"
                                    enabled: root.formMode !== 0
                                    checked: Boolean(root.activeData().shutdown || false)
                                    onToggled: root.updateField("shutdown", checked)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
