pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

Rectangle {
    id: natAclForm
    color: Theme.contentBackground

    property string currentHostIp: ""

    function reloadAcls() {
        aclModel.clear()
        if (currentHostIp === "") return
        const rows = dbManager.getNatAcls(currentHostIp)
        for (let i = 0; i < rows.length; i++) {
            aclModel.append(rows[i])
        }
    }

    onCurrentHostIpChanged: reloadAcls()
    Component.onCompleted:  reloadAcls()

    ListModel { id: aclModel }

    SplitView {
        anchors.fill: parent
        orientation:  Qt.Horizontal

        handle: StandardSplitHandle {}

        // ── CỘT TRÁI — Form nhập ──
        SplitFormPane {
            SplitView.preferredWidth: 320
            SplitView.minimumWidth:   240

                Text {
                    text:           qsTr("Add NAT ACL")
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
                        text:           qsTr("ACL Name")
                        color:          Theme.textSecondary
                        font.pixelSize: Theme.fontSizeSmall
                        font.family:    Theme.fontFamily
                    }
                    StandardTextField {
                        id:               aclNameField
                        Layout.fillWidth: true
                        placeholderText:  qsTr("e.g., NAT_ACL")
                    }
                }

                // Action
                StandardComboBox {
                    id:               actionCombo
                    Layout.fillWidth: true
                    labelText:        qsTr("Action")
                    model:            [qsTr("Permit"), qsTr("Deny")]
                    valueModel:       ["permit", "deny"]
                }

                // Source Network
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Text {
                        text:           qsTr("Source Network")
                        color:          Theme.textSecondary
                        font.pixelSize: Theme.fontSizeSmall
                        font.family:    Theme.fontFamily
                    }
                    StandardTextField {
                        id:               sourceNetField
                        Layout.fillWidth: true
                        placeholderText:  qsTr("e.g., 192.168.1.0")
                    }
                }

                // Wildcard
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Text {
                        text:           qsTr("Wildcard Mask")
                        color:          Theme.textSecondary
                        font.pixelSize: Theme.fontSizeSmall
                        font.family:    Theme.fontFamily
                    }
                    StandardTextField {
                        id:               wildcardField
                        Layout.fillWidth: true
                        placeholderText:  qsTr("e.g., 0.0.0.255")
                    }
                }

                Item { Layout.fillHeight: true }

                StandardButton {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    type: "Primary"
                    text: qsTr("Add ACL Entry")
                    enabled: aclNameField.text.trim()   !== "" &&
                             sourceNetField.text.trim() !== "" &&
                             wildcardField.text.trim()  !== "" &&
                             currentHostIp               !== ""

                    onClicked: {
                        const ok = dbManager.addNatAcl(
                            currentHostIp,
                            aclNameField.text.trim(),
                            actionCombo.currentValue,
                            sourceNetField.text.trim(),
                            wildcardField.text.trim()
                        )
                        if (ok) {
                            aclNameField.text   = ""
                            sourceNetField.text = ""
                            wildcardField.text  = ""
                            actionCombo.currentIndex = 0
                            natAclForm.reloadAcls()
                        }
                    }
                }
            }

        // ── CỘT PHẢI — Danh sách ──
        SavedListPanel {
            SplitView.fillWidth: true
            SplitView.minimumWidth: 0
            title: qsTr("NAT ACL Entries")
            count: aclModel.count
            emptyText: qsTr("No NAT ACL entries configured yet.\nAdd an entry using the form on the left.")
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
                            text: qsTr("ACL Name")
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: Theme.fontFamily
                            font.bold: true
                        }
                        Text {
                            width: 80
                            text: qsTr("Action")
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: Theme.fontFamily
                            font.bold: true
                        }
                        Text {
                            width: 140
                            text: qsTr("Network")
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: Theme.fontFamily
                            font.bold: true
                        }
                        Text {
                            text: qsTr("Wildcard")
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
                                tooltip: qsTr("Delete")
                                onClicked: {
                                    dbManager.deleteNatAcl(model.nat_acl_id)
                                    natAclForm.reloadAcls()
                                }
                            }
                        }
                    }
                }
        }
        }
    }
}
