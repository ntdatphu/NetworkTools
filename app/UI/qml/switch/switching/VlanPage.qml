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
    }
    function beginCreate() {
        draftData = { id: 0, vlan_id: "", vlan_name: "", state: "active" }
        formMode = 1
        dirty = false
    }
    function beginEdit() {
        const row = rowAt(selectedIndex)
        if (!row)
            return
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
        if (result.ok)
            load()
    }
    function cancel() {
        formMode = 0
        dirty = false
        draftData = ({})
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
                text: "VLAN database"
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
                valid: String(root.draftData.vlan_id || "") !== ""
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

            Rectangle {
                SplitView.fillWidth: true
                SplitView.minimumWidth: 390
                color: Theme.contentSurface
                border.color: Theme.borderColor
                ListView {
                    anchors.fill: parent
                    anchors.margins: Theme.spacing8
                    clip: true
                    spacing: Theme.spacing4
                    model: vlanModel
                    delegate: Rectangle {
                        id: row
                        required property int index
                        required property int vlan_id
                        required property string vlan_name
                        required property string state
                        required property int access_port_count
                        width: ListView.view.width
                        height: 46
                        radius: Theme.radiusSmall
                        color: root.selectedIndex === index ? Theme.sideBarItemSelected
                             : rowTap.hovered ? Theme.sideBarItemHover : "transparent"
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.spacing12
                            anchors.rightMargin: Theme.spacing12
                            Text { Layout.preferredWidth: 80; text: row.vlan_id; color: Theme.textPrimary; font.family: Theme.fontFamily }
                            Text { Layout.fillWidth: true; text: row.vlan_name || "—"; color: Theme.textPrimary; font.family: Theme.fontFamily; elide: Text.ElideRight }
                            Text { Layout.preferredWidth: 90; text: row.access_port_count + " ports"; color: Theme.textSecondary; font.family: Theme.fontFamily }
                            App.StatusBadge { value: row.state }
                        }
                        HoverHandler { id: rowTap }
                        TapHandler {
                            enabled: root.formMode === 0
                            onTapped: root.selectedIndex = row.index
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: vlanModel.count === 0
                        text: "No VLAN saved"
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
                    spacing: Theme.spacing12
                    App.FormSection {
                        Layout.fillWidth: true
                        title: root.formMode === 1 ? "Create VLAN" : "VLAN details"
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
                    Item { Layout.fillHeight: true }
                }
            }
        }
    }
}
