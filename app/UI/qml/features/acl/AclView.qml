pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import UI

Rectangle {
    id: aclView
    color: Theme.contentBackground

    property string currentHostIp: ""
    property string currentTab:    "Standard"
    property string currentRulesTab: "Standard"
    property bool rulesLoaded: true
    property bool bindingsLoaded: false
    property string rulesHostIp: ""
    property string bindingsHostIp: ""
    readonly property bool isViewLoading: currentTab === "Bindings"
                                                  ? bindingsLoader.status === Loader.Loading
                                                  : rulesLoader.status === Loader.Loading

    function activeLoader() {
        return currentTab === "Bindings" ? bindingsLoader : rulesLoader
    }

    function hasUnsavedChanges(item) {
        if (!item)
            return false
        return item.hasPendingLocalChanges === true
                || item.hasPendingDeletes === true
                || item.dirty === true
                || (item.formMode !== undefined && Number(item.formMode) !== 0)
                || (item.isEditing && item.isEditing())
    }

    function reloadData(reason) {
        const loader = activeLoader()
        const item = loader ? loader.item : null
        if (!item || hasUnsavedChanges(item))
            return false
        if (item.reloadData)
            return item.reloadData(reason || "activation")
        if (currentTab === "Bindings" && item.reloadAll) {
            item.reloadAll()
            return true
        }
        if (currentTab !== "Bindings" && item.refreshSavedAcls) {
            item.refreshSavedAcls()
            return true
        }
        return false
    }

    function activateTab(tabName) {
        currentTab = tabName
        syncHostToCurrentTab()
        ensureCurrentTabLoaded()
        activationReloadTimer.restart()
    }

    function ensureCurrentTabLoaded() {
        if (rulesLoader.status === Loader.Loading && currentTab === "Bindings")
            rulesLoaded = false
        if (bindingsLoader.status === Loader.Loading && currentTab !== "Bindings")
            bindingsLoaded = false

        if (currentTab === "Bindings")
            bindingsLoaded = true
        else
            rulesLoaded = true
    }

    function syncHostToCurrentTab() {
        if (currentTab === "Bindings")
            bindingsHostIp = currentHostIp
        else
            rulesHostIp = currentHostIp
    }

    onCurrentTabChanged: {
        if (currentTab !== "Bindings")
            currentRulesTab = currentTab
        syncHostToCurrentTab()
        ensureCurrentTabLoaded()
        activationReloadTimer.restart()
    }
    onCurrentHostIpChanged: syncHostToCurrentTab()
    Component.onCompleted: syncHostToCurrentTab()

    Timer {
        id: activationReloadTimer
        interval: 0
        repeat: false
        onTriggered: aclView.reloadData("subfeature-activated")
    }

    ColumnLayout {
        anchors.fill: parent
        spacing:      0

        AclSubBar {
            Layout.fillWidth: true
            activeTab:        aclView.currentTab
            onTabClicked:     (tabName) => aclView.activateTab(tabName)
        }

        Item {
            Layout.fillWidth:  true
            Layout.fillHeight: true

            Loader {
                id: rulesLoader
                objectName: "aclRulesLoader"
                anchors.fill: parent
                active: aclView.rulesLoaded
                asynchronous: true
                visible: aclView.currentTab !== "Bindings"
                sourceComponent: Component {
                    AclForm {
                        currentHostIp: aclView.rulesHostIp
                        currentAclType: aclView.currentRulesTab
                    }
                }
            }

            Loader {
                id: bindingsLoader
                objectName: "aclBindingsLoader"
                anchors.fill: parent
                active: aclView.bindingsLoaded
                asynchronous: true
                visible: aclView.currentTab === "Bindings"
                sourceComponent: Component {
                    AclBindingsTab { currentHostIp: aclView.bindingsHostIp }
                }
            }
        }
    }
}
