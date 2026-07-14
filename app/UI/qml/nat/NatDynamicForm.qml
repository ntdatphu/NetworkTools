pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

Rectangle {
    id: natDynamicForm
    color: Theme.contentBackground

    property string currentHostIp: ""
    property int editingDynamicId: -1
    property int nextLocalId: -1
    property var pendingDeletes: []
    property var aclNames: []
    property bool hasPendingLocalChanges: false
    signal dataChanged()

    function isEditing() { return editingDynamicId !== -1 }

    function indexOfValue(values, value) {
        for (let i = 0; i < values.length; i++)
            if (String(values[i]) === String(value)) return i
        return -1
    }

    function clearForm() {
        editingDynamicId = -1
        poolNameField.text = ""
        startIpField.text = ""
        endIpField.text = ""
        netmaskField.text = ""
        dynamicAclCombo.currentIndex = aclNames.length > 0 ? 0 : -1
    }

    function editPool(row) {
        editingDynamicId = row.nat_dynamic_id
        poolNameField.text = row.pool_name || ""
        startIpField.text = row.start_ip || ""
        endIpField.text = row.end_ip || ""
        netmaskField.text = row.netmask || ""
        dynamicAclCombo.currentIndex = indexOfValue(aclNames, row.acl_name)
    }

    function reloadAclNames() {
        aclNames = currentHostIp === "" ? [] : dbManager.getNatAclNames(currentHostIp)
        if (!isEditing()) dynamicAclCombo.currentIndex = aclNames.length > 0 ? 0 : -1
    }

    function refreshDirtyFlag() {
        let dirty = pendingDeletes.length > 0
        for (let i = 0; i < poolModel.count && !dirty; i++) dirty = poolModel.get(i)._isNew || poolModel.get(i)._isEdited
        hasPendingLocalChanges = dirty
    }

    function notify(message, type) {
        if (typeof statusBar !== "undefined")
            statusBar.showMessage(message, type)
    }

    function reloadPools() {
        poolModel.clear()
        pendingDeletes = []
        nextLocalId = -1
        hasPendingLocalChanges = false
        if (currentHostIp === "") return
        const rows = dbManager.getNatDynamicPools(currentHostIp)
        for (let i = 0; i < rows.length; i++) {
            const row = rows[i]
            row._isNew = false
            row._isEdited = false
            poolModel.append(row)
        }
    }

    function stagePool() {
        const values = { pool_name: poolNameField.text.trim(), start_ip: startIpField.text.trim(),
            end_ip: endIpField.text.trim(), netmask: netmaskField.text.trim(), acl_name: dynamicAclCombo.currentValue }
        if (isEditing()) {
            for (let i = 0; i < poolModel.count; i++) {
                if (poolModel.get(i).nat_dynamic_id !== editingDynamicId) continue
                for (const key in values) poolModel.setProperty(i, key, values[key])
                if (!poolModel.get(i)._isNew) poolModel.setProperty(i, "_isEdited", true)
                break
            }
        } else poolModel.append({ nat_dynamic_id: nextLocalId--, pool_name: values.pool_name,
            start_ip: values.start_ip, end_ip: values.end_ip, netmask: values.netmask,
            acl_name: values.acl_name, _isNew: true, _isEdited: false })
        clearForm()
        refreshDirtyFlag()
    }

    function removePool(index, row) {
        if (!row._isNew) pendingDeletes = pendingDeletes.concat([row.nat_dynamic_id])
        poolModel.remove(index)
        if (editingDynamicId === row.nat_dynamic_id) clearForm()
        refreshDirtyFlag()
    }

    function saveChanges() {
        let ok = true
        for (let i = 0; i < pendingDeletes.length && ok; i++) ok = dbManager.deleteNatDynamicPool(pendingDeletes[i])
        for (let i = 0; i < poolModel.count && ok; i++) {
            const row = poolModel.get(i)
            if (row._isEdited) ok = dbManager.deleteNatDynamicPool(row.nat_dynamic_id)
            if (ok && (row._isNew || row._isEdited)) ok = dbManager.addNatDynamicPool(currentHostIp, row.pool_name, row.start_ip, row.end_ip, row.netmask, row.acl_name)
        }
        reloadPools()
        reloadAclNames()
        if (ok) dataChanged()
        notify(ok ? "Saved dynamic NAT changes." : "Save dynamic NAT changes failed.", ok ? "success" : "error")
    }

    onCurrentHostIpChanged: {
        clearForm()
        reloadAclNames()
        reloadPools()
    }
    Component.onCompleted: { reloadAclNames(); reloadPools() }

    ListModel { id: poolModel }

    SplitView {
        anchors.fill: parent
        anchors.bottomMargin: 60
        orientation:  Qt.Horizontal

        handle: StandardSplitHandle {}

        // ── CỘT TRÁI — Form nhập ──
        SplitFormPane {
            SplitView.preferredWidth: 320
            SplitView.minimumWidth:   240

                Text {
                    text:           natDynamicForm.isEditing() ? "Edit Dynamic NAT Pool" : "Add Dynamic NAT Pool"
                    color:          Theme.textPrimary
                    font.pixelSize: Theme.fontSizeLarge
                    font.family:    Theme.fontFamily
                    font.bold:      true
                }

                Text {
                    Layout.fillWidth: true
                    text:             "Create a public IP pool and bind it to an ACL for dynamic NAT."
                    color:            Theme.textSecondary
                    font.pixelSize:   Theme.fontSizeSmall
                    font.family:      Theme.fontFamily
                    wrapMode:         Text.WordWrap
                }

                Rectangle {
                    Layout.fillWidth: true
                    height:           Theme.borderWidth
                    color:            Theme.splitHandleColor
                }

                // Pool Name
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Text {
                        text:           "Pool Name"
                        color:          Theme.textSecondary
                        font.pixelSize: Theme.fontSizeSmall
                        font.family:    Theme.fontFamily
                    }
                    StandardTextField {
                        id:               poolNameField
                        Layout.fillWidth: true
                        placeholderText:  "e.g., NAT_POOL"
                    }
                }

                // Pool Start IP
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Text {
                        text:           "Start IP"
                        color:          Theme.textSecondary
                        font.pixelSize: Theme.fontSizeSmall
                        font.family:    Theme.fontFamily
                    }
                    StandardNetworkField {
                        id:               startIpField
                        inputKind:        "ipv4"
                        Layout.fillWidth: true
                        placeholderText:  "e.g., 203.0.113.1"
                    }
                }

                // Pool End IP
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Text {
                        text:           "End IP"
                        color:          Theme.textSecondary
                        font.pixelSize: Theme.fontSizeSmall
                        font.family:    Theme.fontFamily
                    }
                    StandardNetworkField {
                        id:               endIpField
                        inputKind:        "ipv4"
                        Layout.fillWidth: true
                        placeholderText:  "e.g., 203.0.113.10"
                    }
                }

                // Netmask
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Text {
                        text:           "Netmask"
                        color:          Theme.textSecondary
                        font.pixelSize: Theme.fontSizeSmall
                        font.family:    Theme.fontFamily
                    }
                    StandardNetworkField {
                        id:               netmaskField
                        inputKind:        "subnet"
                        Layout.fillWidth: true
                        placeholderText:  "e.g., 255.255.255.0 or /24"
                    }
                }

                StandardComboBox {
                    id: dynamicAclCombo
                    Layout.fillWidth: true
                    labelText: "ACL Name"
                    model: natDynamicForm.aclNames
                    valueModel: natDynamicForm.aclNames
                    emptyText: "No NAT ACL available"
                    emptyWarningText: "No ACL exists in t05_NAT_ACL_DB for this device. Add and save a NAT ACL first."
                }

                Item { Layout.fillHeight: true }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacing8
                    StandardButton {
                        Layout.fillWidth: true; Layout.preferredHeight: 36; type: "Primary"
                        text: natDynamicForm.isEditing() ? "Apply Edit" : "Add Locally"
                        enabled: dynamicAclCombo.currentIndex >= 0 && poolNameField.text.trim() !== "" && startIpField.text.trim() !== "" && endIpField.text.trim() !== "" && netmaskField.text.trim() !== "" && currentHostIp !== ""
                        onClicked: natDynamicForm.stagePool()
                    }
                    StandardButton { Layout.preferredWidth: 84; text: "Cancel"; visible: natDynamicForm.isEditing(); onClicked: natDynamicForm.clearForm() }
                }
            }

        // ── CỘT PHẢI — Danh sách ──
        SavedListPanel {
            SplitView.fillWidth: true
            SplitView.minimumWidth: 0
            title: "Dynamic NAT Pools"
            count: poolModel.count
            emptyText: "No dynamic NAT pools configured yet.\nAdd a pool using the form on the left."
            headerComponent: Component {
                SavedListHeader {
                    width: parent ? parent.width : 0




                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 68
                        spacing: 0

                        Text {
                            width: 110
                            text: "Pool Name"
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: Theme.fontFamily
                            font.bold: true
                        }
                        Text {
                            width: 120
                            text: "Start IP"
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: Theme.fontFamily
                            font.bold: true
                        }
                        Text {
                            width: 120
                            text: "End IP"
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: Theme.fontFamily
                            font.bold: true
                        }
                        Text {
                            text: "ACL"
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: Theme.fontFamily
                            font.bold: true
                        }
                    }
                }
            }

            ListView {
                anchors.fill: parent
                model: poolModel
                clip: true
                spacing: 2
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                delegate: SavedListRow {
                    required property int index
                    required property var model
                    rowIndex: index

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 8
                        spacing: 0

                        Text {
                            width: 110
                            height: parent.height
                            text: model.pool_name
                            color: Theme.textPrimary
                            font.pixelSize: Theme.fontSizeNormal
                            font.family: Theme.fontFamily
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }
                        Text {
                            width: 120
                            height: parent.height
                            text: model.start_ip
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeNormal
                            font.family: Theme.fontFamily
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }
                        Text {
                            width: 120
                            height: parent.height
                            text: model.end_ip
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeNormal
                            font.family: Theme.fontFamily
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }
                        Text {
                            width: Math.max(0, parent.width - 110 - 120 - 120 - 56)
                            height: parent.height
                            text: model.acl_name !== "" ? model.acl_name : "—"
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeNormal
                            font.family: Theme.fontFamily
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }

                        Item {
                            width: 56
                            height: parent.height
                            Row {
                                anchors.centerIn: parent; spacing: 4
                                IconButton { buttonSize: 24; iconSize: 12; glyph: "E"; tooltip: "Edit"; onClicked: natDynamicForm.editPool(model) }
                                IconButton { buttonSize: 24; iconSize: 11; glyph: "✕"; danger: true; tooltip: "Delete"; onClicked: natDynamicForm.removePool(index, model) }
                            }
                        }
                    }
                }
        }
        }
    }

    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 12
        spacing: Theme.spacing8

        Text {
            Layout.fillWidth: true
            text: "Dynamic NAT pools are saved locally before push."
            color: Theme.textSecondary
            font.pixelSize: Theme.fontSizeSmall
            font.family: Theme.fontFamily
            elide: Text.ElideRight
        }
        StandardButton {
            text: "Reload"
            icon.source: AppAssets.resource("resources/general/database-reload.svg")
            type: "Secondary"
            enabled: currentHostIp !== ""
            onClicked: { natDynamicForm.clearForm(); natDynamicForm.reloadAclNames(); natDynamicForm.reloadPools(); natDynamicForm.notify("Reloaded dynamic NAT pools from database.", "info") }
        }
        StandardButton {
            text: "Cancel Changes"
            type: "Secondary"
            enabled: hasPendingLocalChanges
            onClicked: {
                natDynamicForm.clearForm()
                natDynamicForm.reloadPools()
                natDynamicForm.notify("Discarded local dynamic NAT changes.", "info")
            }
        }
        StandardButton {
            text: "Save"
            icon.source: AppAssets.resource("resources/general/save.svg")
            type: "Primary"
            enabled: hasPendingLocalChanges && currentHostIp !== ""
            onClicked: natDynamicForm.saveChanges()
        }
    }
}
