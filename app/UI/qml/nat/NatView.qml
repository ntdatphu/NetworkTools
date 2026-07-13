pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import UI

Rectangle {
    id: natView
    color: Theme.contentBackground

    property string currentHostIp: ""
    property string currentTab:    "Static"
    property int viewPushRevision: 0
    property bool staticLoaded: true
    property bool dynamicLoaded: false
    property bool patLoaded: false
    property bool interfacesLoaded: false
    property bool aclLoaded: false
    property bool routeMapLoaded: false
    property bool infoLoaded: false

    function ensureCurrentTabLoaded() {
        switch (currentTab) {
        case "Static": staticLoaded = true; break
        case "Dynamic": dynamicLoaded = true; break
        case "PAT": patLoaded = true; break
        case "Interfaces": interfacesLoaded = true; break
        case "ACL": aclLoaded = true; break
        case "Route Map": routeMapLoaded = true; break
        case "Info": infoLoaded = true; break
        }
    }

    onCurrentTabChanged: ensureCurrentTabLoaded()

    function refreshViewPush() {
        viewPushRevision++
    }

    function reloadNatData() {
        if (staticLoader.item) staticLoader.item.reloadEntries()
        if (dynamicLoader.item) dynamicLoader.item.reloadPools()
        if (patLoader.item) patLoader.item.reloadRules()
        if (interfacesLoader.item) interfacesLoader.item.reloadInterfaces()
        if (aclLoader.item) aclLoader.item.reloadAcls()
        if (routeMapLoader.item) routeMapLoader.item.reloadEntries()
        refreshViewPush()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing:      0

        NatSubBar {
            Layout.fillWidth: true
            activeTab:        natView.currentTab
            onTabClicked:     (tabName) => { natView.currentTab = tabName }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 58
            color: Theme.contentSurface

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: Theme.borderWidth
                color: Theme.borderColor
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 24
                anchors.rightMargin: 24
                spacing: Theme.spacing12

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        text: "NAT Configuration"
                        color: Theme.textPrimary
                        font.pixelSize: Theme.fontSizeLarge
                        font.family: Theme.fontFamily
                        font.bold: true
                    }
                    Text {
                        Layout.fillWidth: true
                        text: String(natView.currentHostIp || "").trim() === "" ? "No device selected" : natView.currentHostIp
                        color: Theme.textSecondary
                        font.pixelSize: Theme.fontSizeSmall
                        font.family: Theme.fontFamily
                        elide: Text.ElideRight
                    }
                }

                ViewPushButton {
                    type: "Primary"
                    controllerName: "nat"
                    moduleName: "all"
                    hostIp: natView.currentHostIp
                    ownerForm: natView
                    refreshKey: natView.viewPushRevision
                    onPushCompleted: function(ok, message) {
                        if (ok) natView.reloadNatData()
                    }
                }
            }
        }

        Item {
            Layout.fillWidth:  true
            Layout.fillHeight: true

            // Phase D: converted from static Text to Loader (consistent with other tabs).
            // When NatInfoView is implemented, replace the placeholder component.
            Loader {
                anchors.fill: parent
                active: natView.infoLoaded
                visible: natView.currentTab === "Info"
                sourceComponent: Component {
                    Item {
                        Text {
                            anchors.centerIn: parent
                            text:             "NAT Info — Not yet implemented"
                            color:            Theme.textDisabled
                            font.pixelSize:   Theme.fontSizeNormal
                            font.family:      Theme.fontFamily
                        }
                    }
                }
            }

            Loader {
                id: staticLoader
                anchors.fill:  parent
                active: natView.staticLoaded
                visible: natView.currentTab === "Static"
                sourceComponent: Component {
                    NatStaticForm {
                        currentHostIp: natView.currentHostIp
                        onDataChanged: natView.refreshViewPush()
                    }
                }
            }

            Loader {
                id: dynamicLoader
                anchors.fill:  parent
                active: natView.dynamicLoaded
                visible: natView.currentTab === "Dynamic"
                sourceComponent: Component {
                    NatDynamicForm {
                        currentHostIp: natView.currentHostIp
                        onDataChanged: natView.refreshViewPush()
                    }
                }
            }

            Loader {
                id: patLoader
                anchors.fill:  parent
                active: natView.patLoaded
                visible: natView.currentTab === "PAT"
                sourceComponent: Component {
                    NatPatForm {
                        currentHostIp: natView.currentHostIp
                        onDataChanged: natView.refreshViewPush()
                    }
                }
            }

            Loader {
                id: interfacesLoader
                anchors.fill:  parent
                active: natView.interfacesLoaded
                visible: natView.currentTab === "Interfaces"
                sourceComponent: Component {
                    NatInterfaceForm {
                        currentHostIp: natView.currentHostIp
                        onDataChanged: natView.refreshViewPush()
                    }
                }
            }

            Loader {
                id: aclLoader
                anchors.fill:  parent
                active: natView.aclLoaded
                visible: natView.currentTab === "ACL"
                sourceComponent: Component {
                    NatAclForm {
                        currentHostIp: natView.currentHostIp
                        onDataChanged: natView.refreshViewPush()
                    }
                }
            }

            Loader {
                id: routeMapLoader
                anchors.fill:  parent
                active: natView.routeMapLoaded
                visible: natView.currentTab === "Route Map"
                sourceComponent: Component {
                    NatRouteMapForm {
                        currentHostIp: natView.currentHostIp
                        onDataChanged: natView.refreshViewPush()
                    }
                }
            }
        }
    }

    onCurrentHostIpChanged: refreshViewPush()
}
