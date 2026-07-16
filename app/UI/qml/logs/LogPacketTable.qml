pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

Rectangle {
    id: root

    required property var backend
    property int selectedPacketId: 0

    color: Theme.contentPanelSurface
    border.color: Theme.contentPanelBorder
    border.width: Theme.borderWidth
    radius: Theme.radiusSmall
    clip: true

    function protocolColor(protocol) {
        const value = String(protocol || "").toUpperCase()
        if (value === "TCP" || value === "SSH" || value === "TLS")
            return Theme.alertInfoSubtle
        if (value === "UDP" || value === "DNS")
            return Theme.alertWarningSubtle
        if (value === "ARP" || value.indexOf("ICMP") === 0)
            return Theme.alertSuccessSubtle
        return "transparent"
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.itemHeight
            color: Theme.sideBarBackground

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.spacing8
                anchors.rightMargin: Theme.spacing8
                spacing: Theme.spacing8

                Text { Layout.preferredWidth: 54; text: "No."; color: Theme.textSecondary; font.bold: true; font.pixelSize: Theme.fontSizeSmall; font.family: Theme.fontFamily }
                Text { Layout.preferredWidth: 88; text: "Time"; color: Theme.textSecondary; font.bold: true; font.pixelSize: Theme.fontSizeSmall; font.family: Theme.fontFamily }
                Text { Layout.preferredWidth: 150; text: "Source"; color: Theme.textSecondary; font.bold: true; font.pixelSize: Theme.fontSizeSmall; font.family: Theme.fontFamily }
                Text { Layout.preferredWidth: 150; text: "Destination"; color: Theme.textSecondary; font.bold: true; font.pixelSize: Theme.fontSizeSmall; font.family: Theme.fontFamily }
                Text { Layout.preferredWidth: 86; text: "Protocol"; color: Theme.textSecondary; font.bold: true; font.pixelSize: Theme.fontSizeSmall; font.family: Theme.fontFamily }
                Text { Layout.preferredWidth: 64; text: "Length"; color: Theme.textSecondary; font.bold: true; font.pixelSize: Theme.fontSizeSmall; font.family: Theme.fontFamily }
                Text { Layout.fillWidth: true; text: "Information"; color: Theme.textSecondary; font.bold: true; font.pixelSize: Theme.fontSizeSmall; font.family: Theme.fontFamily }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.borderWidth
            color: Theme.contentPanelBorder
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: packetList
                objectName: "logPacketList"
                anchors.fill: parent
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.backend ? root.backend.packetModel : null

                delegate: Rectangle {
                    id: packetRow
                    required property int packetId
                    required property int packetNo
                    required property string timeOffset
                    required property string source
                    required property string destination
                    required property string protocol
                    required property int packetLength
                    required property string info

                    width: packetList.width
                    height: Theme.itemHeight
                    color: root.selectedPacketId === packetId
                           ? Theme.sideBarItemSelected
                           : (rowHover.hovered ? Theme.sideBarItemHover : "transparent")

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacing8
                        anchors.rightMargin: Theme.spacing8
                        spacing: Theme.spacing8

                        Text { Layout.preferredWidth: 54; text: packetRow.packetNo; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSmall; font.family: Theme.monoFontFamily; elide: Text.ElideRight }
                        Text { Layout.preferredWidth: 88; text: packetRow.timeOffset; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSmall; font.family: Theme.monoFontFamily; elide: Text.ElideRight }
                        Text { Layout.preferredWidth: 150; text: packetRow.source; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSmall; font.family: Theme.monoFontFamily; elide: Text.ElideRight }
                        Text { Layout.preferredWidth: 150; text: packetRow.destination; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSmall; font.family: Theme.monoFontFamily; elide: Text.ElideRight }
                        Rectangle {
                            Layout.preferredWidth: 86
                            Layout.preferredHeight: 22
                            color: root.protocolColor(packetRow.protocol)
                            radius: Theme.radiusSmall
                            Text {
                                anchors.centerIn: parent
                                text: packetRow.protocol
                                color: Theme.textPrimary
                                font.bold: true
                                font.pixelSize: Theme.fontSizeSmall
                                font.family: Theme.fontFamily
                            }
                        }
                        Text { Layout.preferredWidth: 64; text: packetRow.packetLength; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSmall; font.family: Theme.monoFontFamily }
                        Text { Layout.fillWidth: true; text: packetRow.info; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSmall; font.family: Theme.fontFamily; elide: Text.ElideRight }
                    }

                    HoverHandler { id: rowHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: {
                            root.selectedPacketId = packetRow.packetId
                            root.backend.selectPacket(packetRow.packetId)
                        }
                    }
                }

                ScrollBar.vertical: ScrollBar {}
            }

            Text {
                anchors.centerIn: parent
                visible: root.backend && root.backend.packetModel.count === 0
                text: "No packet summaries in the current view"
                color: Theme.textDisabled
                font.pixelSize: Theme.fontSizeNormal
                font.family: Theme.fontFamily
            }
        }
    }
}
