pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import UI

RowLayout {
    id: root
    property int formMode: 0
    property bool hasSelection: false
    property bool dirty: false
    property bool valid: true
    property bool saving: false

    signal addRequested()
    signal editRequested()
    signal saveRequested()
    signal cancelRequested()
    signal refreshRequested()

    spacing: Theme.spacing8

    StandardButton {
        text: "Add"
        visible: root.formMode === 0
        enabled: !root.saving
        onClicked: root.addRequested()
    }
    StandardButton {
        text: "Edit"
        visible: root.formMode === 0
        enabled: root.hasSelection && !root.saving
        onClicked: root.editRequested()
    }
    StandardButton {
        text: "Reload"
        icon.source: AppAssets.resource("resources/general/database-reload.svg")
        visible: root.formMode === 0
        enabled: !root.saving
        onClicked: root.refreshRequested()
    }
    StandardButton {
        text: "Cancel"
        type: "Text"
        visible: root.formMode !== 0
        enabled: !root.saving
        onClicked: root.cancelRequested()
    }
    StandardButton {
        text: root.saving ? "Saving..." : "Save"
        icon.source: AppAssets.resource("resources/general/save.svg")
        type: "Primary"
        visible: root.formMode !== 0
        enabled: root.dirty && root.valid && !root.saving
        onClicked: root.saveRequested()
    }
}
