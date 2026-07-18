pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root

    width: 0
    height: 0

    property bool commandsEnabled: true
    property bool inputFocusActive: false
    property bool reloadAvailable: false
    property bool devicesAvailable: true
    property bool databaseAvailable: false
    property bool settingsAvailable: true

    property var reloadHandler: null
    property var devicesHandler: null
    property var databaseHandler: null
    property var settingsHandler: null

    readonly property string reloadLabel: "Reload"
    readonly property string reloadShortcut: "Ctrl+R"
    readonly property string devicesLabel: "Devices"
    readonly property string devicesShortcut: "Ctrl+1"
    readonly property string databaseLabel: "Database"
    readonly property string databaseShortcut: "Ctrl+2"
    readonly property string settingsLabel: "Settings"
    readonly property string settingsShortcut: "Ctrl+3"

    readonly property bool contextualCommandsEnabled: commandsEnabled && !inputFocusActive
    readonly property bool reloadEnabled: contextualCommandsEnabled && reloadAvailable
    readonly property bool devicesEnabled: contextualCommandsEnabled && devicesAvailable
    readonly property bool databaseEnabled: contextualCommandsEnabled && databaseAvailable
    readonly property bool settingsEnabled: contextualCommandsEnabled && settingsAvailable

    function invoke(handler) {
        if (typeof handler !== "function")
            return false
        const result = handler()
        return result === undefined ? true : result !== false
    }

    function triggerReload() {
        return root.reloadEnabled && root.invoke(root.reloadHandler)
    }

    function triggerDevices() {
        return root.devicesEnabled && root.invoke(root.devicesHandler)
    }

    function triggerDatabase() {
        return root.databaseEnabled && root.invoke(root.databaseHandler)
    }

    function triggerSettings() {
        return root.settingsEnabled && root.invoke(root.settingsHandler)
    }

    Shortcut {
        objectName: "commandReloadShortcut"
        sequence: root.reloadShortcut
        context: Qt.ApplicationShortcut
        enabled: root.reloadEnabled
        onActivated: root.triggerReload()
    }

    Shortcut {
        objectName: "commandDevicesShortcut"
        sequence: root.devicesShortcut
        context: Qt.ApplicationShortcut
        enabled: root.devicesEnabled
        onActivated: root.triggerDevices()
    }

    Shortcut {
        objectName: "commandDatabaseShortcut"
        sequence: root.databaseShortcut
        context: Qt.ApplicationShortcut
        enabled: root.databaseEnabled
        onActivated: root.triggerDatabase()
    }

    Shortcut {
        objectName: "commandSettingsShortcut"
        sequence: root.settingsShortcut
        context: Qt.ApplicationShortcut
        enabled: root.settingsEnabled
        onActivated: root.triggerSettings()
    }
}
