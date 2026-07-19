pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

DataTable {
    id: root
    objectName: "syslogLogTable"

    property alias model: list.model
    property bool hasMore: false
    property bool limitReached: false
    property bool paused: false
    property int selectedIndex: -1
    signal loadOlderRequested()
    signal messageActivated(var rowData)

    count: list.count
    bodyMargins: 0
    emptyTitle: root.paused ? "Live updates are paused" : "No System Log messages"
    emptyDescription: root.paused
                      ? "Resume live updates to reload messages received while paused."
                      : "Start the listener, then configure a connected device to send Syslog messages."

    headerComponent: Component {
        DataTableHeader {
            RowLayout {
                anchors.fill: parent
                spacing: Theme.spacing8

                DataTableCell { Layout.preferredWidth: 150; header: true; text: "Time" }
                DataTableCell { Layout.preferredWidth: 120; header: true; text: "Host" }
                DataTableCell { Layout.preferredWidth: 120; header: true; text: "Source IP" }
                DataTableCell { Layout.preferredWidth: 132; header: true; text: "Facility / Severity" }
                DataTableCell { Layout.preferredWidth: 120; header: true; text: "Mnemonic" }
                DataTableCell { Layout.fillWidth: true; header: true; text: "Message" }
            }
        }
    }

    ListView {
        id: list
        anchors.fill: parent
        clip: true
        reuseItems: true
        spacing: 0
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        delegate: SyslogLogRow {
            required property int index
            required property var model

            width: ListView.view.width
            rowIndex: index
            rowData: model
            selected: root.selectedIndex === index
            onSelectedRequested: root.selectedIndex = index
            onActivated: function(data) {
                root.selectedIndex = index
                root.messageActivated(data)
            }
        }

        footer: Item {
            width: list.width
            height: root.hasMore || root.limitReached ? 48 : 0

            StandardButton {
                visible: root.hasMore
                anchors.centerIn: parent
                text: "Load Older Messages"
                type: "Secondary"
                onClicked: root.loadOlderRequested()
            }

            Text {
                visible: root.limitReached
                anchors.centerIn: parent
                text: "Showing the newest 2,000 messages. Refine the filters to narrow the view."
                color: Theme.textDisabled
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
            }
        }
    }
}
