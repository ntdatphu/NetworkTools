pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import NetworkUI

Rectangle {
    id: featureBar
    color: Theme.featureBarBackground

    property var mainFeatures: [
        { icon: "qrc:/qt/qml/NetworkUI/resources/featurebar/info.svg",      tooltip: "Information" },
        { icon: "qrc:/qt/qml/NetworkUI/resources/featurebar/terminal.svg",  tooltip: "CLI"         },
        { icon: "qrc:/qt/qml/NetworkUI/resources/featurebar/interface.svg", tooltip: "Interface"   }
    ]

    property var textFeatures: [
        { id: "routing", label: "Routing" },
        { id: "vlan", label: "VLAN" },
        { id: "dhcp", label: "DHCP" },
        { id: "acl", label: "ACL" },
        { id: "bgp", label: "BGP" },
        { id: "nat", label: "NAT" },
        { id: "stp", label: "STP" },
        { id: "qos", label: "QoS" },
        { id: "snmp", label: "SNMP" },
        { id: "ntp", label: "NTP" },
        { id: "aaa", label: "AAA" },
        { id: "mpls", label: "MPLS" },
        { id: "vpn", label: "VPN" },
        { id: "firewall", label: "Firewall" },
        { id: "monitor", label: "Monitor" }
    ]

    property int activeMain: 0
    property int activeText: -1

    signal userChangedFeature(int mIdx, int tIdx)

    Row {
        anchors.fill: parent

        Row {
            id: mainFeaturesRow
            height: parent.height

            Repeater {
                model: featureBar.mainFeatures
                delegate: MainFeatureItem {
                    id: mainItemDelegate
                    required property int index
                    required property var modelData
                    iconSource: modelData.icon
                    tooltipText: modelData.tooltip
                    isActive: featureBar.activeMain === index

                    onClicked: {
                        if (modelData.tooltip === "CLI") {
                            mainItemDelegate.triggerFlash()
                        } else {
                            featureBar.userChangedFeature(index, -1)
                        }
                    }
                }
            }
        }

        Rectangle {
            width: Theme.borderWidth; height: parent.height - 12
            anchors.verticalCenter: parent.verticalCenter; color: Theme.borderColor
        }

        Item {
            id: textFeaturesArea
            width: parent.width - mainFeaturesRow.width - 1 - moreBtn.width
            height: parent.height

            ListView {
                id: textFeatureList
                anchors.fill: parent; orientation: ListView.Horizontal; clip: true
                model: featureBar.textFeatures

                Behavior on contentX { NumberAnimation { duration: Theme.animationDurationMedium; easing.type: Easing.OutQuad } }

                delegate: TextFeatureItem {
                    required property int index
                    required property var modelData
                    height: textFeatureList.height; label: modelData.label
                    isActive: featureBar.activeText === index
                    onClicked: {
                        featureBar.activeText = index
                        featureBar.activeMain = -1
                        featureBar.userChangedFeature(-1, index)
                    }
                }
                ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AlwaysOff }
            }
        }

        Rectangle {
            id: moreBtn
            width: 28; height: parent.height
            color: moreBtnHover.hovered ? Theme.sideBarItemHover : "transparent"
            Text { anchors.centerIn: parent; text: "›"; font.pixelSize: 18; color: Theme.textSecondary }
            HoverHandler { id: moreBtnHover }
            TapHandler {
                onTapped: {
                    if (dropdown.visible) {
                        dropdown.hide()
                    } else {
                        const hidden = []
                        for (let i = 0; i < featureBar.textFeatures.length; i++) {
                            const itemX = textFeatureList.contentItem.children[i]
                            if (itemX && (itemX.x < textFeatureList.contentX ||
                                itemX.x + itemX.width > textFeatureList.contentX + textFeatureList.width)) {
                                hidden.push(featureBar.textFeatures[i])
                            }
                        }
                        dropdown.hiddenFeatures = hidden.length > 0 ? hidden : featureBar.textFeatures
                        dropdown.visible = true
                    }
                }
            }
        }
    }

    FeatureDropdown {
        id: dropdown
        anchors.right: parent.right; anchors.top: parent.bottom

        onFeatureSelected: function(idx) {
            const actualIdx = featureBar.textFeatures.indexOf(dropdown.hiddenFeatures[idx])
            featureBar.activeText = actualIdx
            featureBar.activeMain = -1
            featureBar.userChangedFeature(-1, actualIdx)
        }
    }

    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: Theme.borderWidth; color: Theme.borderColor }
}