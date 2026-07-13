pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

Rectangle {
    id: natInterfaceForm
    color: Theme.contentBackground

    property string currentHostIp: ""
    property int editingInterfaceId: -1
    property int nextLocalId: -1
    property var pendingDeletes: []
    property bool hasPendingLocalChanges: false
    signal dataChanged()

    function isEditing() { return editingInterfaceId !== -1 }

    function clearForm() {
        editingInterfaceId = -1
        intfNameField.text = ""
        directionCombo.currentIndex = 0
    }

    function editInterface(row) {
        editingInterfaceId = row.nat_intf_id
        intfNameField.text = row.interface_name || ""
        directionCombo.currentIndex = row.direction === "outside" ? 1 : 0
    }

    function refreshDirtyFlag() {
        let dirty = pendingDeletes.length > 0
        for (let i = 0; i < interfaceModel.count && !dirty; i++) dirty = interfaceModel.get(i)._isNew || interfaceModel.get(i)._isEdited
        hasPendingLocalChanges = dirty
    }

    function notify(message, type) {
        if (typeof statusBar !== "undefined")
            statusBar.showMessage(message, type)
    }

    function reloadInterfaces() {
        interfaceModel.clear()
        pendingDeletes = []
        nextLocalId = -1
        hasPendingLocalChanges = false
        if (currentHostIp === "") return
        const rows = dbManager.getNatInterfaces(currentHostIp)
        for (let i = 0; i < rows.length; i++) {
            const row = rows[i]
            row._isNew = false
            row._isEdited = false
            interfaceModel.append(row)
        }
    }

    function stageInterface() {
        const values = { interface_name: intfNameField.text.trim(), direction: directionCombo.currentValue }
        if (isEditing()) {
            for (let i = 0; i < interfaceModel.count; i++) {
                if (interfaceModel.get(i).nat_intf_id !== editingInterfaceId) continue
                interfaceModel.setProperty(i, "interface_name", values.interface_name)
                interfaceModel.setProperty(i, "direction", values.direction)
                if (!interfaceModel.get(i)._isNew) interfaceModel.setProperty(i, "_isEdited", true)
                break
            }
        } else interfaceModel.append({ nat_intf_id: nextLocalId--, interface_name: values.interface_name, direction: values.direction, _isNew: true, _isEdited: false })
        clearForm()
        refreshDirtyFlag()
    }

    function removeInterface(index, row) {
        if (!row._isNew) pendingDeletes = pendingDeletes.concat([row.nat_intf_id])
        interfaceModel.remove(index)
        if (editingInterfaceId === row.nat_intf_id) clearForm()
        refreshDirtyFlag()
    }

    function saveChanges() {
        let ok = true
        for (let i = 0; i < pendingDeletes.length && ok; i++) ok = dbManager.deleteNatInterface(pendingDeletes[i])
        for (let i = 0; i < interfaceModel.count && ok; i++) {
            const row = interfaceModel.get(i)
            if (row._isEdited) ok = dbManager.deleteNatInterface(row.nat_intf_id)
            if (ok && (row._isNew || row._isEdited)) ok = dbManager.addNatInterface(currentHostIp, row.interface_name, row.direction)
        }
        reloadInterfaces()
        if (ok) dataChanged()
        notify(ok ? "Saved NAT interface changes." : "Save NAT interface changes failed.", ok ? "success" : "error")
    }

    onCurrentHostIpChanged: {
        clearForm()
        reloadInterfaces()
    }
    Component.onCompleted:  reloadInterfaces()

    ListModel { id: interfaceModel }

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
                    text:           natInterfaceForm.isEditing() ? "Edit NAT Interface" : "Assign NAT Interface"
                    color:          Theme.textPrimary
                    font.pixelSize: Theme.fontSizeLarge
                    font.family:    Theme.fontFamily
                    font.bold:      true
                }

                Text {
                    Layout.fillWidth: true
                    text:             "Mark an interface as Inside or Outside for NAT."
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

                // Interface Name
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Text {
                        text:           "Interface Name"
                        color:          Theme.textSecondary
                        font.pixelSize: Theme.fontSizeSmall
                        font.family:    Theme.fontFamily
                    }
                    StandardTextField {
                        id:               intfNameField
                        Layout.fillWidth: true
                        placeholderText:  "e.g., GigabitEthernet0/0"
                    }
                }

                // Direction
                StandardComboBox {
                    id:               directionCombo
                    Layout.fillWidth: true
                    labelText:        "Direction"
                    model:            ["Inside", "Outside"]
                    valueModel:       ["inside", "outside"]
                }

                Item { Layout.fillHeight: true }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacing8
                    StandardButton {
                        Layout.fillWidth: true; Layout.preferredHeight: 36; type: "Primary"
                        text: natInterfaceForm.isEditing() ? "Apply Edit" : "Add Locally"
                        enabled: intfNameField.text.trim() !== "" && currentHostIp !== ""
                        onClicked: natInterfaceForm.stageInterface()
                    }
                    StandardButton { Layout.preferredWidth: 84; text: "Cancel"; visible: natInterfaceForm.isEditing(); onClicked: natInterfaceForm.clearForm() }
                }
            }

        // ── CỘT PHẢI — Danh sách ──
        SavedListPanel {
            SplitView.fillWidth: true
            SplitView.minimumWidth: 0
            title: "NAT Interfaces"
            count: interfaceModel.count
            emptyText: "No NAT interfaces assigned yet.\nAdd an interface using the form on the left."
            headerComponent: Component {
                SavedListHeader {
                    width: parent ? parent.width : 0




                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 68
                        spacing: 0

                        Text {
                            width: parent.width - 40 - 120
                            text: "Interface Name"
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: Theme.fontFamily
                            font.bold: true
                        }
                        Text {
                            width: 120
                            text: "Direction"
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
                model: interfaceModel
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
                            width: parent.width - 8 - 120 - 56
                            height: parent.height
                            text: model.interface_name
                            color: Theme.textPrimary
                            font.pixelSize: Theme.fontSizeNormal
                            font.family: Theme.fontFamily
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }

                        Rectangle {
                            width: 100
                            height: parent.height
                            color: "transparent"

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                width: dirText.implicitWidth + 16
                                height: 22
                                radius: Theme.radiusSmall
                                color: model.direction === "inside"
                                       ? Theme.alertSuccessSubtle
                                       : Theme.alertWarningSubtle

                                Text {
                                    id: dirText
                                    anchors.centerIn: parent
                                    text: model.direction
                                    color: model.direction === "inside"
                                           ? Theme.statusConnected
                                           : Theme.alertWarning
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.family: Theme.fontFamily
                                    font.bold: true
                                }
                            }
                        }

                        Item {
                            width: 56
                            height: parent.height
                            Row {
                                anchors.centerIn: parent; spacing: 4
                                IconButton { buttonSize: 24; iconSize: 12; glyph: "E"; tooltip: "Edit"; onClicked: natInterfaceForm.editInterface(model) }
                                IconButton { buttonSize: 24; iconSize: 11; glyph: "✕"; danger: true; tooltip: "Delete"; onClicked: natInterfaceForm.removeInterface(index, model) }
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
            text: "NAT interface roles are saved locally before push."
            color: Theme.textSecondary
            font.pixelSize: Theme.fontSizeSmall
            font.family: Theme.fontFamily
            elide: Text.ElideRight
        }
        StandardButton {
            text: "Reload"
            type: "Secondary"
            enabled: currentHostIp !== ""
            onClicked: { natInterfaceForm.clearForm(); natInterfaceForm.reloadInterfaces(); natInterfaceForm.notify("Reloaded NAT interfaces from database.", "info") }
        }
        StandardButton {
            text: "Cancel Changes"
            type: "Secondary"
            enabled: hasPendingLocalChanges
            onClicked: { natInterfaceForm.clearForm(); natInterfaceForm.reloadInterfaces(); natInterfaceForm.notify("Discarded local NAT interface changes.", "info") }
        }
        StandardButton {
            text: "Save"
            type: "Primary"
            enabled: hasPendingLocalChanges && currentHostIp !== ""
            onClicked: natInterfaceForm.saveChanges()
        }
    }
}
