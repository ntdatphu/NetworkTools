pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import NetworkUI

Rectangle {
    id: contentArea
    color: Theme.contentBackground

    property int    tabCount:          0
    property string currentHostIp:     ""
    property int    activeTextFeature: -1
    property string appMode:           "devices"

    property bool   hostConfigEnabled: true

    readonly property var textFeatureNames: [
        "Routing", "VLAN", "DHCP", "ACL", "BGP", "NAT",
        "STP", "QoS", "SNMP", "NTP", "AAA", "MPLS",
        "VPN", "Firewall", "Monitor"
    ]

    property string activeFeatureName: activeTextFeature >= 0
                                       ? textFeatureNames[activeTextFeature]
                                       : ""

    // ── HÀM ĐỊNH TUYẾN: Chuyển đổi tên chế độ sang Index của StackLayout ──
    // function getModeIndex() {
    //     if (appMode === "logs") return 1
    //     if (appMode === "settings") return 2
    //     return 0 // Mặc định luôn là 0 (Devices)
    // }

    // ── Áp dụng StackLayout để quản lý các màn hình chuyên nghiệp hơn ──
    StackLayout {
        anchors.fill: parent
        // currentIndex: contentArea.getModeIndex()
        currentIndex: contentArea.appMode === "logs" ? 1 : (contentArea.appMode === "settings" ? 2 : 0)

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

                // ── Các feature chưa implement ───────────────────────────
                Text {
                    anchors.centerIn: parent
                    visible: contentArea.activeFeatureName !== ""
                             && contentArea.activeFeatureName !== "Routing"
                             && contentArea.activeFeatureName !== "DHCP"
                             && contentArea.activeFeatureName !== "ACL"
                    text: contentArea.activeFeatureName + " — Not yet implemented"
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeNormal
                }

                Text {
                    anchors.centerIn: parent
                    visible: contentArea.activeFeatureName === ""
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

        // ── INDEX 1: LOGS & ALERTS ──
        LogsAlertsView {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        // ── INDEX 2: SETTINGS ──
        SettingsView {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
}