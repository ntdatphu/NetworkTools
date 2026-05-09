pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import NetworkTools

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
            color:                    Theme.contentBackground
            SplitView.preferredWidth: 320
            SplitView.minimumWidth:   240

            ColumnLayout {
                anchors.fill:      parent
                anchors.margins:   24
                anchors.topMargin: 16
                spacing:           14

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
                    color:            Theme.borderColor
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
                    model:            ["permit", "deny"]
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
                    StandardTextField {
                        id:               sourceNetField
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
                    StandardTextField {
                        id:               wildcardField
                        Layout.fillWidth: true
                        placeholderText:  "e.g., 0.0.0.255"
                    }
                }

                Item { Layout.fillHeight: true }

                Rectangle {
                    id:                     addAclBtn
                    Layout.fillWidth:       true
                    Layout.preferredHeight: 36
                    radius:                 Theme.radiusSmall

                    property bool canAdd: aclNameField.text.trim()   !== "" &&
                                          sourceNetField.text.trim() !== "" &&
                                          wildcardField.text.trim()  !== "" &&
                                          currentHostIp               !== ""

                    enabled: canAdd
                    opacity: canAdd ? 1.0 : 0.5
                    color:   canAdd
                                 ? (addAclHover.hovered
                                        ? Qt.lighter(Theme.accentColor, 1.2)
                                        : Theme.accentColor)
                                 : Theme.buttonDisabled

                    Behavior on color   { ColorAnimation { duration: Theme.animationDurationFast } }
                    Behavior on opacity { NumberAnimation { duration: Theme.animationDurationFast } }

                    HoverHandler { id: addAclHover }

                    Text {
                        anchors.centerIn: parent
                        text:             "Add ACL Entry"
                        color:            Theme.buttonTextSolid
                        font.pixelSize:   Theme.fontSizeNormal
                        font.family:      Theme.fontFamily
                        font.bold:        true
                    }

                    TapHandler {
                        onTapped: {
                            if (!addAclBtn.canAdd) return
                            const ok = dbManager.addNatAcl(
                                currentHostIp,
                                aclNameField.text.trim(),
                                actionCombo.currentText,
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
            }
        }

        // ── CỘT PHẢI — Danh sách ──
        Rectangle {
            color:               Theme.contentBackground
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
                        text:           "NAT ACL Entries"
                        color:          Theme.textPrimary
                        font.pixelSize: Theme.fontSizeLarge
                        font.family:    Theme.fontFamily
                        font.bold:      true
                    }

                    Rectangle {
                        visible:           aclModel.count > 0
                        width:             aclCountText.implicitWidth + 12
                        height:            20
                        radius:            10
                        color:             Theme.accentColor
                        Layout.alignment:  Qt.AlignVCenter
                        Layout.leftMargin: 8

                        Text {
                            id:               aclCountText
                            anchors.centerIn: parent
                            text:             aclModel.count
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

                // Header cột
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
                            width:          140
                            text:           "ACL Name"
                            color:          Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family:    Theme.fontFamily
                            font.bold:      true
                        }
                        Text {
                            width:          80
                            text:           "Action"
                            color:          Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family:    Theme.fontFamily
                            font.bold:      true
                        }
                        Text {
                            width:          140
                            text:           "Network"
                            color:          Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family:    Theme.fontFamily
                            font.bold:      true
                        }
                        Text {
                            text:           "Wildcard"
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
                        visible:             aclModel.count === 0
                        text:                "No NAT ACL entries configured yet.\nAdd an entry using the form on the left."
                        color:               Theme.textDisabled
                        font.pixelSize:      Theme.fontSizeNormal
                        font.family:         Theme.fontFamily
                        horizontalAlignment: Text.AlignHCenter
                        lineHeight:          1.6
                    }

                    ListView {
                        anchors.fill: parent
                        model:        aclModel
                        clip:         true
                        spacing:      2
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                        delegate: Rectangle {
                            required property int index
                            required property var model
                            width:  ListView.view.width
                            height: 36
                            radius: Theme.radiusSmall
                            color:  aclRowHover.hovered
                                        ? Theme.sideBarItemHover
                                        : (index % 2 === 0 ? "transparent" : Theme.searchBackground2)

                            Behavior on color { ColorAnimation { duration: Theme.animationDurationFast } }
                            HoverHandler { id: aclRowHover }

                            Row {
                                anchors.fill:        parent
                                anchors.leftMargin:  12
                                anchors.rightMargin: 8
                                spacing:             0

                                Text {
                                    width:             140
                                    height:            parent.height
                                    text:              model.acl_name
                                    color:             Theme.textPrimary
                                    font.pixelSize:    Theme.fontSizeNormal
                                    font.family:       Theme.fontFamily
                                    elide:             Text.ElideRight
                                    verticalAlignment: Text.AlignVCenter
                                }

                                // Action badge
                                Rectangle {
                                    width:  80
                                    height: parent.height
                                    color:  "transparent"

                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left:           parent.left
                                        width:                  actionBadgeText.implicitWidth + 16
                                        height:                 22
                                        radius:                 Theme.radiusSmall
                                        color:                  model.action === "permit"
                                                                    ? Theme.alertSuccessSubtle
                                                                    : Qt.rgba(Theme.alertError.r,
                                                                              Theme.alertError.g,
                                                                              Theme.alertError.b, 0.15)

                                        Text {
                                            id:               actionBadgeText
                                            anchors.centerIn: parent
                                            text:             model.action
                                            color:            model.action === "permit"
                                                                  ? Theme.statusConnected
                                                                  : Theme.alertError
                                            font.pixelSize:   Theme.fontSizeSmall
                                            font.family:      Theme.fontFamily
                                            font.bold:        true
                                        }
                                    }
                                }

                                Text {
                                    width:             140
                                    height:            parent.height
                                    text:              model.source_network
                                    color:             Theme.textSecondary
                                    font.pixelSize:    Theme.fontSizeNormal
                                    font.family:       Theme.fontFamily
                                    elide:             Text.ElideRight
                                    verticalAlignment: Text.AlignVCenter
                                }
                                Text {
                                    width:             Math.max(0, parent.width - 140 - 80 - 140 - 32)
                                    height:            parent.height
                                    text:              model.wildcard
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
                                        color:  aclDelHover.hovered
                                                    ? Qt.lighter(Theme.alertError, 1.15)
                                                    : "transparent"
                                        border.color: aclDelHover.hovered ? Theme.alertError : "transparent"
                                        border.width: 1

                                        Behavior on color        { ColorAnimation { duration: Theme.animationDurationFast } }
                                        Behavior on border.color { ColorAnimation { duration: Theme.animationDurationFast } }

                                        HoverHandler { id: aclDelHover }

                                        Text {
                                            anchors.centerIn: parent
                                            text:             "✕"
                                            color:            aclDelHover.hovered
                                                                  ? Theme.alertError
                                                                  : Theme.textSecondary
                                            font.pixelSize:   11
                                            font.family:      Theme.fontFamily
                                            Behavior on color { ColorAnimation { duration: Theme.animationDurationFast } }
                                        }

                                        TapHandler {
                                            onTapped: {
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
        }
    }
}