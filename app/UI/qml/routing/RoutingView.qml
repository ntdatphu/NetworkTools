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
    property string infoHostIp: ""
    property string staticHostIp: ""
    property string ospfHostIp: ""
    property string eigrpHostIp: ""
    readonly property bool isViewLoading: {
        switch (currentTab) {
        case "Info": return infoLoader.status === Loader.Loading
        case "Static": return staticLoader.status === Loader.Loading
        case "OSPF": return ospfLoader.status === Loader.Loading
        case "EIGRP": return eigrpLoader.status === Loader.Loading
        default: return false
        }
    }

    function ensureCurrentTabLoaded() {
        if (infoLoader.status === Loader.Loading && currentTab !== "Info")
            infoLoaded = false
        if (staticLoader.status === Loader.Loading && currentTab !== "Static")
            staticLoaded = false
        if (ospfLoader.status === Loader.Loading && currentTab !== "OSPF")
            ospfLoaded = false
        if (eigrpLoader.status === Loader.Loading && currentTab !== "EIGRP")
            eigrpLoaded = false

        switch (currentTab) {
        case "Info": infoLoaded = true; break
        case "Static": staticLoaded = true; break
        case "OSPF": ospfLoaded = true; break
        case "EIGRP": eigrpLoaded = true; break
        }
    }

    function syncHostToCurrentTab() {
        switch (currentTab) {
        case "Info": infoHostIp = currentHostIp; break
        case "Static": staticHostIp = currentHostIp; break
        case "OSPF": ospfHostIp = currentHostIp; break
        case "EIGRP": eigrpHostIp = currentHostIp; break
        }
    }

    onCurrentTabChanged: {
        syncHostToCurrentTab()
        ensureCurrentTabLoaded()
    }
    onCurrentHostIpChanged: syncHostToCurrentTab()
    onInfoHostIpChanged: {
        if (infoLoader.item)
            infoLoader.item.currentHostIp = infoHostIp
    }
    Component.onCompleted: syncHostToCurrentTab()

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
                objectName: "routingInfoLoader"
                anchors.fill: parent
                visible:      routingView.currentTab === "Info"
                active:       routingView.infoLoaded
                asynchronous: true
                source:       "info_routing.qml"
                onLoaded:     item.currentHostIp = routingView.infoHostIp
            }

            // ── Static ────────────────────────────────────────────
            Loader {
                id: staticLoader
                objectName: "routingStaticLoader"
                anchors.fill: parent
                active: routingView.staticLoaded
                asynchronous: true
                visible: routingView.currentTab === "Static"
                sourceComponent: Component {
                    StaticRoutingForm { currentHostIp: routingView.staticHostIp }
                }
            }

            // ── OSPF ──────────────────────────────────────────────
            Loader {
                id: ospfLoader
                objectName: "routingOspfLoader"
                anchors.fill: parent
                active: routingView.ospfLoaded
                asynchronous: true
                visible: routingView.currentTab === "OSPF"
                sourceComponent: Component {
                    OspfRoutingForm { currentHostIp: routingView.ospfHostIp }
                }
            }

            // ── EIGRP ─────────────────────────────────────────────
            Loader {
                id: eigrpLoader
                objectName: "routingEigrpLoader"
                anchors.fill: parent
                active: routingView.eigrpLoaded
                asynchronous: true
                visible: routingView.currentTab === "EIGRP"
                sourceComponent: Component {
                    EigrpRoutingForm { currentHostIp: routingView.eigrpHostIp }
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

}
