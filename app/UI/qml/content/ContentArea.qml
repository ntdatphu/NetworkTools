pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

Rectangle {
    id: contentArea
    color: Theme.contentBackground

    property int    tabCount:          0
    property string currentHostIp:     ""
    property int    activeMainFeature: -1
    property int    activeTextFeature: -1
    property string appMode:           "devices"
    property string activeSettingKey:  "theme"
    property string activeDatabaseTable: ""

    property bool   hostConfigEnabled: true

    // UI-P1-01: Load each expensive screen on first visit, then keep it alive.
    // Caching preserves unsaved form state while avoiding eager startup work.
    property bool routingViewLoaded: false
    property bool dhcpViewLoaded: false
    property bool aclViewLoaded: false
    property bool natViewLoaded: false
    property bool interfaceViewLoaded: false
    property bool informationViewLoaded: false
    property bool settingsViewLoaded: false
    property bool databaseViewLoaded: false

    readonly property var textFeatureNames: [
        "Routing", "VLAN", "DHCP", "ACL","VRF", "NAT",
        "STP", "QoS", "SNMP", "NTP", "AAA", "MPLS",
        "VPN", "Firewall", "Monitor"
    ]
    readonly property var mainFeatureNames: ["Information", "CLI", "Interface"]

    property string activeFeatureName: activeTextFeature >= 0
                                       ? textFeatureNames[activeTextFeature]
                                       : ""
    property string activeMainFeatureName: activeMainFeature >= 0
                                           ? mainFeatureNames[activeMainFeature]
                                           : ""

    function ensureActiveViewLoaded() {
        switch (activeFeatureName) {
        case "Routing": routingViewLoaded = true; break
        case "DHCP": dhcpViewLoaded = true; break
        case "ACL": aclViewLoaded = true; break
        case "NAT": natViewLoaded = true; break
        }

        if (activeMainFeatureName === "Interface")
            interfaceViewLoaded = true
        else if (activeMainFeatureName === "Information")
            informationViewLoaded = true

        if (appMode === "settings")
            settingsViewLoaded = true
        else if (appMode === "database")
            databaseViewLoaded = true
    }

    onActiveFeatureNameChanged: ensureActiveViewLoaded()
    onActiveMainFeatureNameChanged: ensureActiveViewLoaded()
    onAppModeChanged: ensureActiveViewLoaded()
    Component.onCompleted: ensureActiveViewLoaded()

    function displayFeatureName(name) {
        switch (name) {
        case "Routing": return "Routing"
        case "VLAN": return "VLAN"
        case "DHCP": return "DHCP"
        case "ACL": return "ACL"
        case "VRF": return "VRF"
        case "NAT": return "NAT"
        case "STP": return "STP"
        case "QoS": return "QoS"
        case "SNMP": return "SNMP"
        case "NTP": return "NTP"
        case "AAA": return "AAA"
        case "MPLS": return "MPLS"
        case "VPN": return "VPN"
        case "Firewall": return "Firewall"
        case "Monitor": return "Monitor"
        default: return name
        }
    }

    function displayMainFeatureName(name) {
        switch (name) {
        case "Information": return "Information"
        case "CLI": return "CLI"
        case "Interface": return "Interface"
        default: return name
        }
    }

    // ── Áp dụng StackLayout để quản lý các màn hình chuyên nghiệp hơn ──
    StackLayout {
        anchors.fill: parent
        currentIndex: {
            if (contentArea.appMode === "settings") return 1
            if (contentArea.appMode === "database") return 2
            return 0
        }

        // ── INDEX 0: WORKSPACE (Quản lý thiết bị) ──
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Màn hình chào mừng
            WelcomeScreen {
                anchors.fill: parent
                visible: contentArea.tabCount === 0
            }

            // Khu vực làm việc
            Item {
                anchors.fill: parent
                visible: contentArea.tabCount > 0
                enabled: contentArea.hostConfigEnabled
                opacity: contentArea.hostConfigEnabled ? 1.0 : 0.4

                Behavior on opacity {
                    NumberAnimation { duration: Theme.animationDurationMedium }
                }

                // ── Routing ──────────────────────────────────────────────
                Loader {
                    id: routingLoader
                    anchors.fill: parent
                    active: contentArea.routingViewLoaded
                    visible: contentArea.activeFeatureName === "Routing"
                    sourceComponent: Component {
                        RoutingView { currentHostIp: contentArea.currentHostIp }
                    }
                }

                // ── DHCP ─────────────────────────────────────────────────
                Loader {
                    anchors.fill: parent
                    active: contentArea.dhcpViewLoaded
                    visible: contentArea.activeFeatureName === "DHCP"
                    sourceComponent: Component {
                        DhcpView { currentHostIp: contentArea.currentHostIp }
                    }
                }

                // ── ACL ──────────────────────────────────────────────────
                Loader {
                    anchors.fill: parent
                    active: contentArea.aclViewLoaded
                    visible: contentArea.activeFeatureName === "ACL"
                    sourceComponent: Component {
                        AclView { currentHostIp: contentArea.currentHostIp }
                    }
                }

                // ── NAT ──────────────────────────────────────────────────
                Loader {
                    anchors.fill: parent
                    active: contentArea.natViewLoaded
                    visible: contentArea.activeFeatureName === "NAT"
                    sourceComponent: Component {
                        NatView { currentHostIp: contentArea.currentHostIp }
                    }
                }

                Loader {
                    anchors.fill: parent
                    active: contentArea.interfaceViewLoaded
                    visible: contentArea.activeFeatureName === ""
                             && contentArea.activeMainFeatureName === "Interface"
                    sourceComponent: Component {
                        InterfaceView { currentHostIp: contentArea.currentHostIp }
                    }
                }

                Loader {
                    anchors.fill: parent
                    active: contentArea.informationViewLoaded
                    visible: contentArea.activeFeatureName === ""
                             && contentArea.activeMainFeatureName === "Information"
                    sourceComponent: Component {
                        InformationView { currentHostIp: contentArea.currentHostIp }
                    }
                }

                // ── Các feature chưa implement ───────────────────────────
                Text {
                    anchors.centerIn: parent
                    visible: contentArea.activeFeatureName !== ""
                             && contentArea.activeFeatureName !== "Routing"
                             && contentArea.activeFeatureName !== "DHCP"
                             && contentArea.activeFeatureName !== "ACL"
                             && contentArea.activeFeatureName !== "NAT"
                    text: "%1 — Not yet implemented".arg(contentArea.displayFeatureName(contentArea.activeFeatureName))
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeNormal
                }

                Text {
                    anchors.centerIn: parent
                    visible: contentArea.activeFeatureName === ""
                             && contentArea.activeMainFeatureName !== ""
                             && contentArea.activeMainFeatureName !== "Information"
                             && contentArea.activeMainFeatureName !== "Interface"
                    text: "%1 - Not yet implemented".arg(contentArea.displayMainFeatureName(contentArea.activeMainFeatureName))
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeNormal
                }

                Text {
                    anchors.centerIn: parent
                    visible: contentArea.activeFeatureName === ""
                             && contentArea.activeMainFeatureName === ""
                    text: "Choose a feature from the feature bar to get started"
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeNormal
                }
            }

            // Lớp phủ thông báo khi thiết bị đang ở trạng thái Waiting
            Rectangle {
                anchors.fill: parent
                visible: contentArea.tabCount > 0 && !contentArea.hostConfigEnabled
                color: "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "Device is waiting. Configuration is disabled until it connects."
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeNormal
                }
            }
        }

        // ── INDEX 1: SETTINGS ──
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Loader {
                anchors.fill: parent
                active: contentArea.settingsViewLoaded
                sourceComponent: Component {
                    SettingsView { activeSettingKey: contentArea.activeSettingKey }
                }
            }
        }

        // ── INDEX 2: DATABASE BROWSER ──
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Loader {
                anchors.fill: parent
                active: contentArea.databaseViewLoaded
                sourceComponent: Component {
                    DatabaseBrowserView { activeTable: contentArea.activeDatabaseTable }
                }
            }
        }
    }
}
