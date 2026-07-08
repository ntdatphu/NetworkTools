pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

Rectangle {
    id: natPatForm
    color: Theme.contentBackground

    property string currentHostIp: ""

    function reloadRules() {
        patModel.clear()
        if (currentHostIp === "") return
        const rows = dbManager.getNatPatRules(currentHostIp)
        for (let i = 0; i < rows.length; i++) {
            patModel.append(rows[i])
        }
    }

    onCurrentHostIpChanged: reloadRules()
    Component.onCompleted:  reloadRules()

    ListModel { id: patModel }

    SplitView {
        anchors.fill: parent
        orientation:  Qt.Horizontal

        handle: StandardSplitHandle {}

        // ── CỘT TRÁI — Form nhập ──
        SplitFormPane {
            SplitView.preferredWidth: 320
            SplitView.minimumWidth:   240

                Text {
                    text:           qsTr("Add PAT Rule")
                    color:          Theme.textPrimary
                    font.pixelSize: Theme.fontSizeLarge
                    font.family:    Theme.fontFamily
                    font.bold:      true
                }

                Text {
                    Layout.fillWidth: true
                    text:             qsTr("PAT (Overload): many inside IPs share one public IP, separated by ports.")
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
                        text:           qsTr("ACL Name")
                        color:          Theme.textSecondary
                        font.pixelSize: Theme.fontSizeSmall
                        font.family:    Theme.fontFamily
                    }
                    StandardTextField {
                        id:               patAclField
                        Layout.fillWidth: true
                        placeholderText:  qsTr("e.g., NAT_ACL or 1")
                    }
                }

                // Loại source: Interface hay Pool
                StandardComboBox {
                    id:               sourceTypeCombo
                    Layout.fillWidth: true
                    labelText:        qsTr("Source Type")
                    model:            [qsTr("Interface"), qsTr("Pool")]
                    valueModel:       ["Interface", "Pool"]
                }

                // Interface name
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    visible: sourceTypeCombo.currentValue === "Interface"
                    Text {
                        text:           qsTr("Interface")
                        color:          Theme.textSecondary
                        font.pixelSize: Theme.fontSizeSmall
                        font.family:    Theme.fontFamily
                    }
                    StandardTextField {
                        id:               interfaceField
                        Layout.fillWidth: true
                        placeholderText:  qsTr("e.g., GigabitEthernet0/1")
                    }
                }

                // Pool name (khi dùng pool)
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    visible: sourceTypeCombo.currentValue === "Pool"
                    Text {
                        text:           qsTr("Pool Name")
                        color:          Theme.textSecondary
                        font.pixelSize: Theme.fontSizeSmall
                        font.family:    Theme.fontFamily
                    }
                    StandardTextField {
                        id:               patPoolField
                        Layout.fillWidth: true
                        placeholderText:  qsTr("e.g., NAT_POOL")
                    }
                }

                // Overload checkbox
                StandardCheckBox {
                    id:   overloadCheck
                    text: qsTr("Overload (PAT)")
                    checked: true
                }

                Item { Layout.fillHeight: true }

                StandardButton {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    type: "Primary"
                    text: qsTr("Add PAT Rule")
                    enabled: patAclField.text.trim() !== "" &&
                             currentHostIp            !== "" &&
                             (sourceTypeCombo.currentValue === "Interface"
                                  ? interfaceField.text.trim() !== ""
                                  : patPoolField.text.trim()   !== "")

                    onClicked: {
                        const ok = dbManager.addNatPatRule(
                            currentHostIp,
                            patAclField.text.trim(),
                            sourceTypeCombo.currentValue,
                            sourceTypeCombo.currentValue === "Interface"
                                ? interfaceField.text.trim()
                                : patPoolField.text.trim(),
                            overloadCheck.checked
                        )
                        if (ok) {
                            patAclField.text   = ""
                            interfaceField.text = ""
                            patPoolField.text   = ""
                            overloadCheck.checked = true
                            sourceTypeCombo.currentIndex = 0
                            natPatForm.reloadRules()
                        }
                    }
                }
            }

        // ── CỘT PHẢI — Danh sách ──
        SavedListPanel {
            SplitView.fillWidth: true
            SplitView.minimumWidth: 0
            title: qsTr("PAT Rules")
            count: patModel.count
            emptyText: qsTr("No PAT rules configured yet.\nAdd a rule using the form on the left.")
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
                            text: qsTr("ACL")
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: Theme.fontFamily
                            font.bold: true
                        }
                        Text {
                            width: 90
                            text: qsTr("Type")
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: Theme.fontFamily
                            font.bold: true
                        }
                        Text {
                            width: 160
                            text: qsTr("Interface / Pool")
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: Theme.fontFamily
                            font.bold: true
                        }
                        Text {
                            text: qsTr("Overload")
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
                            text: model.overload ? qsTr("Yes") : qsTr("No")
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
                                tooltip: qsTr("Delete")
                                onClicked: {
                                    dbManager.deleteNatPatRule(model.nat_pat_id)
                                    natPatForm.reloadRules()
                                }
                            }
                        }
                    }
                }
        }
        }
    }
}
