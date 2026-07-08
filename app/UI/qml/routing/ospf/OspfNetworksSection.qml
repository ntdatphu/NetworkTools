pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

Item {
    id: root

    required property var form

    visible: String(form.currentHostIp || "").trim() !== ""
        && form.activeRoutingSection === "Networks"
        && form.processCount > 0
    Layout.fillWidth: true
    implicitHeight: content.implicitHeight

    ColumnLayout {
        id: content
        width: parent.width
        spacing: Theme.spacing12

        Rectangle {
            Layout.fillWidth: true
            Layout.leftMargin: 24
            Layout.rightMargin: 24
            implicitHeight: ospfNetworksLayout.implicitHeight + Theme.spacing32
            radius: Theme.cardRadius
            color: Theme.contentPanelSurface
            border.color: Theme.contentPanelBorder
            border.width: Theme.borderWidth

            ColumnLayout {
                id: ospfNetworksLayout
                anchors.fill: parent
                anchors.margins: Theme.spacing16
                spacing: Theme.spacing12

                SectionTitle {
                    text: qsTr("OSPF NETWORKS")
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: width < 760 ? 2 : 4
                    columnSpacing: Theme.spacing12
                    rowSpacing: Theme.spacing8

                    RoutingProcessComboBox { form: root.form; protocol: "OSPF" }

                    StandardTextField {
                        id: ospfNetworkField
                        Layout.fillWidth: true
                        labelText: qsTr("Network")
                        placeholderText: "10.0.0.0"
                        enabled: root.form.processCount > 0
                    }

                    StandardTextField {
                        id: ospfWildcardField
                        Layout.fillWidth: true
                        labelText: qsTr("Wildcard")
                        placeholderText: "0.0.0.255"
                        enabled: root.form.processCount > 0
                    }

                    StandardTextField {
                        id: ospfAreaField
                        Layout.fillWidth: true
                        labelText: qsTr("Area")
                        placeholderText: "0"
                        enabled: root.form.processCount > 0
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacing8

                    StandardButton {
                        text: qsTr("+ Add Network")
                        type: "Primary"
                        enabled: root.form.processCount > 0
                        onClicked: {
                            if (root.form.addNetworkToSelectedProcess(ospfNetworkField.text, ospfWildcardField.text, ospfAreaField.text)) {
                                ospfNetworkField.clear()
                                ospfWildcardField.clear()
                                ospfAreaField.clear()
                            }
                        }
                    }

                    StandardButton {
                        text: qsTr("Clear")
                        type: "Secondary"
                        onClicked: {
                            ospfNetworkField.clear()
                            ospfWildcardField.clear()
                            ospfAreaField.clear()
                        }
                    }

                    Item { Layout.fillWidth: true }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.leftMargin: 24
            Layout.rightMargin: 24
            implicitHeight: ospfNetworkTableLayout.implicitHeight
            radius: Theme.cardRadius
            color: Theme.contentPanelSurface
            border.color: Theme.contentPanelBorder
            border.width: Theme.borderWidth

            ColumnLayout {
                id: ospfNetworkTableLayout
                width: parent.width
                spacing: 0
                readonly property real tableInnerWidth: Math.max(0, width - Theme.spacing16 * 2)
                readonly property real fixedColumnWidth: 96 + 34 + Theme.spacing8 * 4
                readonly property real flexibleColumnWidth: Math.max(0, (tableInnerWidth - fixedColumnWidth) / 3)

                Rectangle {
                    Layout.fillWidth: true
                    height: 36
                    color: "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacing16
                        anchors.rightMargin: Theme.spacing16
                        spacing: Theme.spacing8

                        Text { Layout.preferredWidth: ospfNetworkTableLayout.flexibleColumnWidth; text: qsTr("PROCESS"); color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSmall; font.family: Theme.fontFamily; font.bold: true; elide: Text.ElideRight }
                        Text { Layout.preferredWidth: ospfNetworkTableLayout.flexibleColumnWidth; text: qsTr("NETWORK"); color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSmall; font.family: Theme.fontFamily; font.bold: true; elide: Text.ElideRight }
                        Text { Layout.preferredWidth: ospfNetworkTableLayout.flexibleColumnWidth; text: qsTr("WILDCARD"); color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSmall; font.family: Theme.fontFamily; font.bold: true; elide: Text.ElideRight }
                        Text { Layout.preferredWidth: 96; text: qsTr("AREA"); color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSmall; font.family: Theme.fontFamily; font.bold: true }
                        Text { Layout.preferredWidth: 34; text: "" }
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: Theme.borderWidth
                        color: Theme.contentPanelBorder
                    }
                }

                Text {
                    visible: !root.form.selectedNetworkProcessItem()
                        || root.form.selectedNetworkProcessItem().networks.count === 0
                    Layout.fillWidth: true
                    text: qsTr("No networks in the selected process.")
                    color: Theme.textDisabled
                    font.pixelSize: Theme.fontSizeNormal
                    font.family: Theme.fontFamily
                    horizontalAlignment: Text.AlignHCenter
                    topPadding: Theme.spacing16
                    bottomPadding: Theme.spacing16
                }

                Repeater {
                    model: {
                        const revision = root.form.statsRevision
                        const item = root.form.selectedNetworkProcessItem()
                        return item ? item.networks : null
                    }

                    delegate: Rectangle {
                        id: ospfNetworkRow
                        required property string network
                        required property string wildcard
                        required property var area
                        required property int index

                        width: ospfNetworkTableLayout.width
                        height: 42
                        color: rowHover.hovered ? Theme.sideBarItemHover : "transparent"

                        HoverHandler { id: rowHover }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.spacing16
                            anchors.rightMargin: Theme.spacing16
                            spacing: Theme.spacing8

                            Text { Layout.preferredWidth: ospfNetworkTableLayout.flexibleColumnWidth; text: root.form.processOptionLabel(root.form.selectedNetworkProcessIndex); color: Theme.textSecondary; font.pixelSize: Theme.fontSizeNormal; font.family: Theme.fontFamily; elide: Text.ElideRight }
                            Text { Layout.preferredWidth: ospfNetworkTableLayout.flexibleColumnWidth; text: ospfNetworkRow.network; color: Theme.accentColor; font.pixelSize: Theme.fontSizeNormal; font.family: Theme.fontFamily; elide: Text.ElideRight }
                            Text { Layout.preferredWidth: ospfNetworkTableLayout.flexibleColumnWidth; text: ospfNetworkRow.wildcard; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeNormal; font.family: Theme.fontFamily; elide: Text.ElideRight }
                            Text { Layout.preferredWidth: 96; text: ospfNetworkRow.area === undefined || ospfNetworkRow.area === null ? "" : String(ospfNetworkRow.area); color: Theme.textPrimary; font.pixelSize: Theme.fontSizeNormal; font.family: Theme.fontFamily; elide: Text.ElideRight }
                            RemoveIconButton {
                                tooltip: qsTr("Remove network")
                                onClicked: root.form.removeNetworkFromSelectedProcess(ospfNetworkRow.index)
                            }
                        }
                    }
                }
            }
        }
    }
}
