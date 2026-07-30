pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import UI

SavedListPanel {
    id: root
    required property var groupModel
    signal removeRequested(int fhrpId)

    title: "Saved FHRP groups"
    count: groupModel.count
    emptyText: "No FHRP group includes this device."

    ListView {
        anchors.fill: parent
        spacing: Theme.spacing8
        clip: true
        model: root.groupModel
        delegate: Rectangle {
            id: groupRow
            required property int fhrp_id
            required property string protocol
            required property int group_number
            required property string virtual_ip
            required property var members
            width: ListView.view.width
            height: 62
            radius: Theme.radiusSmall
            color: hover.hovered
                   ? Theme.sideBarItemHover : Theme.contentPanelSurface
            border.color: Theme.contentPanelBorder
            border.width: Theme.borderWidth
            ColumnLayout {
                anchors.left: parent.left
                anchors.right: removeButton.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Theme.spacing12
                anchors.rightMargin: Theme.spacing8
                spacing: Theme.spacing2
                Text {
                    text: groupRow.protocol.toUpperCase()
                          + " " + groupRow.group_number
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.bold: true
                }
                Text {
                    text: groupRow.virtual_ip + " · "
                          + groupRow.members.length + " members"
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                }
            }
            StandardButton {
                id: removeButton
                anchors.right: parent.right
                anchors.rightMargin: Theme.spacing8
                anchors.verticalCenter: parent.verticalCenter
                text: "Remove"
                icon.source: AppAssets.actionDelete
                type: "Text"
                onClicked: root.removeRequested(groupRow.fhrp_id)
            }
            HoverHandler { id: hover }
        }
    }
}
