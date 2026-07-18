pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

Item {
    id: root
    objectName: "syslogDevicesPanel"

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
            return value === ""
                || String(row.host || "").toLowerCase().indexOf(value) >= 0
                || String(row.device_name || "").toLowerCase().indexOf(value) >= 0
        })
    }

    function reloadDevices() {
        if (backend !== null)
            backend.loadConnectedDevices()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            color: Theme.panelSideBarBackground

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.spacing16
                anchors.rightMargin: Theme.spacing12
                spacing: Theme.spacing8

                Text {
                    Layout.fillWidth: true
                    text: "SYSTEM LOGS"
                    color: Theme.panelSideBarTextSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.capitalization: Font.AllUppercase
                    font.weight: Font.Medium
                }
                Text {
                    text: String(root.devices.length)
                    color: Theme.panelSideBarTextDisabled
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: Theme.borderWidth
                color: Theme.panelSideBarBorderColor
            }
        }

        SideBarSearch {
            id: search
            Layout.fillWidth: true
            Layout.margins: Theme.spacing8
            placeholderText: "Search connected hosts..."
            onTextChanged: debounce.restart()
        }

        ListView {
            id: deviceList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.filteredDevices
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            delegate: SyslogDeviceItem {
                required property var modelData
                width: ListView.view.width
                deviceData: modelData
                selected: root.selectedHost === String(modelData.host || "")
                onClicked: function(host) {
                    root.selectedHost = host
                    root.hostSelected(host)
                }
                onRightClicked: function(host, configured, globalX, globalY) {
                    root.selectedHost = host
                    root.hostSelected(host)
                    contextMenu.openAt(globalX, globalY, host, configured)
                }
            }

            Text {
                anchors.centerIn: parent
                width: Math.max(0, parent.width - Theme.spacing32)
                visible: root.filteredDevices.length === 0
                text: root.backend === null
                      ? "System Logs backend is unavailable."
                      : root.devices.length === 0
                        ? "No connected devices.\nConnect a device from Dashboard first."
                        : "No hosts match the current search."
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                color: Theme.panelSideBarTextSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 52
            color: Theme.panelSideBarBackground

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: Theme.borderWidth
                color: Theme.panelSideBarBorderColor
            }

            StandardButton {
                anchors.fill: parent
                anchors.margins: Theme.spacing8
                text: root.busy ? "Applying Configuration..." : "Refresh Connected Hosts"
                icon.source: AppAssets.actionRefresh
                type: "Secondary"
                enabled: root.backend !== null && !root.busy
                onClicked: root.reloadDevices()
            }
        }
    }

    Timer {
        id: debounce
        interval: 250
        repeat: false
        onTriggered: root.applyFilter()
    }

    Timer {
        interval: 5000
        repeat: true
        running: root.visible && root.backend !== null
        onTriggered: root.reloadDevices()
    }

    SyslogDeviceContextMenu {
        id: contextMenu
        parent: Overlay.overlay
        busy: root.busy
        onConfigureRequested: host => {
            if (root.backend !== null)
                root.backend.configureDevice(host)
        }
        onCancelRequested: host => {
            if (root.backend !== null)
                root.backend.cancelDevice(host)
        }
    }

    SyslogSourceInterfaceDialog {
        id: sourceInterfaceDialog
        onPushRequested: function(host, sourceInterface) {
            if (root.backend !== null)
                root.backend.configureDeviceWithInterface(host, sourceInterface)
        }
    }

    Connections {
        target: root.backend

        function onConnectedDevicesChanged(rows) {
            root.devices = rows || []
            root.applyFilter()
        }

        function onDeviceConfigStarted(host, action) {
            root.busy = true
        }

        function onDeviceConfigFinished(host, action, ok, message) {
            root.busy = false
            root.operationFinished(ok, message)
        }

        function onSourceInterfaceRequired(host, message) {
            root.busy = false
            sourceInterfaceDialog.openFor(host, message)
        }
    }

    onVisibleChanged: {
        if (visible)
            reloadDevices()
    }
}
