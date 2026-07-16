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
    property int formMode: 0
    property int selectedIndex: -1
    property bool dirty: false
    property bool saving: false
    property var draftData: ({})
    property string message: ""
    property bool messageError: false

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
            if (!routedOnly || rows[i].mode === "routed")
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

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacing16
        spacing: Theme.spacing12

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: root.routedOnly ? "Routed Ports" : "Switch Ports"
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeTitle
                font.bold: true
            }
            Item { Layout.fillWidth: true }
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

        Text {
            visible: root.message !== ""
            text: root.message
            color: root.messageError ? Theme.alertError : Theme.alertSuccess
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
        }

        SplitView {
            Layout.fillWidth: true
            Layout.fillHeight: true

            SwitchPortTable {
                SplitView.fillWidth: true
                SplitView.minimumWidth: 420
                sourceModel: interfaceModel
                selectedIndex: root.selectedIndex
                selectionEnabled: root.formMode === 0
                onRowSelected: index => {
                    root.selectedIndex = index
                    root.draftData = root.clone(root.selectedRow())
                }
            }
            InterfaceInspector {
                SplitView.preferredWidth: Math.min(430, root.width * 0.42)
                SplitView.minimumWidth: 320
                draft: root.formMode === 0 ? (root.selectedRow() || ({})) : root.draftData
                editing: root.formMode !== 0
                allowRouted: root.allowRouted
                routedOnly: root.routedOnly
                onFieldChanged: (name, value) => root.updateField(name, value)
            }
        }
    }
}
