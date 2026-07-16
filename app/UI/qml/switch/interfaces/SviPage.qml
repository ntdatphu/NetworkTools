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
    ListModel { id: sviModel }

    function clone(value) { return JSON.parse(JSON.stringify(value || {})) }
    function selectedRow() {
        return selectedIndex >= 0 && selectedIndex < sviModel.count
             ? sviModel.get(selectedIndex) : null
    }
    function activeData() {
        return formMode === 0 ? (selectedRow() || {}) : draftData
    }
    function load() {
        sviModel.clear()
        const rows = dbManager.getSwitchSvis(host)
        for (let i = 0; i < rows.length; i++)
            sviModel.append(rows[i])
        selectedIndex = sviModel.count
                      ? Math.min(Math.max(selectedIndex, 0), sviModel.count - 1)
                      : -1
        formMode = 0
        dirty = false
        draftData = selectedRow() ? clone(selectedRow()) : ({})
        const routing = dbManager.getSwitchIpRouting(host)
        ipRoutingEnabled = Boolean(routing.ip_routing || false)
    }
    function beginCreate() {
        draftData = {
            id: 0,
            vlan_id: "",
            ip_address: "",
            subnet_mask: "",
            shutdown: false
        }
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
    function save() {
        const result = dbManager.saveSwitchSvi(host, draftData)
        message = String(result.message || "")
        messageError = !result.ok
        if (result.ok)
            load()
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
        if (result.ok)
            ipRoutingEnabled = !ipRoutingEnabled
    }

    Component.onCompleted: load()
    onHostChanged: load()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacing16
        spacing: Theme.spacing12

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "Switch Virtual Interfaces"
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeTitle
                font.bold: true
            }
            Item { Layout.fillWidth: true }
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
        Text {
            visible: root.message !== ""
            text: root.message
            color: root.messageError ? Theme.alertError : Theme.alertSuccess
            font.family: Theme.fontFamily
        }
        SplitView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Rectangle {
                SplitView.fillWidth: true
                SplitView.minimumWidth: 420
                color: Theme.contentSurface
                border.color: Theme.borderColor
                ListView {
                    anchors.fill: parent
                    anchors.margins: Theme.spacing8
                    model: sviModel
                    spacing: Theme.spacing4
                    clip: true
                    delegate: Rectangle {
                        id: row
                        required property int index
                        required property int vlan_id
                        required property string vlan_name
                        required property var ip_address
                        required property var subnet_mask
                        required property int shutdown
                        width: ListView.view.width
                        height: 46
                        radius: Theme.radiusSmall
                        color: root.selectedIndex === index ? Theme.sideBarItemSelected
                             : hover.hovered ? Theme.sideBarItemHover : "transparent"
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Theme.spacing12
                            Text { Layout.preferredWidth: 80; text: "Vlan" + row.vlan_id; color: Theme.textPrimary; font.family: Theme.fontFamily }
                            Text { Layout.preferredWidth: 120; text: row.vlan_name || "—"; color: Theme.textSecondary; font.family: Theme.fontFamily }
                            Text { Layout.fillWidth: true; text: row.ip_address ? row.ip_address + " / " + (row.subnet_mask || "") : "No IP"; color: Theme.textPrimary; font.family: Theme.fontFamily }
                            App.StatusBadge { value: row.shutdown ? "down" : "up" }
                        }
                        HoverHandler { id: hover }
                        TapHandler {
                            enabled: root.formMode === 0
                            onTapped: {
                                root.selectedIndex = row.index
                                root.draftData = root.clone(root.selectedRow())
                            }
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: sviModel.count === 0
                        text: "No SVI saved"
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                    }
                }
            }
            ScrollView {
                SplitView.preferredWidth: Math.min(390, root.width * 0.4)
                SplitView.minimumWidth: 310
                contentWidth: availableWidth
                ColumnLayout {
                    width: parent.width
                    App.FormSection {
                        Layout.fillWidth: true
                        title: root.formMode === 1 ? "Create SVI" : "SVI details"
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
                            text: "Shutdown"
                            enabled: root.formMode !== 0
                            checked: Boolean(root.activeData().shutdown || false)
                            onToggled: root.updateField("shutdown", checked)
                        }
                    }
                    Item { Layout.fillHeight: true }
                }
            }
        }
    }
}
