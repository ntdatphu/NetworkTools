pragma ComponentBehavior: Bound

import QtQuick
import Qt.labs.platform as NativeMenus
import NetworkUI

NativeMenus.MenuBar {
    id: appMenuBar

    property bool sidebarVisible: true

    signal newDeviceRequested()
    signal newDeviceBatchRequested()
    signal refreshDevicesRequested()
    signal toggleSidebarRequested()
    signal openTerminalRequested()
    signal showPythonStatusRequested()
    signal showAboutRequested()

    // ════════════════════════════════════════════════════════════
    // FILE
    // ════════════════════════════════════════════════════════════
    NativeMenus.Menu {
        title: qsTr("File")

        NativeMenus.MenuItem {
            text:        qsTr("New Connection")
            shortcut:    "Ctrl+N"
            onTriggered: appMenuBar.newDeviceRequested()
        }

        NativeMenus.MenuSeparator {}

        NativeMenus.MenuItem {
            text:        qsTr("Quit")
            shortcut:    "Alt+F4"
            onTriggered: Qt.quit()
        }
    }

    // ════════════════════════════════════════════════════════════
    // VIEW
    // ════════════════════════════════════════════════════════════
    NativeMenus.Menu {
        title: qsTr("View")

        NativeMenus.MenuItem {
            text:        appMenuBar.sidebarVisible
                             ? qsTr("Hide Sidebar")
                             : qsTr("Show Sidebar")
            shortcut:    "Ctrl+B"
            onTriggered: appMenuBar.toggleSidebarRequested()
        }

        NativeMenus.MenuSeparator {}

        NativeMenus.Menu {
            title: qsTr("Theme")

            NativeMenus.MenuItem {
                text:        qsTr("System Default")
                checkable:   true
                checked:     Theme.themeMode === 0
                onTriggered: Theme.themeMode = 0
            }

            NativeMenus.MenuItem {
                text:        qsTr("Light")
                checkable:   true
                checked:     Theme.themeMode === 1
                onTriggered: Theme.themeMode = 1
            }

            NativeMenus.MenuItem {
                text:        qsTr("Dark")
                checkable:   true
                checked:     Theme.themeMode === 2
                onTriggered: Theme.themeMode = 2
            }
        }
    }

    // ════════════════════════════════════════════════════════════
    // DEVICE
    // ════════════════════════════════════════════════════════════
    NativeMenus.Menu {
        title: qsTr("Device")

        NativeMenus.MenuItem {
            text:        qsTr("Add Device...")
            shortcut:    "Ctrl+N"
            onTriggered: appMenuBar.newDeviceRequested()
        }

        NativeMenus.MenuItem {
            text:        qsTr("Add Multiple Devices...")
            shortcut:    "Ctrl+Shift+N"
            onTriggered: appMenuBar.newDeviceBatchRequested()
        }

        NativeMenus.MenuItem {
            text:        qsTr("Refresh List")
            shortcut:    "F5"
            onTriggered: appMenuBar.refreshDevicesRequested()
        }

        NativeMenus.MenuSeparator {}

        NativeMenus.MenuItem {
            text:    qsTr("Connect All")
            enabled: false
        }

        NativeMenus.MenuItem {
            text:    qsTr("Disconnect All")
            enabled: false
        }
    }

    // ════════════════════════════════════════════════════════════
    // TOOLS
    // ════════════════════════════════════════════════════════════
    NativeMenus.Menu {
        title: qsTr("Tools")

        NativeMenus.MenuItem {
            text:        qsTr("Terminal")
            shortcut:    "Ctrl+Alt+T"
            onTriggered: appMenuBar.openTerminalRequested()
        }

        NativeMenus.MenuSeparator {}

        NativeMenus.MenuItem {
            text:        qsTr("Python Environment Status")
            onTriggered: appMenuBar.showPythonStatusRequested()
        }
    }

    // ════════════════════════════════════════════════════════════
    // HELP
    // ════════════════════════════════════════════════════════════
    NativeMenus.Menu {
        title: qsTr("Help")

        NativeMenus.MenuItem {
            text:        qsTr("GitHub Repository")
            onTriggered: Qt.openUrlExternally("https://github.com/Cherster0606/NCKH/")
        }

        NativeMenus.MenuSeparator {}

        NativeMenus.MenuItem {
            text:        qsTr("About NetworkUI")
            onTriggered: appMenuBar.showAboutRequested()
        }
    }
}