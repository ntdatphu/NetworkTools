import QtQuick
import QtQuick.Layouts
import UI

Rectangle {
    id: root
    required property var deviceData
    property bool selected: false
    signal clicked(string host)
    signal rightClicked(string host, bool configured)
    height: Theme.listItemHeight
    color: selected ? Theme.panelSideBarItemSelected : (hover.hovered ? Theme.panelSideBarItemHover : "transparent")

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 8
        spacing: 8
        Rectangle { width: 8; height: 8; radius: 4; color: Theme.statusConnected }
        Text {
            Layout.fillWidth: true
            text: deviceData.device_name || deviceData.host
            color: Theme.panelSideBarTextPrimary
            elide: Text.ElideRight
            font.family: Theme.fontFamily
        }
        Text {
            text: deviceData.configured ? "Configured" : "Not configured"
            color: deviceData.configured ? Theme.statusConnected : Theme.panelSideBarTextSecondary
            font.pixelSize: Theme.fontSizeSmall
        }
    }
    HoverHandler { id: hover }
    TapHandler { acceptedButtons: Qt.LeftButton; onTapped: root.clicked(deviceData.host) }
    TapHandler { acceptedButtons: Qt.RightButton; onTapped: root.rightClicked(deviceData.host, Boolean(deviceData.configured)) }
}

