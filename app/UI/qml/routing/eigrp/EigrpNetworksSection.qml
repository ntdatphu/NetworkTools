pragma ComponentBehavior: Bound

import QtQuick
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
            implicitHeight: layout.implicitHeight + Theme.spacing32
            radius: Theme.cardRadius
            color: Theme.contentPanelSurface
            border.color: Theme.contentPanelBorder
            border.width: Theme.borderWidth

            ColumnLayout {
                id: layout
                anchors.fill: parent
                anchors.margins: Theme.spacing16
                spacing: Theme.spacing12

                SectionTitle { text: "EIGRP NETWORKS" }

                GridLayout {
                    Layout.fillWidth: true
                    columns: width < 760 ? 2 : 4
                    columnSpacing: Theme.spacing12
                    rowSpacing: Theme.spacing8

                    RoutingProcessComboBox { form: root.form; protocol: "EIGRP" }
                    StandardTextField { id: networkField; Layout.fillWidth: true; labelText: "Network"; placeholderText: "10.0.0.0" }
                    StandardTextField { id: wildcardField; Layout.fillWidth: true; labelText: "Wildcard"; placeholderText: "optional" }
                    StandardTextField { id: ifaceField; Layout.fillWidth: true; labelText: "Interface"; placeholderText: "optional" }
                }

                RowLayout {
                    Layout.fillWidth: true
                    StandardButton {
                        text: "+ Add Network"
                        type: "Primary"
                        onClicked: {
                            if (root.form.addNetworkToSelectedProcess(networkField.text, wildcardField.text, ifaceField.text)) {
                                networkField.clear()
                                wildcardField.clear()
                                ifaceField.clear()
                            }
                        }
                    }
                    StandardButton { text: "Clear"; type: "Secondary"; onClicked: { networkField.clear(); wildcardField.clear(); ifaceField.clear() } }
                    Item { Layout.fillWidth: true }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.leftMargin: 24
            Layout.rightMargin: 24
            implicitHeight: table.implicitHeight
            radius: Theme.cardRadius
            color: Theme.contentPanelSurface
            border.color: Theme.contentPanelBorder
            border.width: Theme.borderWidth

            ColumnLayout {
                id: table
                width: parent.width
                spacing: 0

                Rectangle {
                    Layout.fillWidth: true
                    height: 36
                    color: "transparent"
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacing16
                        anchors.rightMargin: Theme.spacing16
                        spacing: Theme.spacing8
                        Text { Layout.fillWidth: true; text: "PROCESS"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSmall; font.family: Theme.fontFamily; font.bold: true }
                        Text { Layout.fillWidth: true; text: "NETWORK"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSmall; font.family: Theme.fontFamily; font.bold: true }
                        Text { Layout.fillWidth: true; text: "WILDCARD"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSmall; font.family: Theme.fontFamily; font.bold: true }
                        Text { Layout.fillWidth: true; text: "INTERFACE"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSmall; font.family: Theme.fontFamily; font.bold: true }
                        Text { Layout.preferredWidth: 40; text: "" }
                    }
                    Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: Theme.borderWidth; color: Theme.contentPanelBorder }
                }

                Text {
                    visible: !root.form.selectedProcessItem() || root.form.selectedProcessItem().networks.count === 0
                    Layout.fillWidth: true
                    text: "No networks in the selected process."
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
                        const item = root.form.selectedProcessItem()
                        return item ? item.networks : null
                    }
                    delegate: Rectangle {
                        required property string network
                        required property string wildcard
                        required property string interface_name
                        required property int index
                        width: table.width
                        height: 42
                        color: rowHover.hovered ? Theme.sideBarItemHover : "transparent"
                        HoverHandler { id: rowHover }
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.spacing16
                            anchors.rightMargin: Theme.spacing16
                            spacing: Theme.spacing8
                            Text { Layout.fillWidth: true; text: root.form.processOptionLabel(root.form.selectedNetworkProcessIndex); color: Theme.textSecondary; font.pixelSize: Theme.fontSizeNormal; font.family: Theme.fontFamily; elide: Text.ElideRight }
                            Text { Layout.fillWidth: true; text: network; color: Theme.accentColor; font.pixelSize: Theme.fontSizeNormal; font.family: Theme.fontFamily; elide: Text.ElideRight }
                            Text { Layout.fillWidth: true; text: wildcard; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeNormal; font.family: Theme.fontFamily; elide: Text.ElideRight }
                            Text { Layout.fillWidth: true; text: interface_name; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeNormal; font.family: Theme.fontFamily; elide: Text.ElideRight }
                            RemoveIconButton { tooltip: "Remove network"; onClicked: root.form.removeNetworkFromSelectedProcess(index) }
                        }
                    }
                }
            }
        }
    }
}
