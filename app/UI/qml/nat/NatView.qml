pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import UI

Rectangle {
    id: natView
    color: Theme.contentBackground

    property string currentHostIp: ""
    property string currentTab:    "Static"
    property bool staticLoaded: true
    property bool dynamicLoaded: false
    property bool patLoaded: false
    property bool interfacesLoaded: false
    property bool aclLoaded: false
    property bool routeMapLoaded: false

    function ensureCurrentTabLoaded() {
        switch (currentTab) {
        case "Static": staticLoaded = true; break
        case "Dynamic": dynamicLoaded = true; break
        case "PAT": patLoaded = true; break
        case "Interfaces": interfacesLoaded = true; break
        case "ACL": aclLoaded = true; break
        case "Route Map": routeMapLoaded = true; break
        }
    }

    onCurrentTabChanged: ensureCurrentTabLoaded()

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

            Loader {
                anchors.fill:  parent
                active: natView.staticLoaded
                visible: natView.currentTab === "Static"
                sourceComponent: Component {
                    NatStaticForm { currentHostIp: natView.currentHostIp }
                }
            }

            Loader {
                anchors.fill:  parent
                active: natView.dynamicLoaded
                visible: natView.currentTab === "Dynamic"
                sourceComponent: Component {
                    NatDynamicForm { currentHostIp: natView.currentHostIp }
                }
            }

            Loader {
                anchors.fill:  parent
                active: natView.patLoaded
                visible: natView.currentTab === "PAT"
                sourceComponent: Component {
                    NatPatForm { currentHostIp: natView.currentHostIp }
                }
            }

            Loader {
                anchors.fill:  parent
                active: natView.interfacesLoaded
                visible: natView.currentTab === "Interfaces"
                sourceComponent: Component {
                    NatInterfaceForm { currentHostIp: natView.currentHostIp }
                }
            }

            Loader {
                anchors.fill:  parent
                active: natView.aclLoaded
                visible: natView.currentTab === "ACL"
                sourceComponent: Component {
                    NatAclForm { currentHostIp: natView.currentHostIp }
                }
            }

            Loader {
                anchors.fill:  parent
                active: natView.routeMapLoaded
                visible: natView.currentTab === "Route Map"
                sourceComponent: Component {
                    NatRouteMapForm { currentHostIp: natView.currentHostIp }
                }
            }
        }
    }
}
