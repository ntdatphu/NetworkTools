pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

Item {
    id: root
    required property string host
    required property string deviceRole
    property string feature: "interfaces"
    property string subFeature: "switchPorts"
    property var navigation: []
    readonly property bool isSw3: String(deviceRole).toLowerCase() === "sw3"

    function reloadNavigation() {
        navigation = dbManager.getSwitchNavigation(deviceRole)
        normalizeSubFeature()
    }
    function subFeaturesForFeature() {
        for (let i = 0; i < navigation.length; i++) {
            if (navigation[i].id === feature)
                return navigation[i].subfeatures || []
        }
        return []
    }
    function label(value) {
        const labels = {
            switchPorts: "Switch Ports",
            routedPorts: "Routed Ports",
            svi: "SVI",
            vlan: "VLAN",
            portSecurity: "Port Security",
            stormControl: "Storm Control",
            acl: "ACL",
            portCounters: "Port Counters",
            macTable: "MAC Table",
            dhcpServer: "DHCP Server",
            dhcpRelay: "DHCP Relay"
        }
        return labels[value] || value
    }
    function normalizeSubFeature() {
        const options = subFeaturesForFeature()
        if (options.length > 0 && options.indexOf(subFeature) === -1)
            subFeature = options[0]
    }

    onFeatureChanged: normalizeSubFeature()
    onDeviceRoleChanged: reloadNavigation()
    Component.onCompleted: reloadNavigation()

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.subBarHeight
            color: Theme.featureBarBackground
            Row {
                anchors.fill: parent
                Repeater {
                    model: root.subFeaturesForFeature()
                    delegate: StandardButton {
                        required property string modelData
                        height: parent.height
                        text: root.label(modelData)
                        type: root.subFeature === modelData ? "Secondary" : "Ghost"
                        onClicked: root.subFeature = modelData
                    }
                }
            }
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: Theme.borderWidth
                color: Theme.borderColor
            }
        }

        Loader {
            Layout.fillWidth: true
            Layout.fillHeight: true
            sourceComponent: {
                if (root.feature === "interfaces"
                        && ["switchPorts", "routedPorts"].indexOf(root.subFeature) !== -1)
                    return switchPortsComponent
                if (root.feature === "interfaces" && root.subFeature === "svi")
                    return sviComponent
                if (root.feature === "switching" && root.subFeature === "vlan")
                    return vlanComponent
                if (root.feature === "security"
                        && ["portSecurity", "stormControl"].indexOf(root.subFeature) !== -1)
                    return switchPortsComponent
                if (root.feature === "monitoring")
                    return monitoringComponent
                if (root.feature === "services")
                    return dhcpComponent
                if (root.feature === "security" && root.subFeature === "acl" && root.isSw3)
                    return aclComponent
                return emptyComponent
            }
        }
    }

    Component {
        id: switchPortsComponent
        SwitchPortsPage {
            host: root.host
            allowRouted: root.isSw3
            routedOnly: root.subFeature === "routedPorts"
        }
    }
    Component { id: sviComponent; SviPage { host: root.host } }
    Component { id: vlanComponent; VlanPage { host: root.host } }
    Component {
        id: monitoringComponent
        SwitchMonitoringPage { host: root.host; viewName: root.subFeature }
    }
    Component {
        id: dhcpComponent
        DhcpView {
            currentHostIp: root.host
            currentTab: root.subFeature === "dhcpRelay" ? "Helper" : "Pool"
        }
    }
    Component { id: aclComponent; AclView { currentHostIp: root.host } }
    Component {
        id: emptyComponent
        Item {
            Text {
                anchors.centerIn: parent
                text: "No compatible switch page is available"
                color: Theme.textSecondary
                font.family: Theme.fontFamily
            }
        }
    }
}
