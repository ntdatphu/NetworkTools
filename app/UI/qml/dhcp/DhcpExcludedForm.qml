pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

Rectangle {
    id: dhcpExcludedForm
    color: Theme.contentBackground

    property string currentHostIp: ""

    signal dataChanged()

    function reloadExcluded() {
        excludedListModel.clear()
        if (currentHostIp === "") return
        // @suppress("missing-property") dbManager is context property from C++
        const rows = dbManager.getExcludedAddresses(currentHostIp)
        for (let i = 0; i < rows.length; i++) {
            excludedListModel.append(rows[i])
        }
    }

    onCurrentHostIpChanged: reloadExcluded()
    Component.onCompleted:  reloadExcluded()

    ListModel { id: excludedListModel }

    SplitView {
        anchors.fill: parent
        orientation:  Qt.Horizontal

        handle: StandardSplitHandle {}

        // ══════════════════════════════════════════════════════════
        // CỘT TRÁI — Form
        // ══════════════════════════════════════════════════════════
        SplitFormPane {
            SplitView.preferredWidth: 300
            SplitView.minimumWidth:   220

                Text {
                    text:           "Add Excluded Address"
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

                // Start IP
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
                        placeholderText:  "e.g., 192.168.10.1"
                    }
                }

                // End IP
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
                        placeholderText:  "e.g., 192.168.10.10"
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text:             "Tip: Set Start IP = End IP\nto exclude a single address."
                    color:            Theme.textDisabled
                    font.pixelSize:   Theme.fontSizeSmall
                    font.family:      Theme.fontFamily
                    lineHeight:       1.5
                    wrapMode:         Text.WordWrap
                }

                Item { Layout.fillHeight: true }

                StandardButton {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    type: "Primary"
                    text: "Add Excluded"
                    enabled: startIpField.text.trim() !== "" &&
                             endIpField.text.trim()   !== "" &&
                             currentHostIp             !== ""

                    onClicked: {
                        // @suppress("missing-property") dbManager is context property from C++
                        const ok = dbManager.addExcludedAddress(
                            currentHostIp,
                            startIpField.text.trim(),
                            endIpField.text.trim()
                        )
                        if (ok) {
                            startIpField.text = ""
                            endIpField.text   = ""
                            dhcpExcludedForm.reloadExcluded()
                            dhcpExcludedForm.dataChanged()
                        }
                    }
                }
        }

        // ══════════════════════════════════════════════════════════
        // CỘT PHẢI — Danh sách
        // ══════════════════════════════════════════════════════════
        SavedListPanel {
            SplitView.fillWidth: true
            SplitView.minimumWidth: 200
            title: "Excluded Addresses"
            count: excludedListModel.count
            countColor: Theme.alertError
            emptyText: "No excluded addresses configured yet.\nAdd an entry using the form on the left."
            headerComponent: Component {
                SavedListHeader {
                    width: parent ? parent.width : 0




                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 40
                        spacing: 0

                        Text {
                            width: 36
                            text: "#"
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: Theme.fontFamily
                            font.bold: true
                        }
                        Text {
                            width: parent.width / 2 - 18
                            text: "Start IP"
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: Theme.fontFamily
                            font.bold: true
                        }
                        Text {
                            text: "End IP"
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
                model: excludedListModel
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
                            width: 36
                            height: parent.height
                            text: index + 1
                            color: Theme.textDisabled
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: Theme.fontFamily
                            verticalAlignment: Text.AlignVCenter
                        }
                        Text {
                            width: (parent.width - 36 - 32) / 2
                            height: parent.height
                            text: model.start_ip
                            color: Theme.textPrimary
                            font.pixelSize: Theme.fontSizeNormal
                            font.family: Theme.fontFamily
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }
                        Text {
                            width: (parent.width - 36 - 32) / 2
                            height: parent.height
                            text: model.end_ip
                            color: Theme.textPrimary
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
                                    // @suppress("unqualified") dbManager and model are context/delegate properties
                                    dbManager.deleteExcludedAddress(model.ex_id)
                                    dhcpExcludedForm.reloadExcluded()
                                    dhcpExcludedForm.dataChanged()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
