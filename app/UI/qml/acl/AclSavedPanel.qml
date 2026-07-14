pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

SavedListPanel {
    id: panel
    property var aclModel
    property int selectedAclId: 0
    signal viewRequested(int index)
    signal editRequested(int index)
    signal deleteRequested(int aclId)

    Layout.fillWidth: true
    Layout.preferredHeight: Math.max(210, parent ? parent.height * 0.38 : 210)
    title: "Saved ACLs"
    count: aclModel ? aclModel.count : 0
    countColor: Theme.accentColor
    emptyText: "No saved ACLs for this host and type."
    headerComponent: Component {
        SavedListHeader {
            width: parent ? parent.width : 0
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 196
                Text { Layout.preferredWidth: 34; text: "#"; color: Theme.textSecondary; font.bold: true }
                Text { Layout.fillWidth: true; text: "ACL"; color: Theme.textSecondary; font.bold: true }
                Text { Layout.preferredWidth: 68; text: "Rules"; color: Theme.textSecondary; font.bold: true }
                Text { Layout.preferredWidth: 120; text: "Binding"; color: Theme.textSecondary; font.bold: true }
            }
        }
    }

    ListView {
        anchors.fill: parent
        model: panel.aclModel
        clip: true
        spacing: 2
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        delegate: SavedListRow {
            required property int index
            required property int aclIndex
            required property int aclId
            required property string aclName
            required property string description
            required property int ruleCount
            required property string bindingText
            rowIndex: index
            width: ListView.view ? ListView.view.width : 0
            height: description !== "" ? 48 : 38
            baseColor: panel.selectedAclId === aclId
                       ? Qt.rgba(Theme.accentColor.r, Theme.accentColor.g, Theme.accentColor.b, 0.14)
                       : Theme.contentSurface
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 8
                spacing: Theme.spacing8
                Text { Layout.preferredWidth: 34; text: index + 1; color: Theme.textDisabled }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Text { Layout.fillWidth: true; text: aclName; color: Theme.textPrimary; elide: Text.ElideRight }
                    Text {
                        visible: description !== ""
                        Layout.fillWidth: true
                        text: description
                        color: Theme.textDisabled
                        font.pixelSize: Theme.fontSizeSmall
                        elide: Text.ElideRight
                    }
                }
                Text { Layout.preferredWidth: 68; text: ruleCount; color: Theme.textSecondary }
                Text {
                    Layout.preferredWidth: 120
                    text: bindingText
                    color: Theme.textSecondary
                    elide: Text.ElideRight
                }
                StandardButton {
                    Layout.preferredWidth: 56
                    text: "View"
                    type: "Secondary"
                    onClicked: panel.viewRequested(aclIndex)
                }
                StandardButton {
                    Layout.preferredWidth: 56
                    text: "Edit"
                    type: "Secondary"
                    onClicked: panel.editRequested(aclIndex)
                }
                StandardButton {
                    Layout.preferredWidth: 64
                    text: "Delete"
                    type: "Secondary"
                    onClicked: panel.deleteRequested(aclId)
                }
            }
        }
    }
}
