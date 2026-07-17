pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

DataTable {
    id: root

    required property var backend
    property int selectedPacketId: 0

    count: backend && backend.packetModel ? backend.packetModel.count : 0
    bodyMargins: 0
    emptyTitle: "No packet summaries"
    emptyDescription: "No packets match the current device and filter selection."
    headerComponent: Component {
        DataTableHeader {
            RowLayout {
                anchors.fill: parent
                spacing: Theme.spacing8

                DataTableCell { Layout.preferredWidth: 54; header: true; text: "No." }
                DataTableCell { Layout.preferredWidth: 88; header: true; text: "Time" }
                DataTableCell { Layout.preferredWidth: 150; header: true; text: "Source" }
                DataTableCell { Layout.preferredWidth: 150; header: true; text: "Destination" }
                DataTableCell { Layout.preferredWidth: 86; header: true; text: "Protocol" }
                DataTableCell { Layout.preferredWidth: 64; header: true; text: "Length" }
                DataTableCell { Layout.fillWidth: true; header: true; text: "Information" }
            }
        }
    }

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

    ListView {
        id: packetList
        objectName: "logPacketList"
        anchors.fill: parent
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: root.backend ? root.backend.packetModel : null
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        delegate: DataTableRow {
            id: packetRow

            required property int index
            required property int packetId
            required property int packetNo
            required property string timeOffset
            required property string source
            required property string destination
            required property string protocol
            required property int packetLength
            required property string info

            width: ListView.view.width
            height: Theme.tableRowHeight
            rowIndex: index
            selected: root.selectedPacketId === packetId

            RowLayout {
                anchors.fill: parent
                spacing: Theme.spacing8

                DataTableCell { Layout.preferredWidth: 54; monospaced: true; text: packetRow.packetNo }
                DataTableCell { Layout.preferredWidth: 88; monospaced: true; text: packetRow.timeOffset }
                DataTableCell { Layout.preferredWidth: 150; monospaced: true; primary: true; text: packetRow.source }
                DataTableCell { Layout.preferredWidth: 150; monospaced: true; primary: true; text: packetRow.destination }
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
                DataTableCell { Layout.preferredWidth: 64; monospaced: true; text: packetRow.packetLength }
                DataTableCell { Layout.fillWidth: true; primary: true; text: packetRow.info }
            }

            TapHandler {
                onTapped: {
                    root.selectedPacketId = packetRow.packetId
                    root.backend.selectPacket(packetRow.packetId)
                }
            }
        }
    }
}
