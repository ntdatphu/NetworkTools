pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

Rectangle {
    id: interfaceView

    readonly property bool compactLayout: width < Theme.dataWorkspaceBreakpoint
    property string currentHostIp: ""
    property int selectedListIndex: -1
    property var selectedInterface: ({})
    property int viewPushRevision: 0
    property alias selectedIfaceId: editor.selectedIfaceId
    readonly property bool isViewLoading: false
    readonly property bool textInputActive: {
        const focusItem = Window.window ? Window.window.activeFocusItem : null
        return focusItem instanceof TextInput || focusItem instanceof TextEdit
    }
    readonly property bool collectionShortcutsEnabled: visible
                                                       && !UiState.windowLock
                                                       && !textInputActive

    color: Theme.contentBackground

    function notify(message, type) {
        if (typeof statusBar !== "undefined")
            statusBar.showMessage(message, type)
    }

    function reloadData(reason) {
        reloadInterfaces()
        return currentHostIp !== ""
    }

    function normalizeRow(row) {
        const normalized = row || ({})
        for (const key in normalized) {
            if (normalized[key] === null || normalized[key] === undefined)
                normalized[key] = ""
        }
        return normalized
    }

    function reloadInterfaces() {
        const selectedId = Number(selectedInterface.iface_id || -1)
        selectedListIndex = -1
        selectedInterface = ({})
        interfaceModel.clear()
        if (currentHostIp === "")
            return
        const rows = dbManager.getRouterInterfaces(currentHostIp)
        for (let i = 0; i < rows.length; i++) {
            const row = normalizeRow(rows[i])
            interfaceModel.append(row)
            if (Number(row.iface_id || -1) === selectedId) {
                selectedListIndex = i
                selectedInterface = row
            }
        }
        viewPushRevision++
    }

    function loadInterface(name) {
        if (currentHostIp === "" || name === "")
            return
        const row = dbManager.getRouterInterfaceByName(currentHostIp, name)
        if (row && row.iface_id !== undefined)
            editor.applyRow(normalizeRow(row))
        else
            editor.beginInterface(name)
    }

    function selectInterfaceRow(index, row) {
        selectedListIndex = index
        selectedInterface = row || ({})
    }

    function editInterface(index, row) {
        selectInterfaceRow(index, row)
        editor.applyRow(selectedInterface)
    }

    function editSelectedInterface() {
        if (selectedListIndex >= 0)
            editor.applyRow(selectedInterface)
    }

    function deleteInterface(index, row) {
        selectInterfaceRow(index, row)
        const ifaceId = Number(selectedInterface.iface_id || -1)
        if (ifaceId < 0)
            return
        const ok = dbManager.deleteRouterInterface(ifaceId)
        if (ok) {
            if (editor.selectedIfaceId === ifaceId)
                editor.clearForm()
            reloadInterfaces()
            notify("Interface marked for removal.", "success")
        } else {
            notify("Could not remove the selected interface.", "error")
        }
    }

    function deleteSelectedInterface() {
        if (selectedListIndex >= 0)
            deleteInterface(selectedListIndex, selectedInterface)
    }

    function saveInterface(payload, interfaceName) {
        const ok = dbManager.saveRouterInterface(payload)
        if (!ok) {
            notify("Could not save the router interface.", "error")
            return
        }
        reloadInterfaces()
        loadInterface(interfaceName)
        notify("Router interface saved locally.", "success")
    }

    function openInterfaceContext(index, row, sceneX, sceneY) {
        selectInterfaceRow(index, row)
        interfaceContextMenu.openAt(sceneX, sceneY)
    }

    function openContextForSelectedInterface() {
        if (selectedListIndex < 0)
            return
        const item = savedPanel.itemAtIndex(selectedListIndex)
        if (!item)
            return
        const point = item.mapToItem(
            null,
            Math.min(item.width - Theme.spacing8, 180),
            item.height / 2
        )
        interfaceContextMenu.openAt(point.x, point.y)
    }

    onCurrentHostIpChanged: {
        editor.clearForm()
        reloadInterfaces()
    }
    Component.onCompleted: reloadInterfaces()

    ListModel { id: interfaceModel }

    InterfaceContextMenu {
        id: interfaceContextMenu
        parent: Window.window ? Window.window.contentItem : interfaceView
        hasTarget: interfaceView.selectedListIndex >= 0
        onEditRequested: interfaceView.editSelectedInterface()
        onDeleteRequested: interfaceView.deleteSelectedInterface()
        onRefreshRequested: interfaceView.reloadInterfaces()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 68
            color: Theme.contentSurface

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: Theme.borderWidth
                color: Theme.borderColor
            }

            WorkspaceHeader {
                anchors.fill: parent
                anchors.leftMargin: Theme.spacing24
                anchors.rightMargin: Theme.spacing24
                title: "Router Interfaces"
                subtitle: interfaceView.currentHostIp === ""
                          ? "No device selected"
                          : interfaceView.currentHostIp + " · Layer 3, WAN and tunnel profiles"

                ViewPushButton {
                    type: "Primary"
                    controllerName: "interface"
                    moduleName: "all"
                    hostIp: interfaceView.currentHostIp
                    ownerForm: interfaceView
                    refreshKey: interfaceView.viewPushRevision
                }
            }
        }

        SplitView {
            id: interfaceSplit
            objectName: "interfaceResponsiveSplit"
            Layout.fillWidth: true
            Layout.fillHeight: true
            orientation: interfaceView.compactLayout ? Qt.Vertical : Qt.Horizontal
            handle: StandardSplitHandle {}

            InterfaceSavedPanel {
                // Navigation stays on the left/top so selecting an existing
                // interface is the first action in the editing workflow.
                // Row actions: iconSource: AppAssets.actionEdit; tooltip: "Edit interface"
                // Row actions: iconSource: AppAssets.actionDelete; tooltip: "Delete interface"
                // WAN secret input stays in InterfaceEditorPane:
                // StandardPasswordField {
                id: savedPanel
                SplitView.fillWidth: false
                SplitView.fillHeight: true
                SplitView.preferredWidth: interfaceView.compactLayout
                                          ? interfaceSplit.width
                                          : interfaceSplit.width * 0.34
                SplitView.minimumWidth: interfaceView.compactLayout ? 0 : 300
                SplitView.preferredHeight: interfaceView.compactLayout
                                           ? Math.min(300, interfaceSplit.height * 0.38)
                                           : interfaceSplit.height
                SplitView.minimumHeight: interfaceView.compactLayout ? 220 : 0
                interfaceModel: interfaceModel
                selectedIndex: interfaceView.selectedListIndex
                onSelected: function(index, row) {
                    interfaceView.selectInterfaceRow(index, row)
                }
                onEditRequested: function(index, row) {
                    interfaceView.editInterface(index, row)
                }
                onDeleteRequested: function(index, row) {
                    interfaceView.deleteInterface(index, row)
                }
                onContextRequested: function(index, row, sceneX, sceneY) {
                    interfaceView.openInterfaceContext(index, row, sceneX, sceneY)
                }
            }

            InterfaceEditorPane {
                // The wider editor keeps L3/WAN/Tunnel fields readable and
                // avoids forcing users to scroll horizontally.
                id: editor
                SplitView.fillWidth: true
                SplitView.fillHeight: true
                SplitView.minimumWidth: interfaceView.compactLayout ? 0 : 480
                SplitView.minimumHeight: interfaceView.compactLayout ? 380 : 0
                currentHostIp: interfaceView.currentHostIp
                interfaceModel: interfaceModel
                onInterfaceRequested: function(interfaceName) {
                    interfaceView.loadInterface(interfaceName)
                }
                onSaveRequested: function(payload, interfaceName) {
                    interfaceView.saveInterface(payload, interfaceName)
                }
            }
        }
    }

    Shortcut {
        sequence: "F2"
        enabled: interfaceView.collectionShortcutsEnabled
                 && interfaceView.selectedListIndex >= 0
        onActivated: interfaceView.editSelectedInterface()
    }
    Shortcut {
        sequence: "Delete"
        enabled: interfaceView.collectionShortcutsEnabled
                 && interfaceView.selectedListIndex >= 0
        onActivated: interfaceView.deleteSelectedInterface()
    }
    Shortcut {
        sequence: "F5"
        enabled: interfaceView.collectionShortcutsEnabled
        onActivated: interfaceView.reloadInterfaces()
    }
    Shortcut {
        sequence: "Shift+F10"
        enabled: interfaceView.collectionShortcutsEnabled
                 && interfaceView.selectedListIndex >= 0
        onActivated: interfaceView.openContextForSelectedInterface()
    }
}
