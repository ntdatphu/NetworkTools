pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import NetworkTools

Rectangle {
    id: natStaticForm
    color: Theme.contentBackground

    property string currentHostIp: ""

    function reloadEntries() {
        entryModel.clear()
        if (currentHostIp === "") return
        const rows = dbManager.getNatStaticEntries(currentHostIp)
        for (let i = 0; i < rows.length; i++) {
            entryModel.append(rows[i])
        }
    }

    onCurrentHostIpChanged: reloadEntries()
    Component.onCompleted:  reloadEntries()

    ListModel { id: entryModel }

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
                    text:           "Add Static NAT"
                    color:          Theme.textPrimary
                    font.pixelSize: Theme.fontSizeLarge
                    font.family:    Theme.fontFamily
                    font.bold:      true
                }

                Text {
                    Layout.fillWidth: true
                    text:             "Ánh xạ cố định 1 IP nội bộ ↔ 1 IP public."
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
                }

                // Port fields — chỉ hiện khi Protocol != Any
                RowLayout {
                    Layout.fillWidth: true
                    spacing:          8
                    visible:          protocolCombo.currentText !== "Any"

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

                // Nút Add
                Rectangle {
                    id:                     addBtn
                    Layout.fillWidth:       true
                    Layout.preferredHeight: 36
                    radius:                 Theme.radiusSmall

                    property bool canAdd: insideLocalField.text.trim()  !== "" &&
                                          insideGlobalField.text.trim() !== "" &&
                                          currentHostIp                 !== ""

                    enabled: canAdd
                    opacity: canAdd ? 1.0 : 0.5
                    color:   canAdd
                                 ? (addHover.hovered
                                        ? Qt.lighter(Theme.accentColor, 1.2)
                                        : Theme.accentColor)
                                 : Theme.buttonDisabled

                    Behavior on color   { ColorAnimation { duration: Theme.animationDurationFast } }
                    Behavior on opacity { NumberAnimation { duration: Theme.animationDurationFast } }

                    HoverHandler { id: addHover }

                    Text {
                        anchors.centerIn: parent
                        text:             "Add Entry"
                        color:            Theme.buttonTextSolid
                        font.pixelSize:   Theme.fontSizeNormal
                        font.family:      Theme.fontFamily
                        font.bold:        true
                    }

                    TapHandler {
                        onTapped: {
                            if (!addBtn.canAdd) return
                            const ok = dbManager.addNatStaticEntry(
                                currentHostIp,
                                insideLocalField.text.trim(),
                                insideGlobalField.text.trim(),
                                protocolCombo.currentText === "Any" ? "" : protocolCombo.currentText,
                                localPortField.text.trim(),
                                globalPortField.text.trim()
                            )
                            if (ok) {
                                insideLocalField.text  = ""
                                insideGlobalField.text = ""
                                localPortField.text    = ""
                                globalPortField.text   = ""
                                protocolCombo.currentIndex = 0
                                natStaticForm.reloadEntries()
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

                // Tiêu đề + badge
                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text:           "Static NAT Entries"
                        color:          Theme.textPrimary
                        font.pixelSize: Theme.fontSizeLarge
                        font.family:    Theme.fontFamily
                        font.bold:      true
                    }

                    Rectangle {
                        visible:           entryModel.count > 0
                        width:             countText.implicitWidth + 12
                        height:            20
                        radius:            10
                        color:             Theme.accentColor
                        Layout.alignment:  Qt.AlignVCenter
                        Layout.leftMargin: 8

                        Text {
                            id:               countText
                            anchors.centerIn: parent
                            text:             entryModel.count
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
                            text:           "Inside Local"
                            color:          Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family:    Theme.fontFamily
                            font.bold:      true
                        }
                        Text {
                            width:          140
                            text:           "Inside Global"
                            color:          Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family:    Theme.fontFamily
                            font.bold:      true
                        }
                        Text {
                            text:           "Protocol / Port"
                            color:          Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family:    Theme.fontFamily
                            font.bold:      true
                        }
                    }
                }

                // Danh sách entries
                Item {
                    Layout.fillWidth:  true
                    Layout.fillHeight: true

                    Text {
                        anchors.centerIn:    parent
                        visible:             entryModel.count === 0
                        text:                "No static NAT entries configured yet.\nAdd an entry using the form on the left."
                        color:               Theme.textDisabled
                        font.pixelSize:      Theme.fontSizeNormal
                        font.family:         Theme.fontFamily
                        horizontalAlignment: Text.AlignHCenter
                        lineHeight:          1.6
                    }

                    ListView {
                        anchors.fill: parent
                        model:        entryModel
                        clip:         true
                        spacing:      2
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                        delegate: Rectangle {
                            required property int index
                            required property var model
                            width:  ListView.view.width
                            height: 36
                            radius: Theme.radiusSmall
                            color:  rowHover.hovered
                                        ? Theme.sideBarItemHover
                                        : (index % 2 === 0 ? "transparent" : Theme.searchBackground2)

                            Behavior on color { ColorAnimation { duration: Theme.animationDurationFast } }

                            HoverHandler { id: rowHover }

                            Row {
                                anchors.fill:        parent
                                anchors.leftMargin:  12
                                anchors.rightMargin: 8
                                spacing:             0

                                Text {
                                    width:             140
                                    height:            parent.height
                                    text:              model.inside_local
                                    color:             Theme.textPrimary
                                    font.pixelSize:    Theme.fontSizeNormal
                                    font.family:       Theme.fontFamily
                                    elide:             Text.ElideRight
                                    verticalAlignment: Text.AlignVCenter
                                }
                                Text {
                                    width:             140
                                    height:            parent.height
                                    text:              model.inside_global
                                    color:             Theme.textSecondary
                                    font.pixelSize:    Theme.fontSizeNormal
                                    font.family:       Theme.fontFamily
                                    elide:             Text.ElideRight
                                    verticalAlignment: Text.AlignVCenter
                                }
                                Text {
                                    width:             Math.max(0, parent.width - 140 - 140 - 32)
                                    height:            parent.height
                                    text: {
                                        const proto = model.protocol || ""
                                        const lp    = model.local_port || ""
                                        const gp    = model.global_port || ""
                                        if (proto === "") return "Any"
                                        if (lp !== "" && gp !== "") return proto + "  " + lp + " → " + gp
                                        return proto
                                    }
                                    color:             Theme.textSecondary
                                    font.pixelSize:    Theme.fontSizeNormal
                                    font.family:       Theme.fontFamily
                                    elide:             Text.ElideRight
                                    verticalAlignment: Text.AlignVCenter
                                }

                                // Nút Delete
                                Rectangle {
                                    width:  32
                                    height: parent.height
                                    color:  "transparent"

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 24; height: 24
                                        radius: Theme.radiusSmall
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
                                                dbManager.deleteNatStaticEntry(model.nat_static_id)
                                                natStaticForm.reloadEntries()
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