pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import NetworkTools

Rectangle {
    id: natView
    color: Theme.contentBackground

    property string currentHostIp: ""
    property string currentTab:    "Info"

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

            // ── Info ──
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

            // ── Static NAT ──
            NatStaticForm {
                anchors.fill:  parent
                visible:       natView.currentTab === "Static"
                currentHostIp: natView.currentHostIp
            }

            // ── Dynamic NAT ──
            NatDynamicForm {
                anchors.fill:  parent
                visible:       natView.currentTab === "Dynamic"
                currentHostIp: natView.currentHostIp
            }

            // ── PAT ──
            NatPatForm {
                anchors.fill:  parent
                visible:       natView.currentTab === "PAT"
                currentHostIp: natView.currentHostIp
            }

            // ── Interfaces ──
            NatInterfaceForm {
                anchors.fill:  parent
                visible:       natView.currentTab === "Interfaces"
                currentHostIp: natView.currentHostIp
            }
        }
    }
}