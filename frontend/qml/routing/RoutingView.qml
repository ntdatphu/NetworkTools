pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import NetworkUI

Rectangle {
    id: routingView


    color: Theme.contentBackground
    property string currentHostIp: ""

    // Tab đang active, mặc định là "Info"
    property string currentTab: "Info"

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
            // Placeholder — sẽ thay bằng InfoForm.qml sau
            Item {
                anchors.fill: parent
                visible:      routingView.currentTab === "Info"

                Text {
                    anchors.centerIn: parent
                    text:             "Info — Not yet implemented"
                    color:            Theme.textDisabled
                    font.pixelSize:   Theme.fontSizeNormal
                    font.family:      Theme.fontFamily
                }
            }

            // ── Static ────────────────────────────────────────────
            StaticRoutingForm {
                anchors.fill: parent
                visible:      routingView.currentTab === "Static"
                currentHostIp: routingView.currentHostIp
            }

            // ── OSPF ──────────────────────────────────────────────
            OspfRoutingForm {
                anchors.fill: parent
                visible:      routingView.currentTab === "OSPF"
                currentHostIp: routingView.currentHostIp
            }

            // ── EIGRP ─────────────────────────────────────────────
            EigrpRoutingForm {
                anchors.fill: parent
                visible:      routingView.currentTab === "EIGRP"
                currentHostIp: routingView.currentHostIp
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