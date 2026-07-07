pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import UI

Rectangle {
    id: featureBar
    color: Theme.featureBarBackground

    property var mainFeatures: [
        { icon: AppAssets.resource("resources/featurebar/info.svg"),      tooltip: "Information" },
        { icon: AppAssets.resource("resources/featurebar/terminal.svg"),  tooltip: "CLI"         },
        { icon: AppAssets.resource("resources/featurebar/interface.svg"), tooltip: "Interface"   }
    ]

    property string deviceType: ""

    readonly property var allTextFeatures: [
        { id: "routing", label: "Routing", globalIndex: 0, implemented: true },
        { id: "vlan", label: "VLAN", globalIndex: 1, implemented: false },
        { id: "dhcp", label: "DHCP", globalIndex: 2, implemented: true },
        { id: "acl", label: "ACL", globalIndex: 3, implemented: true },
        { id: "bgp", label: "BGP", globalIndex: 4, implemented: false },
        { id: "nat", label: "NAT", globalIndex: 5, implemented: true },
        { id: "stp", label: "STP", globalIndex: 6, implemented: false },
        { id: "qos", label: "QoS", globalIndex: 7, implemented: false },
        { id: "snmp", label: "SNMP", globalIndex: 8, implemented: false },
        { id: "ntp", label: "NTP", globalIndex: 9, implemented: false },
        { id: "aaa", label: "AAA", globalIndex: 10, implemented: false },
        { id: "mpls", label: "MPLS", globalIndex: 11, implemented: false },
        { id: "vpn", label: "VPN", globalIndex: 12, implemented: false },
        { id: "firewall", label: "Firewall", globalIndex: 13, implemented: false },
        { id: "monitor", label: "Monitor", globalIndex: 14, implemented: false }
    ]

    property var textFeatures: featuresForDeviceType(deviceType)
    property int activeMain: 0
    property int activeText: -1

    signal userChangedFeature(int mIdx, int tIdx)
    signal cliOpenRequested()

    function normalizedDeviceType(value) {
        const text = String(value || "").trim().toLowerCase()
        if (text === "router" || text.indexOf("router") !== -1)
            return "router"
        if (text === "sw2" || text === "sw3" || text.indexOf("switch") !== -1)
            return "switch"
        return "unknown"
    }

    function featuresForDeviceType(value) {
        const type = normalizedDeviceType(value)
        if (type !== "router")
            return allTextFeatures

        const allowed = ["routing", "dhcp", "acl", "nat"]
        const result = []

        for (let i = 0; i < allTextFeatures.length; i++) {
            if (allowed.indexOf(allTextFeatures[i].id) !== -1)
                result.push(allTextFeatures[i])
        }
        return result
    }

    function isTextFeatureAllowed(globalIndex) {
        for (let i = 0; i < textFeatures.length; i++) {
            if (textFeatures[i].globalIndex === globalIndex)
                return true
        }
        return false
    }

    onTextFeaturesChanged: {
        if (activeText >= 0 && !isTextFeatureAllowed(activeText)) {
            activeMain = 0
            activeText = -1
            userChangedFeature(0, -1)
        }
    }

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
                            featureBar.cliOpenRequested()
                        } else {
                            featureBar.activeMain = index
                            featureBar.activeText = -1
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
                    selectable: modelData.implemented
                    isActive: featureBar.activeText === modelData.globalIndex
                    onClicked: {
                        featureBar.activeText = modelData.globalIndex
                        featureBar.activeMain = -1
                        featureBar.userChangedFeature(-1, modelData.globalIndex)
                    }
                }
                ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AlwaysOff }
            }
        }

        Rectangle {
            id: moreBtn
            visible: featureBar.textFeatures.length > 0
            width: visible ? 28 : 0
            height: parent.height
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

        onFeatureSelected: function(globalIndex) {
            featureBar.activeText = globalIndex
            featureBar.activeMain = -1
            featureBar.userChangedFeature(-1, globalIndex)
        }
    }

    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: Theme.borderWidth; color: Theme.borderColor }
}
