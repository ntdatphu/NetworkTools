pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

Rectangle {
    id: natStaticForm
    color: Theme.contentBackground

    property string currentHostIp: ""
    property int nextLocalId: -1
    property var pendingDeletes: []
    property bool hasPendingLocalChanges: false
    signal dataChanged()

    function clearForm() {
        insideLocalField.text = ""
        insideGlobalField.text = ""
        localPortField.text = ""
        globalPortField.text = ""
        protocolCombo.currentIndex = 0
    }

    function notify(message, type) {
        if (typeof statusBar !== "undefined")
            statusBar.showMessage(message, type)
    }

    function reloadEntries() {
        entryModel.clear()
        pendingDeletes = []
        nextLocalId = -1
        hasPendingLocalChanges = false
        if (currentHostIp === "") return
        const rows = dbManager.getNatStaticEntries(currentHostIp)
        for (let i = 0; i < rows.length; i++) {
            const row = rows[i]
            row._isNew = false
            entryModel.append(row)
        }
    }

    function stageEntry() {
        entryModel.append({
            nat_static_id: nextLocalId--,
            inside_local: insideLocalField.text.trim(), inside_global: insideGlobalField.text.trim(),
            protocol: protocolCombo.currentValue === "Any" ? "" : protocolCombo.currentValue,
            local_port: localPortField.text.trim(), global_port: globalPortField.text.trim(),
            _isNew: true
        })
        clearForm()
        hasPendingLocalChanges = true
    }

    function removeEntry(index, row) {
        if (!row._isNew) pendingDeletes = pendingDeletes.concat([row.nat_static_id])
        entryModel.remove(index)
        hasPendingLocalChanges = pendingDeletes.length > 0
        for (let i = 0; i < entryModel.count && !hasPendingLocalChanges; i++)
            hasPendingLocalChanges = entryModel.get(i)._isNew
    }

    function saveChanges() {
        let ok = true
        for (let i = 0; i < pendingDeletes.length && ok; i++) ok = dbManager.deleteNatStaticEntry(pendingDeletes[i])
        for (let i = 0; i < entryModel.count && ok; i++) {
            const row = entryModel.get(i)
            if (row._isNew) ok = dbManager.addNatStaticEntry(currentHostIp, row.inside_local, row.inside_global, row.protocol, row.local_port, row.global_port)
        }
        reloadEntries()
        dataChanged()
        notify(ok ? "Saved static NAT changes." : "Save static NAT changes failed.", ok ? "success" : "error")
    }

    onCurrentHostIpChanged: {
        clearForm()
        reloadEntries()
    }
    Component.onCompleted:  reloadEntries()

    ListModel { id: entryModel }

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
                    text:           "Add Static NAT"
                    color:          Theme.textPrimary
                    font.pixelSize: Theme.fontSizeLarge
                    font.family:    Theme.fontFamily
                    font.bold:      true
                }

                Text {
                    Layout.fillWidth: true
                    text:             "Map one inside local IP to one public IP."
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

                // Inside Local IP
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Text {
                        text:           "Inside Local IP"
                        color:          Theme.textSecondary
                        font.pixelSize: Theme.fontSizeSmall
                        font.family:    Theme.fontFamily
                    }
                    StandardTextField {
                        id:               insideLocalField
                        Layout.fillWidth: true
                        placeholderText:  "e.g., 192.168.1.10"
                    }
                }

                // Inside Global IP
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Text {
                        text:           "Inside Global IP"
                        color:          Theme.textSecondary
                        font.pixelSize: Theme.fontSizeSmall
                        font.family:    Theme.fontFamily
                    }
                    StandardTextField {
                        id:               insideGlobalField
                        Layout.fillWidth: true
                        placeholderText:  "e.g., 203.0.113.10"
                    }
                }

                // Protocol (optional)
                StandardComboBox {
                    id:               protocolCombo
                    Layout.fillWidth: true
                    labelText:        "Protocol (optional)"
                    model:            ["Any", "TCP", "UDP"]
                    valueModel:       ["Any", "TCP", "UDP"]
                }

                // Port fields — chỉ hiện khi Protocol != Any
                RowLayout {
                    Layout.fillWidth: true
                    spacing:          8
                    visible:          protocolCombo.currentValue !== "Any"

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Text {
                            text:           "Local Port"
                            color:          Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family:    Theme.fontFamily
                        }
                        StandardTextField {
                            id:               localPortField
                            Layout.fillWidth: true
                            placeholderText:  "e.g., 80"
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Text {
                            text:           "Global Port"
                            color:          Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family:    Theme.fontFamily
                        }
                        StandardTextField {
                            id:               globalPortField
                            Layout.fillWidth: true
                            placeholderText:  "e.g., 8080"
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                StandardButton {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    type: "Primary"
                    text: "Add Locally"
                    enabled: insideLocalField.text.trim()  !== "" &&
                             insideGlobalField.text.trim() !== "" &&
                             currentHostIp                 !== ""

                    onClicked: natStaticForm.stageEntry()
                }
            }

        // ── CỘT PHẢI — Danh sách ──
        SavedListPanel {
            SplitView.fillWidth: true
            SplitView.minimumWidth: 0
            title: "Static NAT Entries"
            count: entryModel.count
            emptyText: "No static NAT entries configured yet.\nAdd an entry using the form on the left."
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
                            text: "Inside Local"
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: Theme.fontFamily
                            font.bold: true
                        }
                        Text {
                            width: 140
                            text: "Inside Global"
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: Theme.fontFamily
                            font.bold: true
                        }
                        Text {
                            text: "Protocol / Port"
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
                model: entryModel
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
                            text: model.inside_local
                            color: Theme.textPrimary
                            font.pixelSize: Theme.fontSizeNormal
                            font.family: Theme.fontFamily
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }
                        Text {
                            width: 140
                            height: parent.height
                            text: model.inside_global
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeNormal
                            font.family: Theme.fontFamily
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }
                        Text {
                            width: Math.max(0, parent.width - 140 - 140 - 32)
                            height: parent.height
                            text: {
                                const proto = model.protocol || ""
                                const lp    = model.local_port || ""
                                const gp    = model.global_port || ""
                                if (proto === "") return "Any"
                                if (lp !== "" && gp !== "") return proto + "  " + lp + " → " + gp
                                return proto
                            }
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
                                onClicked: natStaticForm.removeEntry(index, model)
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
            text: "Static NAT entries are saved locally before push."
            color: Theme.textSecondary
            font.pixelSize: Theme.fontSizeSmall
            font.family: Theme.fontFamily
            elide: Text.ElideRight
        }
        StandardButton {
            text: "Cancel Changes"
            type: "Secondary"
            enabled: hasPendingLocalChanges
            onClicked: {
                natStaticForm.clearForm()
                natStaticForm.reloadEntries()
                natStaticForm.notify("Discarded local static NAT changes.", "info")
            }
        }
        StandardButton {
            text: "Save"
            type: "Primary"
            enabled: hasPendingLocalChanges && currentHostIp !== ""
            onClicked: natStaticForm.saveChanges()
        }
        StandardButton {
            text: "Reload"
            type: "Secondary"
            enabled: currentHostIp !== ""
            onClicked: {
                natStaticForm.clearForm()
                natStaticForm.reloadEntries()
                natStaticForm.notify("Reloaded static NAT entries from database.", "info")
            }
        }
    }
}
