pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI
import UI as App

Item {
    id: root
    required property string host
    property bool allowRouted: false
    property bool routedOnly: false
    property string viewMode: "interfaces"
    property int formMode: 0
    property int selectedIndex: -1
    property bool dirty: false
    property bool saving: false
    property var draftData: ({})
    property string message: ""
    property bool messageError: false
    readonly property bool compactLayout: width < Theme.dataWorkspaceBreakpoint
    readonly property string pageTitle: {
        if (root.routedOnly) return "Routed Ports"
        if (root.viewMode === "portSecurity") return "Port Security"
        if (root.viewMode === "stormControl") return "Storm Control"
        return "Switch Ports"
    }
    readonly property string pageSubtitle: {
        if (root.routedOnly) return "Manage Layer 3 switch-port profiles for this device."
        if (root.viewMode === "portSecurity")
            return "Configure access-port MAC limits and violation behavior."
        if (root.viewMode === "stormControl")
            return "Configure broadcast, multicast and unknown-unicast thresholds."
        return "Manage port modes, VLAN membership and protection settings."
    }

    ListModel { id: interfaceModel }

    function clone(value) { return JSON.parse(JSON.stringify(value || {})) }
    function selectedRow() {
        return selectedIndex >= 0 && selectedIndex < interfaceModel.count
             ? interfaceModel.get(selectedIndex) : null
    }
    function defaultDraft() {
        return {
            id: 0,
            if_name: "",
            description: "",
            mode: routedOnly ? "routed" : "access",
            admin_status: "up",
            oper_status: "unknown",
            speed: "auto",
            duplex: "auto",
            access_vlan: 1,
            voice_vlan: "",
            allowed_vlans: "all",
            native_vlan: 1,
            encapsulation: "dot1q",
            pruning_vlans: "none",
            portfast: "disabled",
            bpduguard: "disabled",
            bpdufilter: "disabled",
            root_guard: "disabled",
            loop_guard: "disabled",
            port_security_enabled: false,
            max_mac: 1,
            violation: "shutdown",
            sticky: false,
            aging_type: "absolute",
            aging_time: 0,
            storm_enabled: false,
            bc_level: 20,
            mc_level: 20,
            uc_level: 80,
            storm_action: "shutdown"
        }
    }
    function load() {
        interfaceModel.clear()
        const rows = dbManager.getSwitchInterfaces(host)
        for (let i = 0; i < rows.length; i++) {
            const securityView = viewMode === "portSecurity" || viewMode === "stormControl"
            if (routedOnly ? rows[i].mode === "routed"
                           : (!securityView || rows[i].mode !== "routed"))
                interfaceModel.append(rows[i])
        }
        selectedIndex = interfaceModel.count > 0
                      ? Math.min(Math.max(selectedIndex, 0), interfaceModel.count - 1)
                      : -1
        formMode = 0
        dirty = false
        draftData = selectedRow() ? clone(selectedRow()) : ({})
    }
    function beginCreate() {
        draftData = defaultDraft()
        formMode = 1
        dirty = false
    }
    function beginEdit() {
        if (selectedRow()) {
            draftData = clone(selectedRow())
            formMode = 2
            dirty = false
        }
    }
    function updateField(name, value) {
        draftData[name] = value
        dirty = true
        draftDataChanged()
    }
    function cancel() {
        formMode = 0
        dirty = false
        draftData = selectedRow() ? clone(selectedRow()) : ({})
    }
    function save() {
        saving = true
        const result = dbManager.saveSwitchInterface(host, draftData)
        saving = false
        message = String(result.message || "")
        messageError = !result.ok
        if (result.ok)
            load()
    }

    Component.onCompleted: load()
    onHostChanged: load()
    onRoutedOnlyChanged: load()
    onViewModeChanged: load()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacing16
        spacing: Theme.spacing12

        WorkspaceHeader {
            Layout.fillWidth: true
            title: root.pageTitle
            subtitle: root.pageSubtitle

            App.CrudFormActions {
                formMode: root.formMode
                hasSelection: root.selectedIndex >= 0
                dirty: root.dirty
                valid: String(root.draftData.if_name || "").trim() !== ""
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
            id: portSplit
            Layout.fillWidth: true
            Layout.fillHeight: true
            orientation: root.compactLayout ? Qt.Vertical : Qt.Horizontal
            handle: StandardSplitHandle { orientation: portSplit.orientation }

            SwitchPortTable {
                SplitView.fillWidth: !root.compactLayout
                SplitView.fillHeight: root.compactLayout
                SplitView.preferredHeight: root.compactLayout
                                           ? Math.max(240, portSplit.height * 0.48)
                                           : portSplit.height
                SplitView.minimumHeight: root.compactLayout ? 220 : 0
                SplitView.minimumWidth: root.compactLayout ? 0 : 420
                sourceModel: interfaceModel
                selectedIndex: root.selectedIndex
                selectionEnabled: root.formMode === 0
                emptyTitle: root.viewMode === "portSecurity"
                            ? "No ports available for Port Security"
                            : root.viewMode === "stormControl"
                              ? "No ports available for Storm Control"
                              : root.routedOnly ? "No routed ports" : "No switch ports"
                emptyDescription: "Use Add to create the first desired-state entry."
                onRowSelected: index => {
                    root.selectedIndex = index
                    root.draftData = root.clone(root.selectedRow())
                }
            }
            InterfaceInspector {
                SplitView.fillWidth: root.compactLayout
                SplitView.fillHeight: !root.compactLayout
                SplitView.preferredWidth: root.compactLayout
                                          ? portSplit.width
                                          : Math.min(460, root.width * 0.42)
                SplitView.minimumWidth: root.compactLayout ? 0 : 340
                SplitView.preferredHeight: root.compactLayout
                                           ? Math.max(260, portSplit.height * 0.52)
                                           : portSplit.height
                SplitView.minimumHeight: root.compactLayout ? 240 : 0
                draft: root.formMode === 0 ? (root.selectedRow() || ({})) : root.draftData
                editing: root.formMode !== 0
                allowRouted: root.allowRouted
                routedOnly: root.routedOnly
                viewMode: root.viewMode
                onFieldChanged: (name, value) => root.updateField(name, value)
            }
        }
    }
}
