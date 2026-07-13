pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

Rectangle {
    id: routeMapForm
    color: Theme.contentBackground

    property string currentHostIp: ""
    property int editingEntryId: -1
    property int nextLocalId: -1
    property var pendingDeletes: []
    property var aclNames: []
    property bool hasPendingLocalChanges: false
    signal dataChanged()

    function isEditing() { return editingEntryId !== -1 }

    function indexOfValue(values, value) {
        for (let i = 0; i < values.length; i++)
            if (String(values[i]) === String(value)) return i
        return -1
    }

    function clearForm() {
        editingEntryId = -1
        routeMapNameField.text = ""
        descriptionField.text = ""
        routeMapAclCombo.currentIndex = 0
        sequenceSpin.value = 10
        actionCombo.currentIndex = 0
    }

    function editEntry(row) {
        editingEntryId = row.route_map_entry_id
        routeMapNameField.text = row.route_map_name || ""
        descriptionField.text = row.description || ""
        const aclIndex = indexOfValue(aclNames, row.nat_acl_name)
        routeMapAclCombo.currentIndex = aclIndex >= 0 ? aclIndex + 1 : 0
        sequenceSpin.value = Number(row.sequence || 10)
        actionCombo.currentIndex = row.action === "deny" ? 1 : 0
    }

    function reloadAclNames() {
        aclNames = currentHostIp === "" ? [] : dbManager.getNatAclNames(currentHostIp)
        if (!isEditing()) routeMapAclCombo.currentIndex = 0
    }

    function refreshDirtyFlag() {
        let dirty = pendingDeletes.length > 0
        for (let i = 0; i < routeMapModel.count && !dirty; i++) dirty = routeMapModel.get(i)._isNew || routeMapModel.get(i)._isEdited
        hasPendingLocalChanges = dirty
    }

    function notify(message, type) {
        if (typeof statusBar !== "undefined")
            statusBar.showMessage(message, type)
    }

    function reloadEntries() {
        routeMapModel.clear()
        pendingDeletes = []
        nextLocalId = -1
        hasPendingLocalChanges = false
        if (currentHostIp === "") return
        const rows = dbManager.getNatRouteMapEntries(currentHostIp)
        for (let i = 0; i < rows.length; i++) {
            const row = rows[i]
            row._isNew = false
            row._isEdited = false
            routeMapModel.append(row)
        }
    }

    function stageEntry() {
        const values = { route_map_name: routeMapNameField.text.trim(), description: descriptionField.text.trim(),
            sequence: sequenceSpin.value, action: actionCombo.currentValue, nat_acl_name: routeMapAclCombo.currentValue }
        if (isEditing()) {
            for (let i = 0; i < routeMapModel.count; i++) {
                if (routeMapModel.get(i).route_map_entry_id !== editingEntryId) continue
                for (const key in values) routeMapModel.setProperty(i, key, values[key])
                if (!routeMapModel.get(i)._isNew) routeMapModel.setProperty(i, "_isEdited", true)
                break
            }
        } else routeMapModel.append({ route_map_entry_id: nextLocalId--, route_map_name: values.route_map_name,
            description: values.description, sequence: values.sequence, action: values.action,
            nat_acl_name: values.nat_acl_name, _isNew: true, _isEdited: false })
        clearForm()
        refreshDirtyFlag()
    }

    function removeEntry(index, row) {
        if (!row._isNew) pendingDeletes = pendingDeletes.concat([row.route_map_entry_id])
        routeMapModel.remove(index)
        if (editingEntryId === row.route_map_entry_id) clearForm()
        refreshDirtyFlag()
    }

    function saveChanges() {
        let ok = true
        for (let i = 0; i < pendingDeletes.length && ok; i++) ok = dbManager.deleteNatRouteMapEntry(pendingDeletes[i])
        for (let i = 0; i < routeMapModel.count && ok; i++) {
            const row = routeMapModel.get(i)
            if (row._isEdited) ok = dbManager.deleteNatRouteMapEntry(row.route_map_entry_id)
            if (ok && (row._isNew || row._isEdited)) ok = dbManager.addNatRouteMapEntry(currentHostIp, row.route_map_name, row.description, row.sequence, row.action, row.nat_acl_name)
        }
        reloadEntries()
        reloadAclNames()
        if (ok) dataChanged()
        notify(ok ? "Saved NAT route-map changes." : "Save NAT route-map changes failed.", ok ? "success" : "error")
    }

    onCurrentHostIpChanged: {
        clearForm()
        reloadAclNames()
        reloadEntries()
    }
    Component.onCompleted: { reloadAclNames(); reloadEntries() }

    ListModel { id: routeMapModel }

    SplitView {
        anchors.fill: parent
        anchors.bottomMargin: 60
        orientation: Qt.Horizontal

        handle: StandardSplitHandle {}

        SplitFormPane {
            SplitView.preferredWidth: 320
            SplitView.minimumWidth: 240

            Text {
                text: routeMapForm.isEditing() ? "Edit Route Map Entry" : "Add Route Map Entry"
                color: Theme.textPrimary
                font.pixelSize: Theme.fontSizeLarge
                font.family: Theme.fontFamily
                font.bold: true
            }

            Text {
                Layout.fillWidth: true
                text: "Create route-map sequences and optionally match them to an existing NAT ACL."
                color: Theme.textSecondary
                font.pixelSize: Theme.fontSizeSmall
                font.family: Theme.fontFamily
                wrapMode: Text.WordWrap
            }

            Rectangle {
                Layout.fillWidth: true
                height: Theme.borderWidth
                color: Theme.splitHandleColor
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: "Route Map Name"
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontSizeSmall
                    font.family: Theme.fontFamily
                }

                StandardTextField {
                    id: routeMapNameField
                    Layout.fillWidth: true
                    placeholderText: "e.g., NAT_EXEMPT"
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: "Description"
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontSizeSmall
                    font.family: Theme.fontFamily
                }

                StandardTextField {
                    id: descriptionField
                    Layout.fillWidth: true
                    placeholderText: "Optional"
                }
            }

            StandardSpinBox {
                id: sequenceSpin
                Layout.fillWidth: true
                labelText: "Sequence"
                from: 1
                to: 65535
                value: 10
                stepSize: 10
            }

            StandardComboBox {
                id: actionCombo
                Layout.fillWidth: true
                labelText: "Action"
                model: ["Permit", "Deny"]
                valueModel: ["permit", "deny"]
            }

            StandardComboBox {
                id: routeMapAclCombo
                Layout.fillWidth: true
                labelText: "NAT ACL Name"
                model: ["No ACL"].concat(routeMapForm.aclNames)
                valueModel: [""].concat(routeMapForm.aclNames)
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacing8
                StandardButton {
                    Layout.fillWidth: true; Layout.preferredHeight: 36; type: "Primary"
                    text: routeMapForm.isEditing() ? "Apply Edit" : "Add Locally"
                    enabled: routeMapNameField.text.trim() !== "" && currentHostIp !== ""
                    onClicked: routeMapForm.stageEntry()
                }
                StandardButton { Layout.preferredWidth: 84; text: "Cancel"; visible: routeMapForm.isEditing(); onClicked: routeMapForm.clearForm() }
            }
        }

        SavedListPanel {
            SplitView.fillWidth: true
            SplitView.minimumWidth: 0
            title: "Route Map Entries"
            count: routeMapModel.count
            emptyText: "No route map entries configured yet.\nAdd an entry using the form on the left."

            headerComponent: Component {
                SavedListHeader {
                    width: parent ? parent.width : 0

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 68
                        spacing: 0

                        Text {
                            width: 140
                            text: "Route Map"
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: Theme.fontFamily
                            font.bold: true
                        }
                        Text {
                            width: 80
                            text: "Seq"
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: Theme.fontFamily
                            font.bold: true
                        }
                        Text {
                            width: 90
                            text: "Action"
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: Theme.fontFamily
                            font.bold: true
                        }
                        Text {
                            width: 130
                            text: "NAT ACL"
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: Theme.fontFamily
                            font.bold: true
                        }
                        Text {
                            text: "Description"
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
                model: routeMapModel
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
                            width: 140
                            height: parent.height
                            text: model.route_map_name
                            color: Theme.textPrimary
                            font.pixelSize: Theme.fontSizeNormal
                            font.family: Theme.fontFamily
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }

                        Text {
                            width: 80
                            height: parent.height
                            text: model.sequence
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeNormal
                            font.family: Theme.fontFamily
                            verticalAlignment: Text.AlignVCenter
                        }

                        Rectangle {
                            width: 90
                            height: parent.height
                            color: "transparent"

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                width: actionBadgeText.implicitWidth + 16
                                height: 22
                                radius: Theme.radiusSmall
                                color: model.action === "permit"
                                       ? Theme.alertSuccessSubtle
                                       : Qt.rgba(Theme.alertError.r, Theme.alertError.g, Theme.alertError.b, 0.15)

                                Text {
                                    id: actionBadgeText
                                    anchors.centerIn: parent
                                    text: model.action
                                    color: model.action === "permit"
                                           ? Theme.statusConnected
                                           : Theme.alertError
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.family: Theme.fontFamily
                                    font.bold: true
                                }
                            }
                        }

                        Text {
                            width: 130
                            height: parent.height
                            text: model.nat_acl_name !== "" ? model.nat_acl_name : "-"
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeNormal
                            font.family: Theme.fontFamily
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }

                        Text {
                            width: Math.max(0, parent.width - 140 - 80 - 90 - 130 - 56)
                            height: parent.height
                            text: model.description !== "" ? model.description : "-"
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
                                IconButton { buttonSize: 24; iconSize: 12; glyph: "E"; tooltip: "Edit"; onClicked: routeMapForm.editEntry(model) }
                                IconButton { buttonSize: 24; iconSize: 11; glyph: "x"; danger: true; tooltip: "Delete"; onClicked: routeMapForm.removeEntry(index, model) }
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
            text: "NAT route-map entries are saved locally before push."
            color: Theme.textSecondary
            font.pixelSize: Theme.fontSizeSmall
            font.family: Theme.fontFamily
            elide: Text.ElideRight
        }
        StandardButton {
            text: "Reload"
            type: "Secondary"
            enabled: currentHostIp !== ""
            onClicked: { routeMapForm.clearForm(); routeMapForm.reloadAclNames(); routeMapForm.reloadEntries(); routeMapForm.notify("Reloaded NAT route-map entries from database.", "info") }
        }
        StandardButton {
            text: "Cancel Changes"
            type: "Secondary"
            enabled: hasPendingLocalChanges
            onClicked: { routeMapForm.clearForm(); routeMapForm.reloadEntries(); routeMapForm.notify("Discarded local route-map changes.", "info") }
        }
        StandardButton {
            text: "Save"
            type: "Primary"
            enabled: hasPendingLocalChanges && currentHostIp !== ""
            onClicked: routeMapForm.saveChanges()
        }
    }
}
