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
    property int    processIndex: 0
    property bool   showArea: true   // OSPF: true | EIGRP: false
    property bool   showAd: false
    property string processIdLabel: "Process ID"
    property string processIdPlaceholder: "e.g., 1"
    property string activeSection: "Process"
    property bool showSectionTabs: true

    function notify(message, type) {
        if (typeof statusBar !== "undefined")
            statusBar.showMessage(message, type)
    }

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

            // ── Segmented sections ───────────────────────────────────
            RowLayout {
                visible: baseCard.showSectionTabs
                Layout.fillWidth: true
                spacing: Theme.spacing4

                Rectangle {
                    Layout.preferredWidth: Math.max(96, processTabText.implicitWidth + 28)
                    height: 28
                    radius: Theme.radiusRound
                    color: baseCard.activeSection === "Process"
                           ? Theme.sideBarItemSelected
                           : (processTabHover.hovered ? Theme.sideBarItemHover : "transparent")
                    border.color: baseCard.activeSection === "Process" ? Theme.accentColor : Theme.borderColor
                    border.width: Theme.borderWidth

                    Behavior on color { ColorAnimation { duration: Theme.animationDurationFast } }
                    Behavior on border.color { ColorAnimation { duration: Theme.animationDurationFast } }

                    Text {
                        id: processTabText
                        anchors.centerIn: parent
                        text: "Process"
                        color: baseCard.activeSection === "Process" ? Theme.textPrimary : Theme.textSecondary
                        font.pixelSize: Theme.fontSizeSmall
                        font.family: Theme.fontFamily
                        font.bold: baseCard.activeSection === "Process"
                    }

                    HoverHandler {
                        id: processTabHover
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: baseCard.activeSection = "Process"
                    }
                }

                Rectangle {
                    Layout.preferredWidth: Math.max(100, networksTabText.implicitWidth + 28)
                    height: 28
                    radius: Theme.radiusRound
                    color: baseCard.activeSection === "Networks"
                           ? Theme.sideBarItemSelected
                           : (networksTabHover.hovered ? Theme.sideBarItemHover : "transparent")
                    border.color: baseCard.activeSection === "Networks" ? Theme.accentColor : Theme.borderColor
                    border.width: Theme.borderWidth

                    Behavior on color { ColorAnimation { duration: Theme.animationDurationFast } }
                    Behavior on border.color { ColorAnimation { duration: Theme.animationDurationFast } }

                    Text {
                        id: networksTabText
                        anchors.centerIn: parent
                        text: "Networks"
                        color: baseCard.activeSection === "Networks" ? Theme.textPrimary : Theme.textSecondary
                        font.pixelSize: Theme.fontSizeSmall
                        font.family: Theme.fontFamily
                        font.bold: baseCard.activeSection === "Networks"
                    }

                    HoverHandler {
                        id: networksTabHover
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: baseCard.activeSection = "Networks"
                    }
                }

                Item { Layout.fillWidth: true }
            }

            // ── Process ──────────────────────────────────────────────
            ColumnLayout {
                visible: baseCard.activeSection === "Process"
                Layout.fillWidth: true
                spacing: Theme.spacing12

                GridLayout {
                    Layout.fillWidth: true
                    columns: width < 520 ? 1 : 2
                    columnSpacing: Theme.spacing12
                    rowSpacing: Theme.spacing8

                    StandardTextField {
                        id: processIdField
                        Layout.fillWidth: true
                        labelText: baseCard.processIdLabel
                        placeholderText: baseCard.processIdPlaceholder
                    }

                    StandardTextField {
                        id: routerIdField
                        Layout.fillWidth: true
                        labelText: "Router ID"
                        placeholderText: "e.g., 1.1.1.1"
                    }
                }

                // Vùng inject checkbox từ OspfProcessCard / EigrpProcessCard
                ColumnLayout {
                    id: extraControlsContainer
                    Layout.fillWidth: true
                    spacing: Theme.spacing8
                }

                ColumnLayout {
                    visible: baseCard.showAd
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
            }

            // ── Networks ─────────────────────────────────────────────
            ColumnLayout {
                visible: baseCard.activeSection === "Networks"
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

                    StandardButton {
                        text: "+ Add Network"
                        type: "Primary"
                        onClicked: {
                            networkModel.append({ network: "", wildcard: "", area: "" })
                            baseCard.notify("Added a network row to Process " + baseCard.processIndex + ".", "info")
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: networkTableLayout.implicitHeight
                    radius: Theme.radiusSmall
                    color: "transparent"
                    border.color: Theme.borderColor
                    border.width: Theme.borderWidth

                    ColumnLayout {
                        id: networkTableLayout
                        width: parent.width
                        spacing: 0

                        Rectangle {
                            Layout.fillWidth: true
                            height: 34
                            color: "transparent"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Theme.spacing12
                                anchors.rightMargin: Theme.spacing12
                                spacing: Theme.spacing8

                                Text {
                                    Layout.fillWidth: true
                                    text: "NETWORK"
                                    color: Theme.textSecondary
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.family: Theme.fontFamily
                                    font.bold: true
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: "WILDCARD"
                                    color: Theme.textSecondary
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.family: Theme.fontFamily
                                    font.bold: true
                                }

                                Text {
                                    Layout.preferredWidth: 88
                                    visible: baseCard.showArea
                                    text: "AREA"
                                    color: Theme.textSecondary
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.family: Theme.fontFamily
                                    font.bold: true
                                }

                                Text {
                                    Layout.preferredWidth: 34
                                    text: ""
                                }
                            }

                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: Theme.borderWidth
                                color: Theme.borderColor
                            }
                        }

                        Text {
                            visible:             networkModel.count === 0
                            Layout.fillWidth: true
                            text:                "No network rows. Use Add Network to create one."
                            color:               Theme.textDisabled
                            font.pixelSize:      Theme.fontSizeNormal
                            font.family:         Theme.fontFamily
                            horizontalAlignment: Text.AlignHCenter
                            topPadding:          Theme.spacing16
                            bottomPadding:       Theme.spacing16
                        }

                        // ── Network rows ──────────────────────────────
                        Repeater {
                            model: networkModel

                            delegate: Rectangle {
                                id: networkRow
                                width: networkTableLayout.width
                                height: 44
                                color: rowHover.hovered ? Theme.sideBarItemHover : "transparent"

                                required property string network
                                required property string wildcard
                                required property string area
                                required property int index

                                opacity: 0
                                Component.onCompleted: opacity = 1
                                Behavior on opacity {
                                    NumberAnimation { duration: Theme.animationDurationMedium; easing.type: Easing.OutQuad }
                                }

                                HoverHandler { id: rowHover }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.spacing12
                                    anchors.rightMargin: Theme.spacing12
                                    spacing: Theme.spacing8

                                    StandardTextField {
                                        id: netField
                                        Layout.fillWidth: true
                                        placeholderText: "10.0.0.0"
                                        Component.onCompleted: text = networkRow.network

                                        onTextEdited: function(value) {
                                            if (networkRow.network !== value) {
                                                networkModel.setProperty(networkRow.index, "network", value)
                                            }
                                        }

                                        onEditingFinished: {
                                            if (networkRow.network !== text) {
                                                networkModel.setProperty(networkRow.index, "network", text)
                                            }
                                        }
                                    }

                                    StandardTextField {
                                        id: wildcardField
                                        Layout.fillWidth: true
                                        placeholderText: "0.0.0.255"

                                        Component.onCompleted: text = networkRow.wildcard
                                        onTextEdited: function(value) {
                                            if (networkRow.wildcard !== value) {
                                                networkModel.setProperty(networkRow.index, "wildcard", value)
                                            }
                                        }

                                        onEditingFinished: {
                                            if (networkRow.wildcard !== text) {
                                                networkModel.setProperty(networkRow.index, "wildcard", text)
                                            }
                                        }
                                    }

                                    StandardTextField {
                                        id: areaField
                                        Layout.preferredWidth: 88
                                        visible: baseCard.showArea
                                        placeholderText: "0"

                                        Component.onCompleted: text = networkRow.area
                                        onTextEdited: function(value) {
                                            if (networkRow.area !== value) {
                                                networkModel.setProperty(networkRow.index, "area", value)
                                            }
                                        }

                                        onEditingFinished: {
                                            if (networkRow.area !== text) {
                                                networkModel.setProperty(networkRow.index, "area", text)
                                            }
                                        }
                                    }

                                    StandardButton {
                                        type: "Icon"
                                        icon.source: "qrc:/qt/qml/NetworkTools/resources/devicetabs/close.svg"
                                        tooltip: "Remove network"
                                        onClicked: {
                                            networkModel.remove(networkRow.index)
                                            baseCard.notify("Removed a network row from Process " + baseCard.processIndex + ".", "warning")
                                        }
                                    }
                                }

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    height: Theme.borderWidth
                                    color: Theme.borderColor
                                    opacity: 0.6
                                }
                            }
                        }
                    }
                }
            }

            Item { height: 4 }
        }
    }
}
