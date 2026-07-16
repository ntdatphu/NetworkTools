pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import UI
import UI as App

Rectangle {
    id: root
    required property var sourceModel
    property int selectedIndex: -1
    property bool selectionEnabled: true
    signal rowSelected(int index)

    color: Theme.contentSurface
    border.color: Theme.borderColor

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacing8
        spacing: Theme.spacing4

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            color: Theme.featureBarBackground
            radius: Theme.radiusSmall
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.spacing12
                anchors.rightMargin: Theme.spacing12
                Text { Layout.preferredWidth: 150; text: "Interface"; color: Theme.textSecondary; font.bold: true; font.family: Theme.fontFamily }
                Text { Layout.preferredWidth: 80; text: "Mode"; color: Theme.textSecondary; font.bold: true; font.family: Theme.fontFamily }
                Text { Layout.preferredWidth: 80; text: "VLAN"; color: Theme.textSecondary; font.bold: true; font.family: Theme.fontFamily }
                Text { Layout.fillWidth: true; text: "Description"; color: Theme.textSecondary; font.bold: true; font.family: Theme.fontFamily }
                Text { Layout.preferredWidth: 90; text: "Status"; color: Theme.textSecondary; font.bold: true; font.family: Theme.fontFamily }
            }
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: Theme.spacing4
            model: root.sourceModel
            delegate: Rectangle {
                id: row
                required property int index
                required property string if_name
                required property string description
                required property string mode
                required property string oper_status
                required property var access_vlan
                required property var native_vlan
                width: ListView.view.width
                height: 44
                radius: Theme.radiusSmall
                color: root.selectedIndex === index ? Theme.sideBarItemSelected
                     : hover.hovered ? Theme.sideBarItemHover
                     : "transparent"
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spacing12
                    anchors.rightMargin: Theme.spacing12
                    Text { Layout.preferredWidth: 150; text: row.if_name; color: Theme.textPrimary; font.family: Theme.fontFamily; elide: Text.ElideRight }
                    Text { Layout.preferredWidth: 80; text: row.mode; color: Theme.textPrimary; font.family: Theme.fontFamily }
                    Text { Layout.preferredWidth: 80; text: row.mode === "access" ? (row.access_vlan || "—") : (row.native_vlan || "—"); color: Theme.textSecondary; font.family: Theme.fontFamily }
                    Text { Layout.fillWidth: true; text: row.description || "—"; color: Theme.textSecondary; font.family: Theme.fontFamily; elide: Text.ElideRight }
                    App.StatusBadge { Layout.preferredWidth: 90; value: row.oper_status }
                }
                HoverHandler { id: hover }
                TapHandler {
                    enabled: root.selectionEnabled
                    onTapped: root.rowSelected(row.index)
                }
            }
            Text {
                anchors.centerIn: parent
                visible: root.sourceModel.count === 0
                text: "No switch ports saved"
                color: Theme.textSecondary
                font.family: Theme.fontFamily
            }
        }
    }
}
