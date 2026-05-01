pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import NetworkUI

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
        handle: Rectangle {
            implicitWidth:  6
            implicitHeight: 6
            color: SplitHandle.hovered || SplitHandle.pressed
                       ? Theme.accentColor
                       : Theme.borderColor

            Behavior on color { ColorAnimation { duration: Theme.animationDurationFast } }

            // Indicator 3 chấm giữa handle
            Column {
                anchors.centerIn: parent
                spacing: 3
                Repeater {
                    model: 3
                    Rectangle {
                        width: 2; height: 2; radius: 1
                        color: SplitHandle.hovered || SplitHandle.pressed
                                   ? Theme.buttonTextSolid
                                   : Theme.textDisabled
                    }
                }
            }
        }

        // ══════════════════════════════════════════════════════════
        // CỘT TRÁI — Form nhập liệu
        // ══════════════════════════════════════════════════════════
        Rectangle {
            color:              Theme.contentBackground
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

                // Nút Add Pool
                Rectangle {
                    id:                     addBtn
                    Layout.fillWidth:       true
                    Layout.preferredHeight: 36
                    radius:                 Theme.borderRadius

                    property bool canAdd: poolField.text.trim()    !== "" &&
                                          networkField.text.trim() !== "" &&
                                          subnetField.text.trim()  !== "" &&
                                          currentHostIp             !== ""

                    enabled: canAdd
                    opacity: canAdd ? 1.0 : 0.5
                    color:   canAdd
                                 ? (addHover.hovered
                                        ? Qt.lighter(Theme.accentColor, 1.2)
                                        : Theme.accentColor)
                                 : Theme.buttonDisabled

                    Behavior on color   { ColorAnimation { duration: Theme.animationDurationMedium } }
                    Behavior on opacity { NumberAnimation { duration: Theme.animationDurationMedium } }

                    HoverHandler { id: addHover }

                    Text {
                        anchors.centerIn: parent
                        text:             "Add Pool"
                        color:            Theme.buttonTextSolid
                        font.pixelSize:   Theme.fontSizeNormal
                        font.family:      Theme.fontFamily
                        font.bold:        true
                    }

                    TapHandler {
                        onTapped: {
                            if (!addBtn.canAdd) return
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
        }

        // ══════════════════════════════════════════════════════════
        // CỘT PHẢI — Danh sách Pool đã lưu
        // ══════════════════════════════════════════════════════════
        Rectangle {
            color:                    Theme.contentBackground
            SplitView.fillWidth:      true
            SplitView.minimumWidth:   0
            SplitView.preferredWidth: dhcpPoolForm.width > 600
                                          ? dhcpPoolForm.width - 300
                                          : 0

            ColumnLayout {
                anchors.fill:        parent
                anchors.margins:     24
                anchors.topMargin:   16
                spacing:             12

                // Tiêu đề + badge
                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text:           "Saved Pools"
                        color:          Theme.textPrimary
                        font.pixelSize: Theme.fontSizeLarge
                        font.family:    Theme.fontFamily
                        font.bold:      true
                    }

                    Rectangle {
                        visible:           poolListModel.count > 0
                        width:             countText.implicitWidth + 12
                        height:            20
                        radius:            10
                        color:             Theme.accentColor
                        Layout.alignment:  Qt.AlignVCenter
                        Layout.leftMargin: 8

                        Text {
                            id:               countText
                            anchors.centerIn: parent
                            text:             poolListModel.count
                            color:            Theme.buttonTextSolid
                            font.pixelSize:   Theme.fontSizeSmall
                            font.family:      Theme.fontFamily
                            font.bold:        true
                        }
                    }

                    Item { Layout.fillWidth: true }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height:           Theme.borderWidth
                    color:            Theme.borderColor
                }

                // Header cột — dùng Row thay vì RowLayout để không bị squeeze
                Rectangle {
                    Layout.fillWidth: true
                    height:           28
                    color:            Theme.searchBackground2
                    radius:           Theme.borderRadius

                    Row {
                        anchors.fill:        parent
                        anchors.leftMargin:  12
                        anchors.rightMargin: 40
                        spacing:             0

                        Text {
                            width:          100
                            text:           "Pool"
                            color:          Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family:    Theme.fontFamily
                            font.bold:      true
                        }
                        Text {
                            width:          120
                            text:           "Network"
                            color:          Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family:    Theme.fontFamily
                            font.bold:      true
                        }
                        Text {
                            width:          120
                            text:           "Subnet"
                            color:          Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family:    Theme.fontFamily
                            font.bold:      true
                        }
                        Text {
                            text:           "Gateway"
                            color:          Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family:    Theme.fontFamily
                            font.bold:      true
                        }
                    }
                }

                // Danh sách
                Item {
                    Layout.fillWidth:  true
                    Layout.fillHeight: true

                    Text {
                        anchors.centerIn:    parent
                        visible:             poolListModel.count === 0
                        text:                "No DHCP pools configured yet.\nAdd a pool using the form on the left."
                        color:               Theme.textDisabled
                        font.pixelSize:      Theme.fontSizeNormal
                        font.family:         Theme.fontFamily
                        horizontalAlignment: Text.AlignHCenter
                        lineHeight:          1.6
                    }

                    ListView {
                        anchors.fill: parent
                        model:        poolListModel
                        clip:         true
                        spacing:      2
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                        delegate: Rectangle {
                            required property int index
                            required property var model
                            width:  ListView.view.width
                            height: 36
                            radius: Theme.borderRadius
                            Behavior on color { ColorAnimation { duration: Theme.animationDurationFast } }

                            HoverHandler { id: rowHover }

                            color:  rowHover.hovered
                                        ? Theme.sideBarItemHover
                                        : (index % 2 === 0 ? "transparent" : Theme.searchBackground2)

                            Row {
                                anchors.fill:        parent
                                anchors.leftMargin:  12
                                anchors.rightMargin: 8
                                anchors.topMargin:   0
                                spacing:             0

                                Text {
                                    width:          100
                                    height:         parent.height
                                    // @suppress("unqualified") model is from parent delegate
                                    text:           model.pool
                                    color:          Theme.textPrimary
                                    font.pixelSize: Theme.fontSizeNormal
                                    font.family:    Theme.fontFamily
                                    elide:          Text.ElideRight
                                    verticalAlignment: Text.AlignVCenter
                                }
                                Text {
                                    width:          120
                                    height:         parent.height
                                    // @suppress("unqualified") model is from parent delegate
                                    text:           model.network
                                    color:          Theme.textSecondary
                                    font.pixelSize: Theme.fontSizeNormal
                                    font.family:    Theme.fontFamily
                                    elide:          Text.ElideRight
                                    verticalAlignment: Text.AlignVCenter
                                }
                                Text {
                                    width:          120
                                    height:         parent.height
                                    // @suppress("unqualified") model is from parent delegate
                                    text:           model.subnetmask
                                    color:          Theme.textSecondary
                                    font.pixelSize: Theme.fontSizeNormal
                                    font.family:    Theme.fontFamily
                                    elide:          Text.ElideRight
                                    verticalAlignment: Text.AlignVCenter
                                }
                                Text {
                                    // fillWidth equivalent: takes remaining space minus delete btn
                                    width:          Math.max(0, parent.width - 100 - 120 - 120 - 32)
                                    height:         parent.height
                                    text:           model.defaut !== "" ? model.defaut : "—"
                                    color:          Theme.textSecondary
                                    font.pixelSize: Theme.fontSizeNormal
                                    font.family:    Theme.fontFamily
                                    elide:          Text.ElideRight
                                    verticalAlignment: Text.AlignVCenter
                                }

                                // Nút Delete
                                Rectangle {
                                    width:  24
                                    height: parent.height
                                    color:  "transparent"

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width:  24; height: 24
                                        radius: Theme.borderRadius
                                        color:  delHover.hovered
                                                    ? Qt.lighter(Theme.alertError, 1.15)
                                                    : "transparent"
                                        border.color: delHover.hovered ? Theme.alertError : "transparent"
                                        border.width: 1

                                        Behavior on color        { ColorAnimation { duration: Theme.animationDurationFast } }
                                        Behavior on border.color { ColorAnimation { duration: Theme.animationDurationFast } }

                                        HoverHandler { id: delHover }

                                        Text {
                                            anchors.centerIn: parent
                                            text:             "✕"
                                            color:            delHover.hovered ? Theme.alertError : Theme.textSecondary
                                            font.pixelSize:   11
                                            font.family:      Theme.fontFamily
                                            Behavior on color { ColorAnimation { duration: Theme.animationDurationFast } }
                                        }

                                        TapHandler {
                                            onTapped: {
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
        }
    }
}