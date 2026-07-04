pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import NetworkTools

Rectangle {
    id: dhcpPoolForm
    color: Theme.contentBackground

    property string currentHostIp: ""
    property int editingDhcpId: -1

    function isEditing() {
        return editingDhcpId >= 0
    }

    function clearForm() {
        editingDhcpId = -1
        poolField.text = ""
        networkField.text = ""
        subnetField.text = ""
        gatewayField.text = ""
        dnsField.text = ""
        leaseField.text = "1"
    }

    function editPool(row) {
        editingDhcpId = row.dhcp_id
        poolField.text = row.pool || ""
        networkField.text = row.network || ""
        subnetField.text = row.subnetmask || ""
        gatewayField.text = row.defaut || ""
        dnsField.text = row.dns || ""
        leaseField.text = row.lease || "1"
    }

    function reloadPools() {
        poolListModel.clear()
        if (currentHostIp === "") return
        // @suppress("missing-property") dbManager is context property from C++
        const rows = dbManager.getDhcpPools(currentHostIp)
        for (let i = 0; i < rows.length; i++)
            poolListModel.append(rows[i])
    }

    onCurrentHostIpChanged: {
        clearForm()
        reloadPools()
    }
    Component.onCompleted: reloadPools()

    ListModel { id: poolListModel }

    SplitView {
        anchors.fill: parent
        orientation: Qt.Horizontal
        handle: StandardSplitHandle {}

        SplitFormPane {
            SplitView.preferredWidth: 320
            SplitView.minimumWidth: 240

            Text {
                text: dhcpPoolForm.isEditing() ? "Edit DHCP Pool" : "Add DHCP Pool"
                color: Theme.textPrimary
                font.pixelSize: Theme.fontSizeLarge
                font.family: Theme.fontFamily
                font.bold: true
            }

            Rectangle {
                Layout.fillWidth: true
                height: Theme.borderWidth
                color: Theme.splitHandleColor
            }

            StandardTextField {
                id: poolField
                Layout.fillWidth: true
                labelText: "Pool Name"
                placeholderText: "e.g., POOL_VLAN10"
            }

            StandardTextField {
                id: networkField
                Layout.fillWidth: true
                labelText: "Network"
                placeholderText: "e.g., 192.168.10.0"
            }

            StandardTextField {
                id: subnetField
                Layout.fillWidth: true
                labelText: "Subnet Mask"
                placeholderText: "e.g., 255.255.255.0"
            }

            StandardTextField {
                id: gatewayField
                Layout.fillWidth: true
                labelText: "Default Router"
                placeholderText: "e.g., 192.168.10.1"
            }

            StandardTextField {
                id: dnsField
                Layout.fillWidth: true
                labelText: "DNS Server"
                placeholderText: "e.g., 8.8.8.8"
            }

            StandardTextField {
                id: leaseField
                Layout.fillWidth: true
                labelText: "Lease"
                placeholderText: "e.g., 1 or 7 12 0"
                text: "1"
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacing8

                StandardButton {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    type: "Primary"
                    text: dhcpPoolForm.isEditing() ? "Save Pool" : "Add Pool"
                    enabled: poolField.text.trim() !== "" &&
                             networkField.text.trim() !== "" &&
                             subnetField.text.trim() !== "" &&
                             currentHostIp !== ""

                    onClicked: {
                        let ok = false
                        if (dhcpPoolForm.isEditing()) {
                            ok = dbManager.updateDhcpPool(
                                dhcpPoolForm.editingDhcpId,
                                poolField.text.trim(),
                                networkField.text.trim(),
                                subnetField.text.trim(),
                                gatewayField.text.trim(),
                                dnsField.text.trim(),
                                leaseField.text.trim()
                            )
                        } else {
                            ok = dbManager.addDhcpPool(
                                currentHostIp,
                                poolField.text.trim(),
                                networkField.text.trim(),
                                subnetField.text.trim(),
                                gatewayField.text.trim(),
                                dnsField.text.trim(),
                                leaseField.text.trim()
                            )
                        }

                        if (ok) {
                            dhcpPoolForm.clearForm()
                            dhcpPoolForm.reloadPools()
                        }
                    }
                }

                StandardButton {
                    Layout.preferredWidth: 84
                    Layout.preferredHeight: 36
                    text: "Cancel"
                    visible: dhcpPoolForm.isEditing()
                    onClicked: dhcpPoolForm.clearForm()
                }
            }
        }

        SavedListPanel {
            SplitView.fillWidth: true
            SplitView.minimumWidth: 0
            SplitView.preferredWidth: dhcpPoolForm.width > 640 ? dhcpPoolForm.width - 320 : 0
            title: "Saved Pools"
            count: poolListModel.count
            countColor: Theme.accentColor
            emptyText: "No DHCP pools configured yet.\nAdd a pool using the form on the left."
            headerComponent: Component {
                SavedListHeader {
                    width: parent ? parent.width : 0

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 68
                        spacing: 0

                        Text {
                            width: 96
                            text: "Pool"
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: Theme.fontFamily
                            font.bold: true
                        }
                        Text {
                            width: 116
                            text: "Network"
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: Theme.fontFamily
                            font.bold: true
                        }
                        Text {
                            width: 112
                            text: "Subnet"
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: Theme.fontFamily
                            font.bold: true
                        }
                        Text {
                            width: 104
                            text: "Gateway"
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: Theme.fontFamily
                            font.bold: true
                        }
                        Text {
                            text: "Lease"
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
                model: poolListModel
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
                            width: 96
                            height: parent.height
                            text: model.pool
                            color: Theme.textPrimary
                            font.pixelSize: Theme.fontSizeNormal
                            font.family: Theme.fontFamily
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }
                        Text {
                            width: 116
                            height: parent.height
                            text: model.network
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeNormal
                            font.family: Theme.fontFamily
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }
                        Text {
                            width: 112
                            height: parent.height
                            text: model.subnetmask
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeNormal
                            font.family: Theme.fontFamily
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }
                        Text {
                            width: 104
                            height: parent.height
                            text: model.defaut !== "" ? model.defaut : "-"
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeNormal
                            font.family: Theme.fontFamily
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }
                        Text {
                            width: Math.max(0, parent.width - 96 - 116 - 112 - 104 - 56)
                            height: parent.height
                            text: model.lease || "1"
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
                                anchors.centerIn: parent
                                spacing: 4

                                IconButton {
                                    buttonSize: 24
                                    iconSize: 12
                                    glyph: "E"
                                    tooltip: "Edit"
                                    onClicked: dhcpPoolForm.editPool(model)
                                }

                                IconButton {
                                    buttonSize: 24
                                    iconSize: 11
                                    glyph: "X"
                                    danger: true
                                    tooltip: "Delete"
                                    onClicked: {
                                        dbManager.deleteDhcpPool(model.dhcp_id)
                                        if (dhcpPoolForm.editingDhcpId === model.dhcp_id)
                                            dhcpPoolForm.clearForm()
                                        dhcpPoolForm.reloadPools()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
