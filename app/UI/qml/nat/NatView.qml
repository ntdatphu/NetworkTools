pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import UI

Rectangle {
    id: natView
    color: Theme.contentBackground

    property string currentHostIp: ""
    property string currentTab:    "Static"

    ColumnLayout {
        anchors.fill: parent
        spacing:      0

        NatSubBar {
            Layout.fillWidth: true
            activeTab:        natView.currentTab
            onTabClicked:     (tabName) => { natView.currentTab = tabName }
        }

        Item {
            Layout.fillWidth:  true
            Layout.fillHeight: true

            Item {
                anchors.fill: parent
                visible:      natView.currentTab === "Info"

                Text {
                    anchors.centerIn: parent
                    text:             "Info — Not yet implemented"
                    color:            Theme.textDisabled
                    font.pixelSize:   Theme.fontSizeNormal
                    font.family:      Theme.fontFamily
                }
            }

            NatStaticForm {
                anchors.fill:  parent
                visible:       natView.currentTab === "Static"
                currentHostIp: natView.currentHostIp
            }

            NatDynamicForm {
                anchors.fill:  parent
                visible:       natView.currentTab === "Dynamic"
                currentHostIp: natView.currentHostIp
            }

            NatPatForm {
                anchors.fill:  parent
                visible:       natView.currentTab === "PAT"
                currentHostIp: natView.currentHostIp
            }

            NatInterfaceForm {
                anchors.fill:  parent
                visible:       natView.currentTab === "Interfaces"
                currentHostIp: natView.currentHostIp
            }

            NatAclForm {
                anchors.fill:  parent
                visible:       natView.currentTab === "ACL"
                currentHostIp: natView.currentHostIp
            }

            NatRouteMapForm {
                anchors.fill:  parent
                visible:       natView.currentTab === "Route Map"
                currentHostIp: natView.currentHostIp
            }
        }
    }
}
