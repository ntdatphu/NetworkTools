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
                RoutingView {
                    anchors.fill: parent
                    visible: contentArea.activeFeatureName === "Routing"
                    currentHostIp: contentArea.currentHostIp
                }

                // ── DHCP ─────────────────────────────────────────────────
                DhcpView {
                    anchors.fill: parent
                    visible: contentArea.activeFeatureName === "DHCP"
                    currentHostIp: contentArea.currentHostIp
                }

                // ── ACL ──────────────────────────────────────────────────
                AclView {
                    anchors.fill: parent
                    visible:      contentArea.activeFeatureName === "ACL"
                    currentHostIp: contentArea.currentHostIp
                }

                // ── NAT ──────────────────────────────────────────────────
                NatView {
                    anchors.fill: parent
                    visible:      contentArea.activeFeatureName === "NAT"
                    currentHostIp: contentArea.currentHostIp
                }

                InterfaceView {
                    anchors.fill: parent
                    visible: contentArea.activeFeatureName === ""
                             && contentArea.activeMainFeatureName === "Interface"
                    currentHostIp: contentArea.currentHostIp
                }

                InformationView {
                    anchors.fill: parent
                    visible: contentArea.activeFeatureName === ""
                             && contentArea.activeMainFeatureName === "Information"
                    currentHostIp: contentArea.currentHostIp
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
        SettingsView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            activeSettingKey: contentArea.activeSettingKey
        }

        // ── INDEX 2: DATABASE BROWSER ──
        DatabaseBrowserView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            activeTable: contentArea.activeDatabaseTable
        }
    }
}
