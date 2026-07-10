pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import UI

Rectangle {
    id: routingView


    color: Theme.contentBackground
    property string currentHostIp: ""

    // Tab đang active, mặc định là "Info"
    property string currentTab: "Info"
    property bool infoLoaded: true
    property bool staticLoaded: false
    property bool ospfLoaded: false
    property bool eigrpLoaded: false

    function ensureCurrentTabLoaded() {
        switch (currentTab) {
        case "Info": infoLoaded = true; break
        case "Static": staticLoaded = true; break
        case "OSPF": ospfLoaded = true; break
        case "EIGRP": eigrpLoaded = true; break
        }
    }

    onCurrentTabChanged: ensureCurrentTabLoaded()

    // ── Bố cục dọc: SubBar trên, Form dưới ──────────────────────────
    ColumnLayout {
        anchors.fill: parent
        spacing:      0

        // 1. Thanh tab con
        RoutingSubBar {
            Layout.fillWidth: true
            activeTab:        routingView.currentTab
            onTabClicked:     (tabName) => { routingView.currentTab = tabName }
        }

        // 2. Vùng nội dung — hoán đổi theo tab đang chọn
        Item {
            Layout.fillWidth:  true
            Layout.fillHeight: true

            // ── Info ──────────────────────────────────────────────
            Loader {
                id: infoLoader
                anchors.fill: parent
                visible:      routingView.currentTab === "Info"
                active:       routingView.infoLoaded
                source:       "info_routing.qml"
                onLoaded:     item.currentHostIp = routingView.currentHostIp
            }

            // ── Static ────────────────────────────────────────────
            Loader {
                anchors.fill: parent
                active: routingView.staticLoaded
                visible: routingView.currentTab === "Static"
                sourceComponent: Component {
                    StaticRoutingForm { currentHostIp: routingView.currentHostIp }
                }
            }

            // ── OSPF ──────────────────────────────────────────────
            Loader {
                anchors.fill: parent
                active: routingView.ospfLoaded
                visible: routingView.currentTab === "OSPF"
                sourceComponent: Component {
                    OspfRoutingForm { currentHostIp: routingView.currentHostIp }
                }
            }

            // ── EIGRP ─────────────────────────────────────────────
            Loader {
                anchors.fill: parent
                active: routingView.eigrpLoaded
                visible: routingView.currentTab === "EIGRP"
                sourceComponent: Component {
                    EigrpRoutingForm { currentHostIp: routingView.currentHostIp }
                }
            }

            // ── BGP ───────────────────────────────────────────────
            Item {
                anchors.fill: parent
                visible:      routingView.currentTab === "BGP"

                Text {
                    anchors.centerIn: parent
                    text:             "BGP — Not yet implemented"
                    color:            Theme.textDisabled
                    font.pixelSize:   Theme.fontSizeNormal
                    font.family:      Theme.fontFamily
                }
            }
        }
    }

    onCurrentHostIpChanged: {
        if (infoLoader.item)
            infoLoader.item.currentHostIp = routingView.currentHostIp
    }
}
