pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import NetworkTools

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
                    text:           "Add PAT Rule"
                    color:          Theme.textPrimary
                    font.pixelSize: Theme.fontSizeLarge
                    font.family:    Theme.fontFamily
                    font.bold:      true
                }

                Text {
                    Layout.fillWidth: true
                    text:             "PAT (Overload): Nhiều IP nội bộ dùng chung 1 IP public, phân biệt bằng port."
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
                        placeholderText:  "e.g., NAT_ACL hoặc 1"
                    }
                }

                // Loại source: Interface hay Pool
                StandardComboBox {
                    id:               sourceTypeCombo
                    Layout.fillWidth: true
                    labelText:        "Source Type"
                    model:            ["Interface", "Pool"]
                }

                // Interface name
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    visible: sourceTypeCombo.currentText === "Interface"
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
                    visible: sourceTypeCombo.currentText === "Pool"
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

                Rectangle {
                    id:                     addPatBtn
                    Layout.fillWidth:       true
                    Layout.preferredHeight: 36
                    radius:                 Theme.radiusSmall

                    property bool canAdd: patAclField.text.trim() !== "" &&
                                          currentHostIp            !== "" &&
                                          (sourceTypeCombo.currentText === "Interface"
                                               ? interfaceField.text.trim() !== ""
                                               : patPoolField.text.trim()   !== "")

                    enabled: canAdd
                    opacity: canAdd ? 1.0 : 0.5
                    color:   canAdd
                                 ? (addPatHover.hovered ? Qt.lighter(Theme.accentColor, 1.2) : Theme.accentColor)
                                 : Theme.buttonDisabled

                    Behavior on color   { ColorAnimation { duration: Theme.animationDurationFast } }
                    Behavior on opacity { NumberAnimation { duration: Theme.animationDurationFast } }

                    HoverHandler { id: addPatHover }

                    Text {
                        anchors.centerIn: parent
                        text:             "Add PAT Rule"
                        color:            Theme.buttonTextSolid
                        font.pixelSize:   Theme.fontSizeNormal
                        font.family:      Theme.fontFamily
                        font.bold:        true
                    }

                    TapHandler {
                        onTapped: {
                            if (!addPatBtn.canAdd) return
                            const ok = dbManager.addNatPatRule(
                                currentHostIp,
                                patAclField.text.trim(),
                                sourceTypeCombo.currentText,
                                sourceTypeCombo.currentText === "Interface"
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
                        text:           "PAT Rules"
                        color:          Theme.textPrimary
                        font.pixelSize: Theme.fontSizeLarge
                        font.family:    Theme.fontFamily
                        font.bold:      true
                    }

                    Rectangle {
                        visible:           patModel.count > 0
                        width:             patCountText.implicitWidth + 12
                        height:            20
                        radius:            10
                        color:             Theme.accentColor
                        Layout.alignment:  Qt.AlignVCenter
                        Layout.leftMargin: 8

                        Text {
                            id:               patCountText
                            anchors.centerIn: parent
                            text:             patModel.count
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
                            width:          100
                            text:           "ACL"
                            color:          Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family:    Theme.fontFamily
                            font.bold:      true
                        }
                        Text {
                            width:          90
                            text:           "Type"
                            color:          Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family:    Theme.fontFamily
                            font.bold:      true
                        }
                        Text {
                            width:          160
                            text:           "Interface / Pool"
                            color:          Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family:    Theme.fontFamily
                            font.bold:      true
                        }
                        Text {
                            text:           "Overload"
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
                        visible:             patModel.count === 0
                        text:                "No PAT rules configured yet.\nAdd a rule using the form on the left."
                        color:               Theme.textDisabled
                        font.pixelSize:      Theme.fontSizeNormal
                        font.family:         Theme.fontFamily
                        horizontalAlignment: Text.AlignHCenter
                        lineHeight:          1.6
                    }

                    ListView {
                        anchors.fill: parent
                        model:        patModel
                        clip:         true
                        spacing:      2
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                        delegate: Rectangle {
                            required property int index
                            required property var model
                            width:  ListView.view.width
                            height: 36
                            radius: Theme.radiusSmall
                            color:  patRowHover.hovered
                                        ? Theme.sideBarItemHover
                                        : (index % 2 === 0 ? "transparent" : Theme.searchBackground2)

                            Behavior on color { ColorAnimation { duration: Theme.animationDurationFast } }
                            HoverHandler { id: patRowHover }

                            Row {
                                anchors.fill:        parent
                                anchors.leftMargin:  12
                                anchors.rightMargin: 8
                                spacing:             0

                                Text {
                                    width:             100
                                    height:            parent.height
                                    text:              model.acl_name
                                    color:             Theme.textPrimary
                                    font.pixelSize:    Theme.fontSizeNormal
                                    font.family:       Theme.fontFamily
                                    elide:             Text.ElideRight
                                    verticalAlignment: Text.AlignVCenter
                                }
                                Text {
                                    width:             90
                                    height:            parent.height
                                    text:              model.source_type
                                    color:             Theme.textSecondary
                                    font.pixelSize:    Theme.fontSizeNormal
                                    font.family:       Theme.fontFamily
                                    elide:             Text.ElideRight
                                    verticalAlignment: Text.AlignVCenter
                                }
                                Text {
                                    width:             160
                                    height:            parent.height
                                    text:              model.source_value
                                    color:             Theme.textSecondary
                                    font.pixelSize:    Theme.fontSizeNormal
                                    font.family:       Theme.fontFamily
                                    elide:             Text.ElideRight
                                    verticalAlignment: Text.AlignVCenter
                                }
                                Text {
                                    width:             Math.max(0, parent.width - 100 - 90 - 160 - 32)
                                    height:            parent.height
                                    text:              model.overload ? "Yes" : "No"
                                    color:             model.overload ? Theme.statusConnected : Theme.textSecondary
                                    font.pixelSize:    Theme.fontSizeNormal
                                    font.family:       Theme.fontFamily
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
                                        color:  patDelHover.hovered ? Qt.lighter(Theme.alertError, 1.15) : "transparent"
                                        border.color: patDelHover.hovered ? Theme.alertError : "transparent"
                                        border.width: 1

                                        Behavior on color        { ColorAnimation { duration: Theme.animationDurationFast } }
                                        Behavior on border.color { ColorAnimation { duration: Theme.animationDurationFast } }

                                        HoverHandler { id: patDelHover }

                                        Text {
                                            anchors.centerIn: parent
                                            text:             "✕"
                                            color:            patDelHover.hovered ? Theme.alertError : Theme.textSecondary
                                            font.pixelSize:   11
                                            font.family:      Theme.fontFamily
                                            Behavior on color { ColorAnimation { duration: Theme.animationDurationFast } }
                                        }

                                        TapHandler {
                                            onTapped: {
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
        }
    }
}