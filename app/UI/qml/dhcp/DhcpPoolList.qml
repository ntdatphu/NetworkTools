pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import UI

SavedListPanel {
    id: panel
    property var poolModel
    signal editRequested(var row)
    signal deleteRequested(int index, var row)

    SplitView.fillWidth: true
    SplitView.minimumWidth: 0
    title: "Saved Pools"
    count: poolModel ? poolModel.count : 0
    countColor: Theme.accentColor
    emptyText: "No DHCP pools configured yet."
    headerComponent: Component {
        SavedListHeader {
            width: parent ? parent.width : 0
            Row {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 68
                Text { width: 96; text: "Pool"; color: Theme.textSecondary; font.bold: true }
                Text { width: 116; text: "Network"; color: Theme.textSecondary; font.bold: true }
                Text { width: 112; text: "Subnet"; color: Theme.textSecondary; font.bold: true }
                Text { width: 104; text: "Gateway"; color: Theme.textSecondary; font.bold: true }
                Text { text: "Lease"; color: Theme.textSecondary; font.bold: true }
            }
        }
    }
    ListView {
        anchors.fill: parent
        model: panel.poolModel
        clip: true
        spacing: 2
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        delegate: SavedListRow {
            required property int index
            required property var model
            rowIndex: index
            Row {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 8
                Text {
                    width: 96; height: parent.height; text: model.pool
                    color: Theme.textPrimary; elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                }
                Text {
                    width: 116; height: parent.height; text: model.network
                    color: Theme.textSecondary; elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                }
                Text {
                    width: 112; height: parent.height; text: model.subnetmask
                    color: Theme.textSecondary; elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                }
                Text {
                    width: 104; height: parent.height; text: model.defaut || "-"
                    color: Theme.textSecondary; elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                }
                Text {
                    width: Math.max(0, parent.width - 484); height: parent.height
                    text: model.lease || "1"; color: Theme.textSecondary
                    elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter
                }
                Item {
                    width: 56; height: parent.height
                    Row {
                        anchors.centerIn: parent
                        spacing: 4
                        IconButton {
                            buttonSize: 24; glyph: "E"; tooltip: "Edit"
                            onClicked: panel.editRequested(model)
                        }
                        IconButton {
                            buttonSize: 24; glyph: "X"; danger: true; tooltip: "Delete"
                            onClicked: panel.deleteRequested(index, model)
                        }
                    }
                }
            }
        }
    }
}
