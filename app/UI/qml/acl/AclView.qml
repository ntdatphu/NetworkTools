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
    }
    onCurrentHostIpChanged: syncHostToCurrentTab()
    Component.onCompleted: syncHostToCurrentTab()

    ColumnLayout {
        anchors.fill: parent
        spacing:      0

        AclSubBar {
            Layout.fillWidth: true
            activeTab:        aclView.currentTab
            onTabClicked:     (tabName) => { aclView.currentTab = tabName }
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
