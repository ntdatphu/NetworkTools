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
    readonly property var backend: typeof syslogManager !== "undefined" && syslogManager !== null
                                   ? syslogManager : null
    signal hostSelected(string host)
    signal operationFinished(bool ok, string message)

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
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            color: Theme.panelSideBarBackground
            Text {
                anchors.fill: parent
                anchors.leftMargin: 16
                verticalAlignment: Text.AlignVCenter
                text: "CONNECTED SYSLOG HOSTS"
                color: Theme.panelSideBarTextSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
            }
        }
        SideBarSearch {
            id: search
            Layout.fillWidth: true
            Layout.margins: 8
            placeholderText: "Search connected hosts..."
            onTextChanged: debounce.restart()
        }
        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: root.filteredDevices
            delegate: SyslogDeviceItem {
                required property var modelData
                width: ListView.view.width
                deviceData: modelData
                selected: root.selectedHost === modelData.host
                onClicked: function(host) {
                    root.selectedHost = host
                    root.hostSelected(host)
                }
                onRightClicked: (host, configured) => contextMenu.openFor(host, configured)
            }
            Text {
                anchors.centerIn: parent
                width: Math.max(0, parent.width - 32)
                visible: root.filteredDevices.length === 0
                text: root.devices.length === 0
                      ? "No connected devices.\nAdd and connect a device from Dashboard first."
                      : "No hosts match the current search."
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                color: Theme.panelSideBarTextSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
            }
        }
        StandardButton {
            Layout.fillWidth: true
            Layout.margins: 8
            text: "Refresh connected hosts"
            enabled: root.backend !== null
            onClicked: root.backend.loadConnectedDevices()
        }
    }

    Timer { id: debounce; interval: 250; onTriggered: root.applyFilter() }
    // Fallback refresh keeps the connected-only list current without touching DevicesPanel.
    Timer {
        interval: 5000
        repeat: true
        running: root.visible
        onTriggered: if (root.backend !== null) root.backend.loadConnectedDevices()
    }
    SyslogDeviceContextMenu {
        id: contextMenu
        busy: root.busy
        onConfigureRequested: host => root.backend.configureDevice(host)
        onCancelRequested: host => root.backend.cancelDevice(host)
    }
    SyslogSourceInterfaceDialog {
        id: sourceInterfaceDialog
        onPushRequested: (host, sourceInterface) => root.backend.configureDeviceWithInterface(host, sourceInterface)
    }
    Connections {
        target: root.backend
        function onConnectedDevicesChanged(rows) { root.devices = rows; root.applyFilter() }
        function onDeviceConfigStarted(host, action) { root.busy = true }
        function onDeviceConfigFinished(host, action, ok, message) {
            root.busy = false
            root.operationFinished(ok, message)
        }
        function onSourceInterfaceRequired(host, message) {
            root.busy = false
            sourceInterfaceDialog.openFor(host, message)
        }
    }
    // Delay device queries until the Syslog activity is actually opened.
    onVisibleChanged: if (visible && root.backend !== null) root.backend.loadConnectedDevices()
}
