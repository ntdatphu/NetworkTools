pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import NetworkTools

Rectangle {
    id: natInterfaceForm
    color: Theme.contentBackground

    property string currentHostIp: ""

    function reloadInterfaces() {
        interfaceModel.clear()
        if (currentHostIp === "") return
        const rows = dbManager.getNatInterfaces(currentHostIp)
        for (let i = 0; i < rows.length; i++) {
            interfaceModel.append(rows[i])
        }
    }

    onCurrentHostIpChanged: reloadInterfaces()
    Component.onCompleted:  reloadInterfaces()

    ListModel { id: interfaceModel }

    SplitView {
        anchors.fill: parent
        orientation:  Qt.Horizontal

        handle: StandardSplitHandle {}

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
                    text:           "Assign NAT Interface"
                    color:          Theme.textPrimary
                    font.pixelSize: Theme.fontSizeLarge
                    font.family:    Theme.fontFamily
                    font.bold:      true
                }

                Text {
                    Layout.fillWidth: true
                    text:             "Đánh dấu interface là Inside (mạng nội bộ) hoặc Outside (phía internet)."
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

                // Interface Name
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Text {
                        text:           "Interface Name"
                        color:          Theme.textSecondary
                        font.pixelSize: Theme.fontSizeSmall
                        font.family:    Theme.fontFamily
                    }
                    StandardTextField {
                        id:               intfNameField
                        Layout.fillWidth: true
                        placeholderText:  "e.g., GigabitEthernet0/0"
                    }
                }

                // Direction
                StandardComboBox {
                    id:               directionCombo
                    Layout.fillWidth: true
                    labelText:        "Direction"
                    model:            ["inside", "outside"]
                }

                Item { Layout.fillHeight: true }

                StandardButton {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    type: "Primary"
                    text: "Assign Interface"
                    enabled: intfNameField.text.trim() !== "" &&
                             currentHostIp              !== ""

                    onClicked: {
                        const ok = dbManager.addNatInterface(
                            currentHostIp,
                            intfNameField.text.trim(),
                            directionCombo.currentText
                        )
                        if (ok) {
                            intfNameField.text = ""
                            directionCombo.currentIndex = 0
                            natInterfaceForm.reloadInterfaces()
                        }
                    }
                }
            }
        }

        // ── CỘT PHẢI — Danh sách ──
        SavedListPanel {
            SplitView.fillWidth: true
            SplitView.minimumWidth: 0
            title: "NAT Interfaces"
            count: interfaceModel.count
            emptyText: "No NAT interfaces assigned yet.\nAdd an interface using the form on the left."
            headerComponent: Component {
                Rectangle {
                    width: parent ? parent.width : 0
                    height: 28
                    color: Theme.searchBackground2
                    radius: Theme.radiusSmall

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 40
                        spacing: 0

                        Text {
                            width: parent.width - 40 - 120
                            text: "Interface Name"
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: Theme.fontFamily
                            font.bold: true
                        }
                        Text {
                            width: 120
                            text: "Direction"
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
                model: interfaceModel
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
                            width: parent.width - 8 - 120 - 32
                            height: parent.height
                            text: model.interface_name
                            color: Theme.textPrimary
                            font.pixelSize: Theme.fontSizeNormal
                            font.family: Theme.fontFamily
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }

                        Rectangle {
                            width: 100
                            height: parent.height
                            color: "transparent"

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                width: dirText.implicitWidth + 16
                                height: 22
                                radius: Theme.radiusSmall
                                color: model.direction === "inside"
                                       ? Theme.alertSuccessSubtle
                                       : Theme.alertWarningSubtle

                                Text {
                                    id: dirText
                                    anchors.centerIn: parent
                                    text: model.direction
                                    color: model.direction === "inside"
                                           ? Theme.statusConnected
                                           : Theme.alertWarning
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.family: Theme.fontFamily
                                    font.bold: true
                                }
                            }
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
                                    dbManager.deleteNatInterface(model.nat_intf_id)
                                    natInterfaceForm.reloadInterfaces()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
