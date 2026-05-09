pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import NetworkTools

Rectangle {
    id: dhcpExcludedForm
    color: Theme.contentBackground

    property string currentHostIp: ""

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

        // ══════════════════════════════════════════════════════════
        // CỘT TRÁI — Form
        // ══════════════════════════════════════════════════════════
        Rectangle {
            color:                    Theme.contentBackground
            SplitView.preferredWidth: 300
            SplitView.minimumWidth:   220

            ColumnLayout {
                anchors.fill:      parent
                anchors.margins:   24
                anchors.topMargin: 16
                spacing:           14

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
                    color:            Theme.borderColor
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

                // Nút Add
                Rectangle {
                    id:                     addExBtn
                    Layout.fillWidth:       true
                    Layout.preferredHeight: 36
                    radius:                 Theme.borderRadius

                    property bool canAdd: startIpField.text.trim() !== "" &&
                                          endIpField.text.trim()   !== "" &&
                                          currentHostIp             !== ""

                    enabled: canAdd
                    opacity: canAdd ? 1.0 : 0.5
                    color:   canAdd
                                 ? (addExHover.hovered
                                        ? Qt.lighter(Theme.accentColor, 1.2)
                                        : Theme.accentColor)
                                 : Theme.buttonDisabled

                    Behavior on color   { ColorAnimation { duration: Theme.animationDurationMedium } }
                    Behavior on opacity { NumberAnimation { duration: Theme.animationDurationMedium } }

                    HoverHandler { id: addExHover }

                    Text {
                        anchors.centerIn: parent
                        text:             "Add Excluded"
                        color:            Theme.buttonTextSolid
                        font.pixelSize:   Theme.fontSizeNormal
                        font.family:      Theme.fontFamily
                        font.bold:        true
                    }

                    TapHandler {
                        onTapped: {
                            if (!addExBtn.canAdd) return
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
                            }
                        }
                    }
                }
            }
        }

        // ══════════════════════════════════════════════════════════
        // CỘT PHẢI — Danh sách
        // ══════════════════════════════════════════════════════════
        Rectangle {
            color:               Theme.contentBackground
            SplitView.fillWidth: true
            SplitView.minimumWidth: 200

            ColumnLayout {
                anchors.fill:      parent
                anchors.margins:   24
                anchors.topMargin: 16
                spacing:           12

                // Tiêu đề + badge
                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text:           "Excluded Addresses"
                        color:          Theme.textPrimary
                        font.pixelSize: Theme.fontSizeLarge
                        font.family:    Theme.fontFamily
                        font.bold:      true
                    }

                    Rectangle {
                        visible:           excludedListModel.count > 0
                        width:             countEx.implicitWidth + 12
                        height:            20
                        radius:            10
                        color:             Theme.alertError
                        Layout.alignment:  Qt.AlignVCenter
                        Layout.leftMargin: 8

                        Text {
                            id:               countEx
                            anchors.centerIn: parent
                            text:             excludedListModel.count
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
                    radius:           Theme.borderRadius

                    Row {
                        anchors.fill:        parent
                        anchors.leftMargin:  12
                        anchors.rightMargin: 40
                        spacing:             0

                        Text {
                            width:          36
                            text:           "#"
                            color:          Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family:    Theme.fontFamily
                            font.bold:      true
                        }
                        Text {
                            width:          parent.width / 2 - 18
                            text:           "Start IP"
                            color:          Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family:    Theme.fontFamily
                            font.bold:      true
                        }
                        Text {
                            text:           "End IP"
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
                        visible:             excludedListModel.count === 0
                        text:                "No excluded addresses configured yet.\nAdd an entry using the form on the left."
                        color:               Theme.textDisabled
                        font.pixelSize:      Theme.fontSizeNormal
                        font.family:         Theme.fontFamily
                        horizontalAlignment: Text.AlignHCenter
                        lineHeight:          1.6
                    }

                    ListView {
                        anchors.fill: parent
                        model:        excludedListModel
                        clip:         true
                        spacing:      2
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                        delegate: Rectangle {
                            required property int index
                            required property var model
                            width:  ListView.view.width
                            height: 36
                            radius: Theme.borderRadius
                            color:  exRowHover.hovered
                                        ? Theme.sideBarItemHover
                                        : (index % 2 === 0 ? "transparent" : Theme.searchBackground2)

                            Behavior on color { ColorAnimation { duration: Theme.animationDurationFast } }

                            HoverHandler { id: exRowHover }

                            Row {
                                anchors.fill:        parent
                                anchors.leftMargin:  12
                                anchors.rightMargin: 8
                                spacing:             0

                                Text {
                                    width:             36
                                    height:            parent.height
                                    // @suppress("unqualified") index is from parent delegate
                                    text:              index + 1
                                    color:             Theme.textDisabled
                                    font.pixelSize:    Theme.fontSizeSmall
                                    font.family:       Theme.fontFamily
                                    verticalAlignment: Text.AlignVCenter
                                }
                                Text {
                                    width:             (parent.width - 36 - 32) / 2
                                    height:            parent.height
                                    // @suppress("unqualified") model is from parent delegate
                                    text:              model.start_ip
                                    color:             Theme.textPrimary
                                    font.pixelSize:    Theme.fontSizeNormal
                                    font.family:       Theme.fontFamily
                                    elide:             Text.ElideRight
                                    verticalAlignment: Text.AlignVCenter
                                }
                                Text {
                                    width:             (parent.width - 36 - 32) / 2
                                    height:            parent.height
                                    // @suppress("unqualified") model is from parent delegate
                                    text:              model.end_ip
                                    color:             Theme.textPrimary
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
                                        radius: Theme.borderRadius
                                        color:  exDelHover.hovered
                                                    ? Qt.lighter(Theme.alertError, 1.15)
                                                    : "transparent"
                                        border.color: exDelHover.hovered ? Theme.alertError : "transparent"
                                        border.width: 1

                                        Behavior on color        { ColorAnimation { duration: Theme.animationDurationFast } }
                                        Behavior on border.color { ColorAnimation { duration: Theme.animationDurationFast } }

                                        HoverHandler { id: exDelHover }

                                        Text {
                                            anchors.centerIn: parent
                                            text:             "✕"
                                            color:            exDelHover.hovered ? Theme.alertError : Theme.textSecondary
                                            font.pixelSize:   11
                                            font.family:      Theme.fontFamily
                                            Behavior on color { ColorAnimation { duration: Theme.animationDurationFast } }
                                        }

                                        TapHandler {
                                            onTapped: {
                                                // @suppress("unqualified") dbManager and model are context/delegate properties
                                                dbManager.deleteExcludedAddress(model.ex_id)
                                                dhcpExcludedForm.reloadExcluded()
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