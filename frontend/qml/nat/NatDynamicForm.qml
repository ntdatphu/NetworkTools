pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import NetworkTools

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

        handle: Rectangle {
            implicitWidth:  6
            implicitHeight: 6
            color: SplitHandle.hovered || SplitHandle.pressed
                       ? Theme.accentColor : Theme.borderColor
            Behavior on color { ColorAnimation { duration: Theme.animationDurationFast } }
            Column {
                anchors.centerIn: parent
                spacing: 3
                Repeater {
                    model: 3
                    Rectangle {
                        width: 2; height: 2; radius: 1
                        color: SplitHandle.hovered || SplitHandle.pressed
                                   ? Theme.buttonTextSolid : Theme.textDisabled
                    }
                }
            }
        }

        // ── CỘT TRÁI — Form nhập ──
        Rectangle {
            color:                    Theme.contentSurface
            SplitView.preferredWidth: 320
            SplitView.minimumWidth:   240

            ColumnLayout {
                anchors.fill:      parent
                anchors.margins:   24
                anchors.topMargin: 16
                spacing:           14

                Text {
                    text:           "Add Dynamic NAT Pool"
                    color:          Theme.textPrimary
                    font.pixelSize: Theme.fontSizeLarge
                    font.family:    Theme.fontFamily
                    font.bold:      true
                }

                Text {
                    Layout.fillWidth: true
                    text:             "Tạo pool IP public và liên kết với ACL để NAT tự động."
                    color:            Theme.textSecondary
                    font.pixelSize:   Theme.fontSizeSmall
                    font.family:      Theme.fontFamily
                    wrapMode:         Text.WordWrap
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
                        id:               poolNameField
                        Layout.fillWidth: true
                        placeholderText:  "e.g., NAT_POOL"
                    }
                }

                // Pool Start IP
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Text {
                        text:           "Start IP"
                        color:          Theme.textSecondary
                        font.pixelSize: Theme.fontSizeSmall
                        font.family:    Theme.fontFamily
                    }
                    StandardTextField {
                        id:               startIpField
                        Layout.fillWidth: true
                        placeholderText:  "e.g., 203.0.113.1"
                    }
                }

                // Pool End IP
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Text {
                        text:           "End IP"
                        color:          Theme.textSecondary
                        font.pixelSize: Theme.fontSizeSmall
                        font.family:    Theme.fontFamily
                    }
                    StandardTextField {
                        id:               endIpField
                        Layout.fillWidth: true
                        placeholderText:  "e.g., 203.0.113.10"
                    }
                }

                // Netmask
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Text {
                        text:           "Netmask"
                        color:          Theme.textSecondary
                        font.pixelSize: Theme.fontSizeSmall
                        font.family:    Theme.fontFamily
                    }
                    StandardTextField {
                        id:               netmaskField
                        Layout.fillWidth: true
                        placeholderText:  "e.g., 255.255.255.0"
                    }
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

                Item { Layout.fillHeight: true }

                Rectangle {
                    id:                     addPoolBtn
                    Layout.fillWidth:       true
                    Layout.preferredHeight: 36
                    radius:                 Theme.radiusSmall

                    property bool canAdd: poolNameField.text.trim() !== "" &&
                                          startIpField.text.trim()  !== "" &&
                                          endIpField.text.trim()    !== "" &&
                                          netmaskField.text.trim()  !== "" &&
                                          currentHostIp              !== ""

                    enabled: canAdd
                    opacity: canAdd ? 1.0 : 0.5
                    color:   canAdd
                                 ? (addPoolHover.hovered ? Qt.lighter(Theme.accentColor, 1.2) : Theme.accentColor)
                                 : Theme.buttonDisabled

                    Behavior on color   { ColorAnimation { duration: Theme.animationDurationFast } }
                    Behavior on opacity { NumberAnimation { duration: Theme.animationDurationFast } }

                    HoverHandler { id: addPoolHover }

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
                            if (!addPoolBtn.canAdd) return
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
            }
        }

        // ── CỘT PHẢI — Danh sách ──
        Rectangle {
            color:               Theme.contentSurface
            SplitView.fillWidth: true
            SplitView.minimumWidth: 0

            ColumnLayout {
                anchors.fill:      parent
                anchors.margins:   24
                anchors.topMargin: 16
                spacing:           12

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text:           "Dynamic NAT Pools"
                        color:          Theme.textPrimary
                        font.pixelSize: Theme.fontSizeLarge
                        font.family:    Theme.fontFamily
                        font.bold:      true
                    }

                    Rectangle {
                        visible:           poolModel.count > 0
                        width:             poolCountText.implicitWidth + 12
                        height:            20
                        radius:            10
                        color:             Theme.accentColor
                        Layout.alignment:  Qt.AlignVCenter
                        Layout.leftMargin: 8

                        Text {
                            id:               poolCountText
                            anchors.centerIn: parent
                            text:             poolModel.count
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

                // Header
                Rectangle {
                    Layout.fillWidth: true
                    height:           28
                    color:            Theme.searchBackground2
                    radius:           Theme.radiusSmall

                    Row {
                        anchors.fill:        parent
                        anchors.leftMargin:  12
                        anchors.rightMargin: 40
                        spacing:             0

                        Text {
                            width:          110
                            text:           "Pool Name"
                            color:          Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family:    Theme.fontFamily
                            font.bold:      true
                        }
                        Text {
                            width:          120
                            text:           "Start IP"
                            color:          Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family:    Theme.fontFamily
                            font.bold:      true
                        }
                        Text {
                            width:          120
                            text:           "End IP"
                            color:          Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family:    Theme.fontFamily
                            font.bold:      true
                        }
                        Text {
                            text:           "ACL"
                            color:          Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family:    Theme.fontFamily
                            font.bold:      true
                        }
                    }
                }

                Item {
                    Layout.fillWidth:  true
                    Layout.fillHeight: true

                    Text {
                        anchors.centerIn:    parent
                        visible:             poolModel.count === 0
                        text:                "No dynamic NAT pools configured yet.\nAdd a pool using the form on the left."
                        color:               Theme.textDisabled
                        font.pixelSize:      Theme.fontSizeNormal
                        font.family:         Theme.fontFamily
                        horizontalAlignment: Text.AlignHCenter
                        lineHeight:          1.6
                    }

                    ListView {
                        anchors.fill: parent
                        model:        poolModel
                        clip:         true
                        spacing:      2
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                        delegate: Rectangle {
                            required property int index
                            required property var model
                            width:  ListView.view.width
                            height: 36
                            radius: Theme.radiusSmall
                            color:  poolRowHover.hovered
                                        ? Theme.sideBarItemHover
                                        : (index % 2 === 0 ? "transparent" : Theme.searchBackground2)

                            Behavior on color { ColorAnimation { duration: Theme.animationDurationFast } }
                            HoverHandler { id: poolRowHover }

                            Row {
                                anchors.fill:        parent
                                anchors.leftMargin:  12
                                anchors.rightMargin: 8
                                spacing:             0

                                Text {
                                    width:             110
                                    height:            parent.height
                                    text:              model.pool_name
                                    color:             Theme.textPrimary
                                    font.pixelSize:    Theme.fontSizeNormal
                                    font.family:       Theme.fontFamily
                                    elide:             Text.ElideRight
                                    verticalAlignment: Text.AlignVCenter
                                }
                                Text {
                                    width:             120
                                    height:            parent.height
                                    text:              model.start_ip
                                    color:             Theme.textSecondary
                                    font.pixelSize:    Theme.fontSizeNormal
                                    font.family:       Theme.fontFamily
                                    elide:             Text.ElideRight
                                    verticalAlignment: Text.AlignVCenter
                                }
                                Text {
                                    width:             120
                                    height:            parent.height
                                    text:              model.end_ip
                                    color:             Theme.textSecondary
                                    font.pixelSize:    Theme.fontSizeNormal
                                    font.family:       Theme.fontFamily
                                    elide:             Text.ElideRight
                                    verticalAlignment: Text.AlignVCenter
                                }
                                Text {
                                    width:             Math.max(0, parent.width - 110 - 120 - 120 - 32)
                                    height:            parent.height
                                    text:              model.acl_name !== "" ? model.acl_name : "—"
                                    color:             Theme.textSecondary
                                    font.pixelSize:    Theme.fontSizeNormal
                                    font.family:       Theme.fontFamily
                                    elide:             Text.ElideRight
                                    verticalAlignment: Text.AlignVCenter
                                }

                                Rectangle {
                                    width:  32
                                    height: parent.height
                                    color:  "transparent"

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 24; height: 24
                                        radius: Theme.radiusSmall
                                        color:  poolDelHover.hovered ? Qt.lighter(Theme.alertError, 1.15) : "transparent"
                                        border.color: poolDelHover.hovered ? Theme.alertError : "transparent"
                                        border.width: 1

                                        Behavior on color        { ColorAnimation { duration: Theme.animationDurationFast } }
                                        Behavior on border.color { ColorAnimation { duration: Theme.animationDurationFast } }

                                        HoverHandler { id: poolDelHover }

                                        Text {
                                            anchors.centerIn: parent
                                            text:             "✕"
                                            color:            poolDelHover.hovered ? Theme.alertError : Theme.textSecondary
                                            font.pixelSize:   11
                                            font.family:      Theme.fontFamily
                                            Behavior on color { ColorAnimation { duration: Theme.animationDurationFast } }
                                        }

                                        TapHandler {
                                            onTapped: {
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
        }
    }
}
