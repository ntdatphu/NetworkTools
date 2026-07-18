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
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 8
                Text { Layout.preferredWidth: 145; text: "TIME"; color: Theme.textSecondary }
                Text { Layout.preferredWidth: 105; text: "HOST"; color: Theme.textSecondary }
                Text { Layout.preferredWidth: 105; text: "SOURCE IP"; color: Theme.textSecondary }
                Text { Layout.preferredWidth: 100; text: "FACILITY/SEV"; color: Theme.textSecondary }
                Text { Layout.preferredWidth: 110; text: "MNEMONIC"; color: Theme.textSecondary }
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
                required property var model
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

    Text {
        anchors.centerIn: parent
        visible: list.count === 0
        text: "No Syslog messages yet.\nStart the listener, then configure a device to send logs."
        horizontalAlignment: Text.AlignHCenter
        color: Theme.textSecondary
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeNormal
    }
}
