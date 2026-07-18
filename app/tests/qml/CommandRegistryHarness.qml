import QtQuick
import QtQuick.Controls.Basic
import UI

ApplicationWindow {
    id: root
    width: 480
    height: 320
    visible: true

    property int reloadCount: 0
    property int devicesCount: 0
    property int databaseCount: 0
    property int settingsCount: 0
    property alias inputFocusActive: registry.inputFocusActive
    property alias reloadAvailable: registry.reloadAvailable
    property alias databaseAvailable: registry.databaseAvailable

    CommandRegistry {
        id: registry
        objectName: "testCommandRegistry"
        reloadAvailable: true
        databaseAvailable: true
        reloadHandler: function() { root.reloadCount++; return true }
        devicesHandler: function() { root.devicesCount++; return true }
        databaseHandler: function() { root.databaseCount++; return true }
        settingsHandler: function() { root.settingsCount++; return true }
    }
}
