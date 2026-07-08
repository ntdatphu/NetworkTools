pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

Rectangle {
    id: natDynamicForm
    color: Theme.contentBackground

    property string currentHostIp: ""

    function reloadPools() {
        poolModel.clear()
        if (currentHostIp === "") return
        const rows = dbManager.getNatDynamicPools(currentHostIp)
        for (let i = 0; i < rows.length; i++) {
            poolModel.append(rows[i])
        }
    }

    onCurrentHostIpChanged: reloadPools()
    Component.onCompleted:  reloadPools()

    ListModel { id: poolModel }

    SplitView {
        anchors.fill: parent
        orientation:  Qt.Horizontal

        handle: StandardSplitHandle {}

        // ── CỘT TRÁI — Form nhập ──
        SplitFormPane {
            SplitView.preferredWidth: 320
            SplitView.minimumWidth:   240

                Text {
                    text:           qsTr("Add Dynamic NAT Pool")
                    color:          Theme.textPrimary
                    font.pixelSize: Theme.fontSizeLarge
                    font.family:    Theme.fontFamily
                    font.bold:      true
                }

                Text {
                    Layout.fillWidth: true
                    text:             qsTr("Create a public IP pool and bind it to an ACL for dynamic NAT.")
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
                        text:           qsTr("Pool Name")
                        color:          Theme.textSecondary
                        font.pixelSize: Theme.fontSizeSmall
                        font.family:    Theme.fontFamily
                    }
                    StandardTextField {
                        id:               poolNameField
                        Layout.fillWidth: true
                        placeholderText:  qsTr("e.g., NAT_POOL")
                    }
                }

                // Pool Start IP
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Text {
                        text:           qsTr("Start IP")
                        color:          Theme.textSecondary
                        font.pixelSize: Theme.fontSizeSmall
                        font.family:    Theme.fontFamily
                    }
                    StandardTextField {
                        id:               startIpField
                        Layout.fillWidth: true
                        placeholderText:  qsTr("e.g., 203.0.113.1")
                    }
                }

                // Pool End IP
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Text {
                        text:           qsTr("End IP")
                        color:          Theme.textSecondary
                        font.pixelSize: Theme.fontSizeSmall
                        font.family:    Theme.fontFamily
                    }
                    StandardTextField {
                        id:               endIpField
                        Layout.fillWidth: true
                        placeholderText:  qsTr("e.g., 203.0.113.10")
                    }
                }

                // Netmask
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Text {
                        text:           qsTr("Netmask")
                        color:          Theme.textSecondary
                        font.pixelSize: Theme.fontSizeSmall
                        font.family:    Theme.fontFamily
                    }
                    StandardTextField {
                        id:               netmaskField
                        Layout.fillWidth: true
                        placeholderText:  qsTr("e.g., 255.255.255.0")
                    }
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

                Item { Layout.fillHeight: true }

                StandardButton {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    type: "Primary"
                    text: qsTr("Add Pool")
                    enabled: poolNameField.text.trim() !== "" &&
                             startIpField.text.trim()  !== "" &&
                             endIpField.text.trim()    !== "" &&
                             netmaskField.text.trim()  !== "" &&
                             currentHostIp              !== ""

                    onClicked: {
                        const ok = dbManager.addNatDynamicPool(
                            currentHostIp,
                            poolNameField.text.trim(),
                            startIpField.text.trim(),
                            endIpField.text.trim(),
                            netmaskField.text.trim(),
                            aclNameField.text.trim()
                        )
                        if (ok) {
                            poolNameField.text = ""
                            startIpField.text  = ""
                            endIpField.text    = ""
                            netmaskField.text  = ""
                            aclNameField.text  = ""
                            natDynamicForm.reloadPools()
                        }
                    }
                }
            }

        // ── CỘT PHẢI — Danh sách ──
        SavedListPanel {
            SplitView.fillWidth: true
            SplitView.minimumWidth: 0
            title: qsTr("Dynamic NAT Pools")
            count: poolModel.count
            emptyText: qsTr("No dynamic NAT pools configured yet.\nAdd a pool using the form on the left.")
            headerComponent: Component {
                SavedListHeader {
                    width: parent ? parent.width : 0




                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 40
                        spacing: 0

                        Text {
                            width: 110
                            text: qsTr("Pool Name")
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: Theme.fontFamily
                            font.bold: true
                        }
                        Text {
                            width: 120
                            text: qsTr("Start IP")
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: Theme.fontFamily
                            font.bold: true
                        }
                        Text {
                            width: 120
                            text: qsTr("End IP")
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: Theme.fontFamily
                            font.bold: true
                        }
                        Text {
                            text: qsTr("ACL")
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
                            width: Math.max(0, parent.width - 110 - 120 - 120 - 32)
                            height: parent.height
                            text: model.acl_name !== "" ? model.acl_name : "—"
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
                                    dbManager.deleteNatDynamicPool(model.nat_dynamic_id)
                                    natDynamicForm.reloadPools()
                                }
                            }
                        }
                    }
                }
        }
        }
    }
}
