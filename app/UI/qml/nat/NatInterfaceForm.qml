pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

Rectangle {
    id: natInterfaceForm
    color: Theme.contentBackground

    property string currentHostIp: ""
    property int nextLocalId: -1
    property var pendingDeletes: []
    property bool hasPendingLocalChanges: false

    function clearForm() {
        intfNameField.text = ""
        directionCombo.currentIndex = 0
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
            interfaceModel.append(row)
        }
    }

    function stageInterface() {
        interfaceModel.append({ nat_intf_id: nextLocalId--, interface_name: intfNameField.text.trim(), direction: directionCombo.currentValue, _isNew: true })
        clearForm()
        hasPendingLocalChanges = true
    }

    function removeInterface(index, row) {
        if (!row._isNew) pendingDeletes = pendingDeletes.concat([row.nat_intf_id])
        interfaceModel.remove(index)
        hasPendingLocalChanges = pendingDeletes.length > 0
        for (let i = 0; i < interfaceModel.count && !hasPendingLocalChanges; i++) hasPendingLocalChanges = interfaceModel.get(i)._isNew
    }

    function saveChanges() {
        let ok = true
        for (let i = 0; i < pendingDeletes.length && ok; i++) ok = dbManager.deleteNatInterface(pendingDeletes[i])
        for (let i = 0; i < interfaceModel.count && ok; i++) {
            const row = interfaceModel.get(i)
            if (row._isNew) ok = dbManager.addNatInterface(currentHostIp, row.interface_name, row.direction)
        }
        reloadInterfaces()
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
                    text:           "Assign NAT Interface"
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

                StandardButton {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    type: "Primary"
                    text: "Add Locally"
                    enabled: intfNameField.text.trim() !== "" &&
                             currentHostIp              !== ""

                    onClicked: natInterfaceForm.stageInterface()
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
                        anchors.rightMargin: 40
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
                            width: parent.width - 8 - 120 - 32
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
                            width: 32
                            height: parent.height

                            IconButton {
                                anchors.centerIn: parent
                                buttonSize: 24
                                iconSize: 11
                                glyph: "✕"
                                danger: true
                                tooltip: "Delete"
                                onClicked: natInterfaceForm.removeInterface(index, model)
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
        StandardButton {
            text: "Reload"
            type: "Secondary"
            enabled: currentHostIp !== ""
            onClicked: {
                natInterfaceForm.clearForm()
                natInterfaceForm.reloadInterfaces()
                natInterfaceForm.notify("Reloaded NAT interfaces from database.", "info")
            }
        }
    }
}
