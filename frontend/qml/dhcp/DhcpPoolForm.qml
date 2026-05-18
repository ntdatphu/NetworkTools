pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import NetworkTools

Rectangle {
    id: dhcpPoolForm
    color: Theme.contentBackground

    property string currentHostIp: ""

    function reloadPools() {
        poolListModel.clear()
        if (currentHostIp === "") return
        // @suppress("missing-property") dbManager is context property from C++
        const rows = dbManager.getDhcpPools(currentHostIp)
        for (let i = 0; i < rows.length; i++) {
            poolListModel.append(rows[i])
        }
    }

    onCurrentHostIpChanged: reloadPools()
    Component.onCompleted:  reloadPools()

    ListModel { id: poolListModel }

    SplitView {
        anchors.fill: parent
        orientation:  Qt.Horizontal
        handle: StandardSplitHandle {}

        // ══════════════════════════════════════════════════════════
        // CỘT TRÁI — Form nhập liệu
        // ══════════════════════════════════════════════════════════
        Rectangle {
            color:              Theme.contentSurface
            SplitView.preferredWidth: 300
            SplitView.minimumWidth:   220

            ColumnLayout {
                anchors.fill:        parent
                anchors.margins:     24
                anchors.topMargin:   16
                spacing:             14

                Text {
                    text:           "Add DHCP Pool"
                    color:          Theme.textPrimary
                    font.pixelSize: Theme.fontSizeLarge
                    font.family:    Theme.fontFamily
                    font.bold:      true
                }

                Rectangle {
                    Layout.fillWidth: true
                    height:           Theme.borderWidth
                    color:            Theme.borderColor
                }

                // Pool Name
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text:           "Pool Name"
                        color:          Theme.textSecondary
                        font.pixelSize: Theme.fontSizeSmall
                        font.family:    Theme.fontFamily
                    }
                    StandardTextField {
                        id:               poolField
                        Layout.fillWidth: true
                        placeholderText:  "e.g., POOL_VLAN10"
                    }
                }

                // Network
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text:           "Network"
                        color:          Theme.textSecondary
                        font.pixelSize: Theme.fontSizeSmall
                        font.family:    Theme.fontFamily
                    }
                    StandardTextField {
                        id: networkField
                        Layout.fillWidth: true
                        placeholderText: "e.g., 192.168.10.0"
}
                }

                // Subnet Mask
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text:           "Subnet Mask"
                        color:          Theme.textSecondary
                        font.pixelSize: Theme.fontSizeSmall
                        font.family:    Theme.fontFamily
                    }
                    StandardTextField {
                        id:               subnetField
                        Layout.fillWidth: true
                        placeholderText:  "e.g., 255.255.255.0"
                    }
                }

                // Default Router
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text:           "Default Router"
                        color:          Theme.textSecondary
                        font.pixelSize: Theme.fontSizeSmall
                        font.family:    Theme.fontFamily
                    }
                    StandardTextField {
                        id:               gatewayField
                        Layout.fillWidth: true
                        placeholderText:  "e.g., 192.168.10.1"
                    }
                }

                // DNS
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text:           "DNS Server"
                        color:          Theme.textSecondary
                        font.pixelSize: Theme.fontSizeSmall
                        font.family:    Theme.fontFamily
                    }
                    StandardTextField {
                        id:               dnsField
                        Layout.fillWidth: true
                        placeholderText:  "e.g., 8.8.8.8"
                    }
                }

                Item { Layout.fillHeight: true }

                StandardButton {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    type: "Primary"
                    text: "Add Pool"
                    enabled: poolField.text.trim()    !== "" &&
                             networkField.text.trim() !== "" &&
                             subnetField.text.trim()  !== "" &&
                             currentHostIp             !== ""

                    onClicked: {
                        // @suppress(\"missing-property\") dbManager is context property from C++
                        const ok = dbManager.addDhcpPool(
                            currentHostIp,
                            poolField.text.trim(),
                            networkField.text.trim(),
                            subnetField.text.trim(),
                            gatewayField.text.trim(),
                            dnsField.text.trim()
                        )
                        if (ok) {
                            poolField.text    = ""
                            networkField.text = ""
                            subnetField.text  = ""
                            gatewayField.text = ""
                            dnsField.text     = ""
                            dhcpPoolForm.reloadPools()
                        }
                    }
                }
            }
        }

        // ══════════════════════════════════════════════════════════
        // CỘT PHẢI — Danh sách Pool đã lưu
        // ══════════════════════════════════════════════════════════
        SavedListPanel {
            SplitView.fillWidth:      true
            SplitView.minimumWidth:   0
            SplitView.preferredWidth: dhcpPoolForm.width > 600
                                          ? dhcpPoolForm.width - 300
                                          : 0
            title: "Saved Pools"
            count: poolListModel.count
            countColor: Theme.accentColor
            emptyText: "No DHCP pools configured yet.\nAdd a pool using the form on the left."
            headerComponent: Component {
                Rectangle {
                    width: parent ? parent.width : 0
                    height: 28
                    color: Theme.searchBackground2
                    radius: Theme.borderRadius

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 40
                        spacing: 0

                        Text {
                            width: 100
                            text: "Pool"
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: Theme.fontFamily
                            font.bold: true
                        }
                        Text {
                            width: 120
                            text: "Network"
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: Theme.fontFamily
                            font.bold: true
                        }
                        Text {
                            width: 120
                            text: "Subnet"
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: Theme.fontFamily
                            font.bold: true
                        }
                        Text {
                            text: "Gateway"
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
                            width: 100
                            height: parent.height
                            text: model.pool
                            color: Theme.textPrimary
                            font.pixelSize: Theme.fontSizeNormal
                            font.family: Theme.fontFamily
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }
                        Text {
                            width: 120
                            height: parent.height
                            text: model.network
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeNormal
                            font.family: Theme.fontFamily
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }
                        Text {
                            width: 120
                            height: parent.height
                            text: model.subnetmask
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeNormal
                            font.family: Theme.fontFamily
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }
                        Text {
                            width: Math.max(0, parent.width - 100 - 120 - 120 - 32)
                            height: parent.height
                            text: model.defaut !== "" ? model.defaut : "—"
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
                                onClicked: {
                                    dbManager.deleteDhcpPool(model.dhcp_id)
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
