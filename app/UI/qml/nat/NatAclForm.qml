pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

Rectangle {
    id: natAclForm
    color: Theme.contentBackground

    property string currentHostIp: ""
    property int nextLocalId: -1
    property var pendingDeletes: []
    property bool hasPendingLocalChanges: false
    signal dataChanged()

    function clearForm() {
        aclNameField.text = ""
        sourceNetField.text = ""
        wildcardField.text = ""
        actionCombo.currentIndex = 0
    }

    function notify(message, type) {
        if (typeof statusBar !== "undefined")
            statusBar.showMessage(message, type)
    }

    function reloadAcls() {
        aclModel.clear()
        pendingDeletes = []
        nextLocalId = -1
        hasPendingLocalChanges = false
        if (currentHostIp === "") return
        const rows = dbManager.getNatAcls(currentHostIp)
        for (let i = 0; i < rows.length; i++) {
            const row = rows[i]
            row._isNew = false
            aclModel.append(row)
        }
    }

    function stageAcl() {
        aclModel.append({ rule_id: nextLocalId--, acl_name: aclNameField.text.trim(), action: actionCombo.currentValue, source_network: sourceNetField.text.trim(), wildcard: wildcardField.text.trim(), _isNew: true })
        clearForm()
        hasPendingLocalChanges = true
    }

    function removeAcl(index, row) {
        if (!row._isNew) pendingDeletes = pendingDeletes.concat([row.rule_id])
        aclModel.remove(index)
        hasPendingLocalChanges = pendingDeletes.length > 0
        for (let i = 0; i < aclModel.count && !hasPendingLocalChanges; i++) hasPendingLocalChanges = aclModel.get(i)._isNew
    }

    function saveChanges() {
        let ok = true
        for (let i = 0; i < pendingDeletes.length && ok; i++) ok = dbManager.deleteNatAcl(pendingDeletes[i])
        for (let i = 0; i < aclModel.count && ok; i++) {
            const row = aclModel.get(i)
            if (row._isNew) ok = dbManager.addNatAcl(currentHostIp, row.acl_name, row.action, row.source_network, row.wildcard)
        }
        reloadAcls()
        dataChanged()
        notify(ok ? "Saved NAT ACL changes." : "Save NAT ACL changes failed.", ok ? "success" : "error")
    }

    onCurrentHostIpChanged: {
        clearForm()
        reloadAcls()
    }
    Component.onCompleted:  reloadAcls()

    ListModel { id: aclModel }

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
                    text:           "Add NAT ACL"
                    color:          Theme.textPrimary
                    font.pixelSize: Theme.fontSizeLarge
                    font.family:    Theme.fontFamily
                    font.bold:      true
                }

                Rectangle {
                    Layout.fillWidth: true
                    height:           Theme.borderWidth
                    color:            Theme.splitHandleColor
                }

                // ACL Name
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Text {
                        text:           "ACL Name"
                        color:          Theme.textSecondary
                        font.pixelSize: Theme.fontSizeSmall
                        font.family:    Theme.fontFamily
                    }
                    StandardTextField {
                        id:               aclNameField
                        Layout.fillWidth: true
                        placeholderText:  "e.g., NAT_ACL"
                    }
                }

                // Action
                StandardComboBox {
                    id:               actionCombo
                    Layout.fillWidth: true
                    labelText:        "Action"
                    model:            ["Permit", "Deny"]
                    valueModel:       ["permit", "deny"]
                }

                // Source Network
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Text {
                        text:           "Source Network"
                        color:          Theme.textSecondary
                        font.pixelSize: Theme.fontSizeSmall
                        font.family:    Theme.fontFamily
                    }
                    StandardNetworkField {
                        id:               sourceNetField
                        inputKind:        "ipv4"
                        Layout.fillWidth: true
                        placeholderText:  "e.g., 192.168.1.0"
                    }
                }

                // Wildcard
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Text {
                        text:           "Wildcard Mask"
                        color:          Theme.textSecondary
                        font.pixelSize: Theme.fontSizeSmall
                        font.family:    Theme.fontFamily
                    }
                    StandardNetworkField {
                        id:               wildcardField
                        inputKind:        "wildcard"
                        Layout.fillWidth: true
                        placeholderText:  "e.g., 0.0.0.255 or -/24"
                    }
                }

                Item { Layout.fillHeight: true }

                StandardButton {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    type: "Primary"
                    text: "Add Locally"
                    enabled: aclNameField.text.trim()   !== "" &&
                             sourceNetField.text.trim() !== "" &&
                             wildcardField.text.trim()  !== "" &&
                             currentHostIp               !== ""

                    onClicked: natAclForm.stageAcl()
                }
            }

        // ── CỘT PHẢI — Danh sách ──
        SavedListPanel {
            SplitView.fillWidth: true
            SplitView.minimumWidth: 0
            title: "NAT ACL Entries"
            count: aclModel.count
            emptyText: "No NAT ACL entries configured yet.\nAdd an entry using the form on the left."
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
                            text: "ACL Name"
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: Theme.fontFamily
                            font.bold: true
                        }
                        Text {
                            width: 80
                            text: "Action"
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: Theme.fontFamily
                            font.bold: true
                        }
                        Text {
                            width: 140
                            text: "Network"
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: Theme.fontFamily
                            font.bold: true
                        }
                        Text {
                            text: "Wildcard"
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
                model: aclModel
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
                            text: model.acl_name
                            color: Theme.textPrimary
                            font.pixelSize: Theme.fontSizeNormal
                            font.family: Theme.fontFamily
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }

                        Rectangle {
                            width: 80
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
                            width: 140
                            height: parent.height
                            text: model.source_network
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeNormal
                            font.family: Theme.fontFamily
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }
                        Text {
                            width: Math.max(0, parent.width - 140 - 80 - 140 - 32)
                            height: parent.height
                            text: model.wildcard
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
                                glyph: "✕"
                                danger: true
                                tooltip: "Delete"
                                onClicked: natAclForm.removeAcl(index, model)
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
            text: "NAT ACL entries are saved locally before push."
            color: Theme.textSecondary
            font.pixelSize: Theme.fontSizeSmall
            font.family: Theme.fontFamily
            elide: Text.ElideRight
        }
        StandardButton {
            text: "Cancel Changes"
            type: "Secondary"
            enabled: hasPendingLocalChanges
            onClicked: { natAclForm.clearForm(); natAclForm.reloadAcls(); natAclForm.notify("Discarded local NAT ACL changes.", "info") }
        }
        StandardButton {
            text: "Save"
            type: "Primary"
            enabled: hasPendingLocalChanges && currentHostIp !== ""
            onClicked: natAclForm.saveChanges()
        }
        StandardButton {
            text: "Reload"
            type: "Secondary"
            enabled: currentHostIp !== ""
            onClicked: {
                natAclForm.clearForm()
                natAclForm.reloadAcls()
                natAclForm.notify("Reloaded NAT ACL entries from database.", "info")
            }
        }
    }
}
