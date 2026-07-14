pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import UI

Rectangle {
    id: aclView
    color: Theme.contentBackground

    property string currentHostIp: ""
    property string currentTab:    "Standard"

    ColumnLayout {
        anchors.fill: parent
        spacing:      0

        AclSubBar {
            Layout.fillWidth: true
            activeTab:        aclView.currentTab
            onTabClicked:     (tabName) => { aclView.currentTab = tabName }
        }

        AclForm {
            Layout.fillWidth:  true
            Layout.fillHeight: true
            visible:           aclView.currentTab !== "Bindings"
            currentHostIp:     aclView.currentHostIp
            currentAclType:    aclView.currentTab === "Bindings" ? "Standard" : aclView.currentTab
        }

        AclBindingsTab {
            Layout.fillWidth:  true
            Layout.fillHeight: true
            visible:           aclView.currentTab === "Bindings"
            currentHostIp:     aclView.currentHostIp
        }
    }
}
