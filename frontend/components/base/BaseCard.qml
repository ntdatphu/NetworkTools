pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import NetworkTools

// BaseProcessCard — card dùng chung cho OSPF và EIGRP
// Các protocol tùy chỉnh thông qua properties và slots bên dưới
Item {
    id: baseCard

    // ── Properties cơ bản ────────────────────────────────────────────
    property int  processIndex: 0
    property bool showArea:     true   // OSPF: true | EIGRP: false

    // ── Slot để inject UI tùy chỉnh (checkboxes) ─────────────────────
    // Dùng default property để nhúng component con vào vùng checkbox
    default property alias extraControls: extraControlsContainer.data

    signal removeRequested()

    // ── Expose model và fields ra ngoài để subclass đọc nếu cần ──────
    property alias processId: processIdField.text
    property alias routerId:  routerIdField.text
    property alias ad:        adField.text
    property alias networks:  networkModel

    Layout.fillWidth: true
    implicitHeight:   cardInner.implicitHeight + 24

    opacity: 0
    Component.onCompleted: opacity = 1
    Behavior on opacity {
        NumberAnimation { duration: Theme.animationDurationMedium; easing.type: Easing.OutQuad }
    }

    ListModel { id: networkModel }

    Rectangle {
        anchors.fill:  parent
        radius:        Theme.cardRadius
        color:         Theme.searchBackground2
        border.color:  Theme.borderColor
        border.width:  Theme.borderWidth

        ColumnLayout {
            id:              cardInner
            anchors.left:    parent.left
            anchors.right:   parent.right
            anchors.top:     parent.top
            anchors.margins: 12
            spacing:         12

            // ── Header ──────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true

                Text {
                    text:           "Process " + baseCard.processIndex
                    color:          Theme.textPrimary
                    font.pixelSize: Theme.fontSizeNormal
                    font.family:    Theme.fontFamily
                    font.bold:      true
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    width:        24
                    height:       24
                    radius:       Theme.borderRadius
                    color:        cardDeleteHover.hovered
                                      ? Qt.lighter(Theme.alertError, 1.15)
                                      : "transparent"
                    border.color: cardDeleteHover.hovered
                                      ? Theme.alertError
                                      : Theme.borderColor
                    border.width: Theme.borderWidth

                    Behavior on color        { ColorAnimation { duration: Theme.animationDurationMedium } }
                    Behavior on border.color { ColorAnimation { duration: Theme.animationDurationMedium } }

                    Text {
                        anchors.centerIn: parent
                        text:             "✕"
                        color:            cardDeleteHover.hovered
                                              ? Theme.alertError
                                              : Theme.textSecondary
                        font.pixelSize:   Theme.fontSizeSmall
                        font.family:      Theme.fontFamily
                        Behavior on color { ColorAnimation { duration: Theme.animationDurationMedium } }
                    }

                    HoverHandler { id: cardDeleteHover }
                    TapHandler   { onTapped: baseCard.removeRequested() }

                    ToolTip {
                        visible: cardDeleteHover.hovered
                        text:    "Remove this process"
                        delay:   400
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height:           Theme.borderWidth
                color:            Theme.borderColor
                opacity:          0.6
            }

            // ── Hàng 1: Process ID + Router ID ──────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing:          12

                ColumnLayout {
                    Layout.preferredWidth: 120
                    spacing:               4

                    Text {
                        text:           "Process ID"
                        color:          Theme.textSecondary
                        font.pixelSize: Theme.fontSizeSmall
                        font.family:    Theme.fontFamily
                    }

                    StandardTextField {
                        id:               processIdField
                        Layout.fillWidth: true
                        placeholderText:  "e.g., 1"
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing:          4

                    Text {
                        text:           "Router ID"
                        color:          Theme.textSecondary
                        font.pixelSize: Theme.fontSizeSmall
                        font.family:    Theme.fontFamily
                    }

                    StandardTextField {
                        id:               routerIdField
                        Layout.fillWidth: true
                        placeholderText:  "e.g., 1.1.1.1"
                    }
                }
            }

            // ── Hàng 2: AD + Extra Controls (inject từ subclass) ────
            RowLayout {
                Layout.fillWidth: true
                spacing:          12

                ColumnLayout {
                    Layout.preferredWidth: 120
                    spacing:               4

                    Text {
                        text:           "AD"
                        color:          Theme.textSecondary
                        font.pixelSize: Theme.fontSizeSmall
                        font.family:    Theme.fontFamily
                    }

                    StandardTextField {
                        id:               adField
                        Layout.fillWidth: true
                        placeholderText:  "1-255"
                    }
                }

                // Vùng inject checkbox từ OspfProcessCard / EigrpProcessCard
                RowLayout {
                    id:               extraControlsContainer
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignBottom
                    spacing: 16
                }
            }

            // ── Networks ─────────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                spacing:          8

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text:                "NETWORKS"
                        color:               Theme.textSecondary
                        font.pixelSize:      Theme.fontSizeSmall
                        font.family:         Theme.fontFamily
                        font.bold:           true
                        font.capitalization: Font.AllUppercase
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        width:  22
                        height: 22
                        radius: Theme.borderRadius
                        color:  netAddHover.hovered
                                    ? Qt.lighter(Theme.accentColor, 1.2)
                                    : Theme.accentColor

                        Behavior on color { ColorAnimation { duration: Theme.animationDurationMedium } }

                        Text {
                            anchors.centerIn: parent
                            text:             "+"
                            color:            Theme.buttonTextSolid
                            font.pixelSize:   15
                            font.family:      Theme.fontFamily
                            font.bold:        true
                            topPadding:       -1
                        }

                        HoverHandler { id: netAddHover }
                        TapHandler {
                            onTapped: {
                                networkModel.append({ network: "", wildcard: "", area: "" })
                            }
                        }

                        ToolTip {
                            visible: netAddHover.hovered
                            text:    "Add Network"
                            delay:   400
                        }
                    }
                }

                Text {
                    visible:             networkModel.count === 0
                    Layout.fillWidth:    true
                    text:                "Click + to add a network"
                    color:               Theme.textDisabled
                    font.pixelSize:      Theme.fontSizeNormal
                    font.family:         Theme.fontFamily
                    horizontalAlignment: Text.AlignHCenter
                    topPadding:          4
                    bottomPadding:       4
                }

                // ── Network rows ──────────────────────────────────────
                Repeater {
                    model: networkModel

                    delegate: RowLayout {
                        width:   cardInner.width
                        height:  36
                        spacing: 8
                        
                        required property string network
                        required property string wildcard
                        required property string area
                        required property int index

                        opacity: 0
                        Component.onCompleted: opacity = 1
                        Behavior on opacity {
                            NumberAnimation { duration: Theme.animationDurationMedium; easing.type: Easing.OutQuad }
                        }

                        // Network
                        StandardTextField {
                            id:               netField
                            Layout.fillWidth: true
                            placeholderText:  "Network"
                            Component.onCompleted: text = parent.network
                            
                            onEditingFinished: {
                                if (parent.network !== text) {
                                    networkModel.setProperty(index, "network", text)
                                }
                            }
                        }

                        // Wildcard
                        StandardTextField {
                            id:               wildcardField
                            Layout.fillWidth: true
                            placeholderText:  "Wildcard"
                            
                            Component.onCompleted: text = parent.wildcard
                            onEditingFinished: {
                                if (parent.wildcard !== text) {
                                    networkModel.setProperty(index, "wildcard", text)
                                }
                            }
                        }

                        // Area — chỉ hiện với OSPF
                        StandardTextField {
                            id:                    areaField
                            Layout.preferredWidth: 80
                            visible:               baseCard.showArea
                            placeholderText:       "Area"
                            
                            Component.onCompleted: text = parent.area
                            onEditingFinished: {
                                if (parent.area !== text) {
                                    networkModel.setProperty(index, "area", text)
                                }
                            }
                        }

                        // Nút xóa
                        Rectangle {
                            width:        24
                            height:       34
                            radius:       Theme.borderRadius
                            color:        netDeleteHover.hovered
                                              ? Qt.lighter(Theme.alertError, 1.15)
                                              : "transparent"
                            border.color: netDeleteHover.hovered ? Theme.alertError : Theme.borderColor
                            border.width: Theme.borderWidth

                            Behavior on color        { ColorAnimation { duration: Theme.animationDurationMedium } }
                            Behavior on border.color { ColorAnimation { duration: Theme.animationDurationMedium } }

                            Text {
                                anchors.centerIn: parent
                                text:             "✕"
                                color:            netDeleteHover.hovered ? Theme.alertError : Theme.textSecondary
                                font.pixelSize:   Theme.fontSizeSmall
                                font.family:      Theme.fontFamily
                                Behavior on color { ColorAnimation { duration: Theme.animationDurationMedium } }
                            }

                            HoverHandler { id: netDeleteHover }
                            TapHandler   { onTapped: networkModel.remove(index) }
                        }
                    }
                }
            }

            Item { height: 4 }
        }
    }
}