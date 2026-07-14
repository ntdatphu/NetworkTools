pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

Rectangle {
    id: routeMapForm
    color: Theme.contentBackground

    property string currentHostIp: ""
    property int nextLocalId: -1
    property var pendingDeletes: []
    property bool hasPendingLocalChanges: false

    function clearForm() {
        routeMapNameField.text = ""
        descriptionField.text = ""
        aclNameField.text = ""
        sequenceSpin.value = 10
        actionCombo.currentIndex = 0
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
            routeMapModel.append(row)
        }
    }

    function stageEntry() {
        routeMapModel.append({ route_map_entry_id: nextLocalId--, route_map_name: routeMapNameField.text.trim(), description: descriptionField.text.trim(), sequence: sequenceSpin.value, action: actionCombo.currentValue, nat_acl_name: aclNameField.text.trim(), _isNew: true })
        clearForm()
        hasPendingLocalChanges = true
    }

    function removeEntry(index, row) {
        if (!row._isNew) pendingDeletes = pendingDeletes.concat([row.route_map_entry_id])
        routeMapModel.remove(index)
        hasPendingLocalChanges = pendingDeletes.length > 0
        for (let i = 0; i < routeMapModel.count && !hasPendingLocalChanges; i++) hasPendingLocalChanges = routeMapModel.get(i)._isNew
    }

    function saveChanges() {
        let ok = true
        for (let i = 0; i < pendingDeletes.length && ok; i++) ok = dbManager.deleteNatRouteMapEntry(pendingDeletes[i])
        for (let i = 0; i < routeMapModel.count && ok; i++) {
            const row = routeMapModel.get(i)
            if (row._isNew) ok = dbManager.addNatRouteMapEntry(currentHostIp, row.route_map_name, row.description, row.sequence, row.action, row.nat_acl_name)
        }
        reloadEntries()
        notify(ok ? "Saved NAT route-map changes." : "Save NAT route-map changes failed.", ok ? "success" : "error")
    }

    onCurrentHostIpChanged: {
        clearForm()
        reloadEntries()
    }
    Component.onCompleted: reloadEntries()

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
                text: "Add Route Map Entry"
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

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: "NAT ACL Name"
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontSizeSmall
                    font.family: Theme.fontFamily
                }

                StandardTextField {
                    id: aclNameField
                    Layout.fillWidth: true
                    placeholderText: "e.g., NAT_ACL"
                }
            }

            Item { Layout.fillHeight: true }

            StandardButton {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                type: "Primary"
                text: "Add Locally"
                enabled: routeMapNameField.text.trim() !== "" &&
                         currentHostIp !== ""

                onClicked: routeMapForm.stageEntry()
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
                        anchors.rightMargin: 40
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
                            width: Math.max(0, parent.width - 140 - 80 - 90 - 130 - 32)
                            height: parent.height
                            text: model.description !== "" ? model.description : "-"
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeNormal
                            font.family: Theme.fontFamily
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }

                        Item {
                            width: 32
                            height: parent.height

                            IconButton {
                                anchors.centerIn: parent
                                buttonSize: 24
                                iconSize: 11
                                glyph: "x"
                                danger: true
                                tooltip: "Delete"
                                onClicked: routeMapForm.removeEntry(index, model)
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
            text: "Cancel Changes"
            type: "Secondary"
            enabled: hasPendingLocalChanges
            onClicked: { routeMapForm.clearForm(); routeMapForm.reloadEntries(); routeMapForm.notify("Discarded local route-map changes.", "info") }
        }
        StandardButton {
            text: "Save"
            icon.source: AppAssets.resource("resources/general/save.svg")
            type: "Primary"
            enabled: hasPendingLocalChanges && currentHostIp !== ""
            onClicked: routeMapForm.saveChanges()
        }
        StandardButton {
            text: "Reload"
            icon.source: AppAssets.resource("resources/general/database-reload.svg")
            type: "Secondary"
            enabled: currentHostIp !== ""
            onClicked: {
                routeMapForm.clearForm()
                routeMapForm.reloadEntries()
                routeMapForm.notify("Reloaded NAT route-map entries from database.", "info")
            }
        }
    }
}
