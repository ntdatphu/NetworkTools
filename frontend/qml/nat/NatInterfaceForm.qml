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

                Rectangle {
                    id:                     addIntfBtn
                    Layout.fillWidth:       true
                    Layout.preferredHeight: 36
                    radius:                 Theme.radiusSmall

                    property bool canAdd: intfNameField.text.trim() !== "" &&
                                          currentHostIp              !== ""

                    enabled: canAdd
                    opacity: canAdd ? 1.0 : 0.5
                    color:   canAdd
                                 ? (addIntfHover.hovered ? Qt.lighter(Theme.accentColor, 1.2) : Theme.accentColor)
                                 : Theme.buttonDisabled

                    Behavior on color   { ColorAnimation { duration: Theme.animationDurationFast } }
                    Behavior on opacity { NumberAnimation { duration: Theme.animationDurationFast } }

                    HoverHandler { id: addIntfHover }

                    Text {
                        anchors.centerIn: parent
                        text:             "Assign Interface"
                        color:            Theme.buttonTextSolid
                        font.pixelSize:   Theme.fontSizeNormal
                        font.family:      Theme.fontFamily
                        font.bold:        true
                    }

                    TapHandler {
                        onTapped: {
                            if (!addIntfBtn.canAdd) return
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
                        text:           "NAT Interfaces"
                        color:          Theme.textPrimary
                        font.pixelSize: Theme.fontSizeLarge
                        font.family:    Theme.fontFamily
                        font.bold:      true
                    }

                    Rectangle {
                        visible:           interfaceModel.count > 0
                        width:             intfCountText.implicitWidth + 12
                        height:            20
                        radius:            10
                        color:             Theme.accentColor
                        Layout.alignment:  Qt.AlignVCenter
                        Layout.leftMargin: 8

                        Text {
                            id:               intfCountText
                            anchors.centerIn: parent
                            text:             interfaceModel.count
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
                            width:          parent.width - 40 - 120
                            text:           "Interface Name"
                            color:          Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family:    Theme.fontFamily
                            font.bold:      true
                        }
                        Text {
                            width:          120
                            text:           "Direction"
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
                        visible:             interfaceModel.count === 0
                        text:                "No NAT interfaces assigned yet.\nAdd an interface using the form on the left."
                        color:               Theme.textDisabled
                        font.pixelSize:      Theme.fontSizeNormal
                        font.family:         Theme.fontFamily
                        horizontalAlignment: Text.AlignHCenter
                        lineHeight:          1.6
                    }

                    ListView {
                        anchors.fill: parent
                        model:        interfaceModel
                        clip:         true
                        spacing:      2
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                        delegate: Rectangle {
                            required property int index
                            required property var model
                            width:  ListView.view.width
                            height: 36
                            radius: Theme.radiusSmall
                            color:  intfRowHover.hovered
                                        ? Theme.sideBarItemHover
                                        : (index % 2 === 0 ? "transparent" : Theme.searchBackground2)

                            Behavior on color { ColorAnimation { duration: Theme.animationDurationFast } }
                            HoverHandler { id: intfRowHover }

                            Row {
                                anchors.fill:        parent
                                anchors.leftMargin:  12
                                anchors.rightMargin: 8
                                spacing:             0

                                Text {
                                    width:             parent.width - 8 - 120 - 32
                                    height:            parent.height
                                    text:              model.interface_name
                                    color:             Theme.textPrimary
                                    font.pixelSize:    Theme.fontSizeNormal
                                    font.family:       Theme.fontFamily
                                    elide:             Text.ElideRight
                                    verticalAlignment: Text.AlignVCenter
                                }

                                // Badge inside/outside
                                Rectangle {
                                    width:            100
                                    height:           parent.height
                                    color:            "transparent"

                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left:           parent.left
                                        width:                  dirText.implicitWidth + 16
                                        height:                 22
                                        radius:                 Theme.radiusSmall
                                        color:                  model.direction === "inside"
                                                                    ? Theme.alertSuccessSubtle
                                                                    : Theme.alertWarningSubtle

                                        Text {
                                            id:               dirText
                                            anchors.centerIn: parent
                                            text:             model.direction
                                            color:            model.direction === "inside"
                                                                  ? Theme.statusConnected
                                                                  : Theme.alertWarning
                                            font.pixelSize:   Theme.fontSizeSmall
                                            font.family:      Theme.fontFamily
                                            font.bold:        true
                                        }
                                    }
                                }

                                Rectangle {
                                    width:  32
                                    height: parent.height
                                    color:  "transparent"

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 24; height: 24
                                        radius: Theme.radiusSmall
                                        color:  intfDelHover.hovered ? Qt.lighter(Theme.alertError, 1.15) : "transparent"
                                        border.color: intfDelHover.hovered ? Theme.alertError : "transparent"
                                        border.width: 1

                                        Behavior on color        { ColorAnimation { duration: Theme.animationDurationFast } }
                                        Behavior on border.color { ColorAnimation { duration: Theme.animationDurationFast } }

                                        HoverHandler { id: intfDelHover }

                                        Text {
                                            anchors.centerIn: parent
                                            text:             "✕"
                                            color:            intfDelHover.hovered ? Theme.alertError : Theme.textSecondary
                                            font.pixelSize:   11
                                            font.family:      Theme.fontFamily
                                            Behavior on color { ColorAnimation { duration: Theme.animationDurationFast } }
                                        }

                                        TapHandler {
                                            onTapped: {
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
        }
    }
}