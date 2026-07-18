import QtQuick
import QtQuick.Controls.Basic
import UI

// Kept separate from DeviceContextMenu so existing device actions remain unchanged.
Menu {
    id: root
    property string targetHost: ""
    property bool configured: false
    property bool busy: false
    signal configureRequested(string host)
    signal cancelRequested(string host)

    function openFor(host, isConfigured) {
        targetHost = host
        configured = isConfigured
        open()
    }

    MenuItem {
        text: "Syslog Server"
        enabled: !root.configured && !root.busy
        onTriggered: root.configureRequested(root.targetHost)
    }
    MenuItem {
        text: "Cancel Syslog Server"
        enabled: root.configured && !root.busy
        onTriggered: root.cancelRequested(root.targetHost)
    }
}
