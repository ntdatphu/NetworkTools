pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import UI

Rectangle {
    id: dhcpView
    color: Theme.contentBackground

    property string currentHostIp: ""
    property string currentTab:    "Pool"

    ColumnLayout {
        anchors.fill: parent
        spacing:      0

        // 1. Thanh tab con
        DhcpSubBar {
            Layout.fillWidth: true
            activeTab:        dhcpView.currentTab
            onTabClicked:     (tabName) => { dhcpView.currentTab = tabName }
        }

        // 2. Vùng nội dung
        Item {
            Layout.fillWidth:  true
            Layout.fillHeight: true

            // ── Info ──────────────────────────────────────────────
            Item {
                anchors.fill: parent
                visible:      dhcpView.currentTab === "Info"

                Text {
                    anchors.centerIn: parent
                    text:             "Info — Not yet implemented"
                    color:            Theme.textDisabled
                    font.pixelSize:   Theme.fontSizeNormal
                    font.family:      Theme.fontFamily
                }
            }

            // ── Pool ──────────────────────────────────────────────
            DhcpPoolForm {
                anchors.fill:  parent
                visible:       dhcpView.currentTab === "Pool"
                currentHostIp: dhcpView.currentHostIp
            }

            // ── Excluded Address ──────────────────────────────────
            DhcpExcludedForm {
                anchors.fill:  parent
                visible:       dhcpView.currentTab === "Excluded"
                currentHostIp: dhcpView.currentHostIp
            }

            // -- Helper Address --------------------------------------------
            DhcpHelperForm {
                anchors.fill: parent
                visible: dhcpView.currentTab === "Helper"
                currentHostIp: dhcpView.currentHostIp
            }
        }
    }
}
