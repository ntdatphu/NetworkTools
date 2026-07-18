import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

Item {
    id: root
    property var devices: []
    property var filteredDevices: []
    property string selectedHost: ""
    property bool busy: false
    signal hostSelected(string host)

    function applyFilter() {
        const value = search.text.toLowerCase().trim()
        filteredDevices = devices.filter(function(row) {
            return value === "" || String(row.host).toLowerCase().indexOf(value) >= 0
                || String(row.device_name || "").toLowerCase().indexOf(value) >= 0
        })
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 36
            color: Theme.panelSideBarBackground
            Text { anchors.centerIn: parent; text: "CONNECTED SYSLOG HOSTS"; color: Theme.panelSideBarTextSecondary }
        }
        SideBarSearch {
            id: search
            Layout.fillWidth: true; Layout.margins: 8
            placeholderText: "Search connected hosts..."
            onTextChanged: debounce.restart()
        }
        ListView {
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true; model: root.filteredDevices
            delegate: SyslogDeviceItem {
                width: ListView.view.width
                deviceData: modelData
                selected: root.selectedHost === modelData.host
                onClicked: host => { root.selectedHost = host; root.hostSelected(host) }
                onRightClicked: (host, configured) => contextMenu.openFor(host, configured)
            }
        }
        StandardButton {
            Layout.fillWidth: true; Layout.margins: 8
            text: "Refresh connected hosts"
            onClicked: syslogManager.loadConnectedDevices()
        }
    }

    Timer { id: debounce; interval: 250; onTriggered: root.applyFilter() }
    SyslogDeviceContextMenu {
        id: contextMenu
        busy: root.busy
        onConfigureRequested: host => syslogManager.configureDevice(host)
        onCancelRequested: host => syslogManager.cancelDevice(host)
    }
    Connections {
        target: syslogManager
        function onConnectedDevicesChanged(rows) { root.devices = rows; root.applyFilter() }
        function onDeviceConfigStarted(host, action) { root.busy = true }
        function onDeviceConfigFinished(host, action, ok, message) { root.busy = false }
    }
    Component.onCompleted: syslogManager.loadConnectedDevices()
}

