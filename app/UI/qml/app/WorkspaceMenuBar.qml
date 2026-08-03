pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls

Controls.MenuBar {
    id: root

    property var newProjectHandler: null
    property var openProjectHandler: null
    property var saveHandler: null
    property var createSnapshotHandler: null
    property var snapshotHistoryHandler: null
    property var closeWorkspaceHandler: null
    property var toggleSidebarHandler: null
    property var devicesHandler: null
    property var databaseHandler: null
    property var settingsHandler: null
    property var shortcutsHandler: null
    property var aboutHandler: null

    property bool saveAvailable: false
    property bool databaseAvailable: false

    function invoke(handler) {
        if (typeof handler !== "function")
            return false
        const result = handler()
        return result === undefined ? true : result !== false
    }

    Controls.Action {
        id: newProjectAction
        text: qsTr("New Project...")
        onTriggered: root.invoke(root.newProjectHandler)
    }

    Controls.Action {
        id: createSnapshotAction
        text: qsTr("Create Snapshot…")
        enabled: root.saveAvailable
        onTriggered: root.invoke(root.createSnapshotHandler)
    }

    Controls.Action {
        id: snapshotHistoryAction
        text: qsTr("Snapshot History…")
        enabled: root.saveAvailable
        onTriggered: root.invoke(root.snapshotHistoryHandler)
    }

    Controls.Action {
        id: openProjectAction
        text: qsTr("Open Project...")
        shortcut: "Ctrl+Shift+O"
        onTriggered: root.invoke(root.openProjectHandler)
    }

    Controls.Action {
        id: saveAction
        text: qsTr("Save Workspace")
        shortcut: StandardKey.Save
        enabled: root.saveAvailable
        onTriggered: root.invoke(root.saveHandler)
    }

    Controls.Action {
        id: closeWorkspaceAction
        text: qsTr("Close Workspace")
        onTriggered: root.invoke(root.closeWorkspaceHandler)
    }

    Controls.Action {
        id: quitAction
        text: qsTr("Quit")
        shortcut: StandardKey.Quit
        onTriggered: Qt.quit()
    }

    Controls.Menu {
        title: qsTr("&File")

        Controls.MenuItem { action: newProjectAction }
        Controls.MenuItem { action: openProjectAction }
        Controls.MenuSeparator {}
        Controls.MenuItem { action: saveAction }
        Controls.MenuItem { action: createSnapshotAction }
        Controls.MenuItem { action: snapshotHistoryAction }
        Controls.MenuSeparator {}
        Controls.MenuItem { action: closeWorkspaceAction }
        Controls.MenuItem { action: quitAction }
    }

    Controls.Menu {
        title: qsTr("&View")

        Controls.MenuItem {
            text: qsTr("Toggle Sidebar")
            onTriggered: root.invoke(root.toggleSidebarHandler)
        }
        Controls.MenuSeparator {}
        Controls.MenuItem {
            text: qsTr("Devices")
            onTriggered: root.invoke(root.devicesHandler)
        }
        Controls.MenuItem {
            text: qsTr("Database")
            enabled: root.databaseAvailable
            onTriggered: root.invoke(root.databaseHandler)
        }
        Controls.MenuItem {
            text: qsTr("Settings")
            onTriggered: root.invoke(root.settingsHandler)
        }
    }

    Controls.Menu {
        title: qsTr("&Help")

        Controls.MenuItem {
            text: qsTr("Keyboard Shortcuts")
            onTriggered: root.invoke(root.shortcutsHandler)
        }
        Controls.MenuSeparator {}
        Controls.MenuItem {
            text: qsTr("About NetworkTools")
            onTriggered: root.invoke(root.aboutHandler)
        }
    }
}
