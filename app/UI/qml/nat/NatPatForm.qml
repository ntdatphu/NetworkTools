pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

Rectangle {
    id: natPatForm
    color: Theme.contentBackground

    property string currentHostIp: ""
    property int nextLocalId: -1
    property var pendingDeletes: []
    property bool hasPendingLocalChanges: false

    function clearForm() {
        patAclField.text = ""
        interfaceField.text = ""
        patPoolField.text = ""
        overloadCheck.checked = true
        sourceTypeCombo.currentIndex = 0
    }

    function notify(message, type) {
        if (typeof statusBar !== "undefined")
            statusBar.showMessage(message, type)
    }

    function reloadRules() {
        patModel.clear()
        pendingDeletes = []
        nextLocalId = -1
        hasPendingLocalChanges = false
        if (currentHostIp === "") return
        const rows = dbManager.getNatPatRules(currentHostIp)
        for (let i = 0; i < rows.length; i++) {
            const row = rows[i]
            row._isNew = false
            patModel.append(row)
        }
    }

    function stageRule() {
        patModel.append({
            nat_pat_id: nextLocalId--, acl_name: patAclField.text.trim(),
            source_type: sourceTypeCombo.currentValue,
            source_value: sourceTypeCombo.currentValue === "Interface" ? interfaceField.text.trim() : patPoolField.text.trim(),
            overload: overloadCheck.checked, _isNew: true
        })
        clearForm()
        hasPendingLocalChanges = true
    }

    function removeRule(index, row) {
        if (!row._isNew) pendingDeletes = pendingDeletes.concat([row.nat_pat_id])
        patModel.remove(index)
        hasPendingLocalChanges = pendingDeletes.length > 0
        for (let i = 0; i < patModel.count && !hasPendingLocalChanges; i++) hasPendingLocalChanges = patModel.get(i)._isNew
    }

    function saveChanges() {
        let ok = true
        for (let i = 0; i < pendingDeletes.length && ok; i++) ok = dbManager.deleteNatPatRule(pendingDeletes[i])
        for (let i = 0; i < patModel.count && ok; i++) {
            const row = patModel.get(i)
            if (row._isNew) ok = dbManager.addNatPatRule(currentHostIp, row.acl_name, row.source_type, row.source_value, row.overload)
        }
        reloadRules()
        notify(ok ? "Saved PAT changes." : "Save PAT changes failed.", ok ? "success" : "error")
    }

    onCurrentHostIpChanged: {
        clearForm()
        reloadRules()
    }
    Component.onCompleted:  reloadRules()

    ListModel { id: patModel }

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
                    text:           "Add PAT Rule"
                    color:          Theme.textPrimary
                    font.pixelSize: Theme.fontSizeLarge
                    font.family:    Theme.fontFamily
                    font.bold:      true
                }

                Text {
                    Layout.fillWidth: true
                    text:             "PAT (Overload): many inside IPs share one public IP, separated by ports."
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
                        id:               patAclField
                        Layout.fillWidth: true
                        placeholderText:  "e.g., NAT_ACL or 1"
                    }
                }

                // Loại source: Interface hay Pool
                StandardComboBox {
                    id:               sourceTypeCombo
                    Layout.fillWidth: true
                    labelText:        "Source Type"
                    model:            ["Interface", "Pool"]
                    valueModel:       ["Interface", "Pool"]
                }

                // Interface name
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    visible: sourceTypeCombo.currentValue === "Interface"
                    Text {
                        text:           "Interface"
                        color:          Theme.textSecondary
                        font.pixelSize: Theme.fontSizeSmall
                        font.family:    Theme.fontFamily
                    }
                    StandardTextField {
                        id:               interfaceField
                        Layout.fillWidth: true
                        placeholderText:  "e.g., GigabitEthernet0/1"
                    }
                }

                // Pool name (khi dùng pool)
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    visible: sourceTypeCombo.currentValue === "Pool"
                    Text {
                        text:           "Pool Name"
                        color:          Theme.textSecondary
                        font.pixelSize: Theme.fontSizeSmall
                        font.family:    Theme.fontFamily
                    }
                    StandardTextField {
                        id:               patPoolField
                        Layout.fillWidth: true
                        placeholderText:  "e.g., NAT_POOL"
                    }
                }

                // Overload checkbox
                StandardCheckBox {
                    id:   overloadCheck
                    text: "Overload (PAT)"
                    checked: true
                }

                Item { Layout.fillHeight: true }

                StandardButton {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    type: "Primary"
                    text: "Add Locally"
                    enabled: patAclField.text.trim() !== "" &&
                             currentHostIp            !== "" &&
                             (sourceTypeCombo.currentValue === "Interface"
                                  ? interfaceField.text.trim() !== ""
                                  : patPoolField.text.trim()   !== "")

                    onClicked: natPatForm.stageRule()
                }
            }

        // ── CỘT PHẢI — Danh sách ──
        SavedListPanel {
            SplitView.fillWidth: true
            SplitView.minimumWidth: 0
            title: "PAT Rules"
            count: patModel.count
            emptyText: "No PAT rules configured yet.\nAdd a rule using the form on the left."
            headerComponent: Component {
                SavedListHeader {
                    width: parent ? parent.width : 0




                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 40
                        spacing: 0

                        Text {
                            width: 100
                            text: "ACL"
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: Theme.fontFamily
                            font.bold: true
                        }
                        Text {
                            width: 90
                            text: "Type"
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: Theme.fontFamily
                            font.bold: true
                        }
                        Text {
                            width: 160
                            text: "Interface / Pool"
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: Theme.fontFamily
                            font.bold: true
                        }
                        Text {
                            text: "Overload"
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
                model: patModel
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
                            width: 100
                            height: parent.height
                            text: model.acl_name
                            color: Theme.textPrimary
                            font.pixelSize: Theme.fontSizeNormal
                            font.family: Theme.fontFamily
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }
                        Text {
                            width: 90
                            height: parent.height
                            text: model.source_type
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeNormal
                            font.family: Theme.fontFamily
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }
                        Text {
                            width: 160
                            height: parent.height
                            text: model.source_value
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeNormal
                            font.family: Theme.fontFamily
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }
                        Text {
                            width: Math.max(0, parent.width - 100 - 90 - 160 - 32)
                            height: parent.height
                            text: model.overload ? "Yes" : "No"
                            color: model.overload ? Theme.statusConnected : Theme.textSecondary
                            font.pixelSize: Theme.fontSizeNormal
                            font.family: Theme.fontFamily
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
                                onClicked: natPatForm.removeRule(index, model)
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
            text: "PAT rules are saved locally before push."
            color: Theme.textSecondary
            font.pixelSize: Theme.fontSizeSmall
            font.family: Theme.fontFamily
            elide: Text.ElideRight
        }
        StandardButton {
            text: "Cancel Changes"
            type: "Secondary"
            enabled: hasPendingLocalChanges
            onClicked: { natPatForm.clearForm(); natPatForm.reloadRules(); natPatForm.notify("Discarded local PAT changes.", "info") }
        }
        StandardButton {
            text: "Save"
            icon.source: AppAssets.resource("resources/general/save.svg")
            type: "Primary"
            enabled: hasPendingLocalChanges && currentHostIp !== ""
            onClicked: natPatForm.saveChanges()
        }
        StandardButton {
            text: "Reload"
            icon.source: AppAssets.resource("resources/general/database-reload.svg")
            type: "Secondary"
            enabled: currentHostIp !== ""
            onClicked: {
                natPatForm.clearForm()
                natPatForm.reloadRules()
                natPatForm.notify("Reloaded PAT rules from database.", "info")
            }
        }
    }
}
