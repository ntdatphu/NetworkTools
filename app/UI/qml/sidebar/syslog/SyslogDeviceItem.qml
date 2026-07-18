import QtQuick
import QtQuick.Layouts
import UI

Rectangle {
    id: root
    required property var deviceData
    property bool selected: false
    signal clicked(string host)
    signal rightClicked(string host, bool configured)

    height: Math.max(Theme.listItemHeight, 38)
    color: selected ? Theme.panelSideBarItemSelected
                    : (hover.hovered ? Theme.panelSideBarItemHover : "transparent")

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 8
        spacing: 8

        Rectangle { width: 8; height: 8; radius: 4; color: Theme.statusConnected }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            Text {
                Layout.fillWidth: true
                text: root.deviceData.device_name || root.deviceData.host
                color: Theme.panelSideBarTextPrimary
                elide: Text.ElideRight
                font.family: Theme.fontFamily
            }
            Text {
                Layout.fillWidth: true
                text: root.deviceData.host
                color: Theme.panelSideBarTextSecondary
                elide: Text.ElideRight
                font.pixelSize: Theme.fontSizeSmall
                font.family: Theme.fontFamily
            }
        }
        Text {
            text: root.deviceData.configured ? "Configured" : "Not configured"
            color: root.deviceData.configured ? Theme.statusConnected : Theme.panelSideBarTextSecondary
            font.pixelSize: Theme.fontSizeSmall
            font.family: Theme.fontFamily
        }
    }

    HoverHandler { id: hover }
    TapHandler { acceptedButtons: Qt.LeftButton; onTapped: root.clicked(root.deviceData.host) }
    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: root.rightClicked(root.deviceData.host, Boolean(root.deviceData.configured))
    }
}
