import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

Item {
    id: root
    property alias model: list.model
    property bool hasMore: false
    signal loadOlderRequested()
    signal messageActivated(var rowData)

    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            color: Theme.featureBarBackground
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 8
                Text { Layout.preferredWidth: 150; text: "TIME"; color: Theme.textSecondary }
                Text { Layout.preferredWidth: 120; text: "HOST"; color: Theme.textSecondary }
                Text { Layout.preferredWidth: 105; text: "FACILITY/SEV"; color: Theme.textSecondary }
                Text { Layout.preferredWidth: 120; text: "MNEMONIC"; color: Theme.textSecondary }
                Text { Layout.fillWidth: true; text: "MESSAGE"; color: Theme.textSecondary }
            }
        }
        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            reuseItems: true
            delegate: SyslogLogRow {
                width: list.width
                rowData: model
                onActivated: data => root.messageActivated(data)
            }
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
            footer: StandardButton {
                width: list.width
                visible: root.hasMore
                text: "Load older messages"
                onClicked: root.loadOlderRequested()
            }
        }
    }
}

