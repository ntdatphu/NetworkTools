pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import UI

SplitFormPane {
    id: editor

    property string currentHostIp: ""
    property string selectedFamily: "GigabitEthernet"
    property string selectedKind: "L3"
    property int selectedIfaceId: -1
    property var interfaceModel: null

    readonly property var portFamilies: [
        "GigabitEthernet", "FastEthernet", "Serial", "Tunnel", "Loopback"
    ]
    readonly property var quickPorts: ({
        "GigabitEthernet": ["GigabitEthernet0/0", "GigabitEthernet0/1", "GigabitEthernet0/2", "GigabitEthernet0/3"],
        "FastEthernet": ["FastEthernet0/0", "FastEthernet0/1", "FastEthernet1/0", "FastEthernet1/1"],
        "Serial": ["Serial0/0/0", "Serial0/0/1", "Serial0/1/0", "Serial0/1/1"],
        "Tunnel": ["Tunnel0", "Tunnel1", "Tunnel2"],
        "Loopback": ["Loopback0", "Loopback1", "Loopback2"]
    })

    signal saveRequested(var payload, string interfaceName)
    signal interfaceRequested(string interfaceName)

    spacing: Theme.spacing16

    function kindForFamily(family) {
        if (family === "Tunnel")
            return "Tunnel"
        if (family === "Serial")
            return "WAN"
        return "L3"
    }

    function shortName(name) {
        return String(name)
            .replace("GigabitEthernet", "GE")
            .replace("FastEthernet", "FE")
            .replace("Serial", "S")
            .replace("Tunnel", "T")
            .replace("Loopback", "L")
    }

    function isSaved(name) {
        if (!interfaceModel)
            return false
        for (let i = 0; i < interfaceModel.count; i++) {
            if (interfaceModel.get(i).interface_name === name)
                return true
        }
        return false
    }

    function clearForm() {
        selectedIfaceId = -1
        ifaceField.text = ""
        ipField.text = ""
        maskField.text = ""
        descriptionField.text = ""
        shutdownCheck.checked = false
        secondaryIpField.text = ""
        secondaryMaskField.text = ""
        mtuField.text = "1500"
        bandwidthField.text = ""
        delayField.text = ""
        speedCombo.currentIndex = 0
        duplexCombo.currentIndex = 0
        negotiationCheck.checked = true
        proxyArpCheck.checked = true
        unreachablesCheck.checked = true
        directedBroadcastCheck.checked = false
        tunnelModeCombo.currentIndex = 0
        tunnelSrcField.text = ""
        tunnelDstField.text = ""
        tunnelKeyField.text = ""
        keepaliveSecField.text = ""
        keepaliveRetryField.text = ""
        ipsecProfileField.text = ""
        encapCombo.currentIndex = 0
        pppoePoolField.text = ""
        pppAuthCombo.currentIndex = 0
        pppUsernameField.text = ""
        pppPasswordField.text = ""
        clockRateField.text = ""
        lmiCombo.currentIndex = 0
    }

    function applyRow(row) {
        clearForm()
        selectedIfaceId = Number(row.iface_id || -1)
        ifaceField.text = row.interface_name || ""
        ipField.text = row.ip_address || ""
        maskField.text = row.subnet_mask || ""
        descriptionField.text = row.description || ""
        shutdownCheck.checked = Number(row.shutdown || 0) === 1
        selectedKind = row.interface_kind || "L3"
        secondaryIpField.text = row.secondary_ip || ""
        secondaryMaskField.text = row.secondary_mask || ""
        mtuField.text = row.mtu ? String(row.mtu) : "1500"
        bandwidthField.text = row.bandwidth ? String(row.bandwidth) : ""
        delayField.text = row.delay ? String(row.delay) : ""
        speedCombo.currentIndex = Math.max(0, ["auto", "10", "100", "1000", "10000"].indexOf(row.speed || "auto"))
        duplexCombo.currentIndex = Math.max(0, ["auto", "full", "half"].indexOf(row.duplex || "auto"))
        negotiationCheck.checked = Number(row.negotiation === undefined ? 1 : row.negotiation) === 1
        proxyArpCheck.checked = Number(row.proxy_arp === undefined ? 1 : row.proxy_arp) === 1
        unreachablesCheck.checked = Number(row.unreachables === undefined ? 1 : row.unreachables) === 1
        directedBroadcastCheck.checked = Number(row.directed_broadcast || 0) === 1
        tunnelModeCombo.currentIndex = Math.max(0, ["gre", "ipip", "ipsec", "gre-ipsec"].indexOf(row.tunnel_mode || "gre"))
        tunnelSrcField.text = row.tunnel_src || ""
        tunnelDstField.text = row.tunnel_dst || ""
        tunnelKeyField.text = row.tunnel_key ? String(row.tunnel_key) : ""
        keepaliveSecField.text = row.keepalive_sec ? String(row.keepalive_sec) : ""
        keepaliveRetryField.text = row.keepalive_retry ? String(row.keepalive_retry) : ""
        ipsecProfileField.text = row.ipsec_profile || ""
        encapCombo.currentIndex = Math.max(0, ["none", "pppoe", "hdlc", "ppp", "frame-relay"].indexOf(row.encap_type || "none"))
        pppoePoolField.text = row.pppoe_dialer_pool ? String(row.pppoe_dialer_pool) : ""
        pppAuthCombo.currentIndex = Math.max(0, ["", "pap", "chap"].indexOf(row.ppp_auth || ""))
        pppUsernameField.text = row.ppp_username || ""
        pppPasswordField.text = row.ppp_password || ""
        clockRateField.text = row.clock_rate ? String(row.clock_rate) : ""
        lmiCombo.currentIndex = Math.max(0, ["", "cisco", "ansi", "q933a"].indexOf(row.lmi_type || ""))
    }

    function beginInterface(name) {
        clearForm()
        ifaceField.text = name
    }

    function payload() {
        return {
            "host": currentHostIp,
            "interface_name": ifaceField.text.trim(),
            "interface_kind": selectedKind,
            "ip_address": ipField.text.trim(),
            "subnet_mask": maskField.text.trim(),
            "description": descriptionField.text.trim(),
            "shutdown": shutdownCheck.checked,
            "secondary_ip": secondaryIpField.text.trim(),
            "secondary_mask": secondaryMaskField.text.trim(),
            "mtu": mtuField.text.trim(),
            "bandwidth": bandwidthField.text.trim(),
            "delay": delayField.text.trim(),
            "speed": speedCombo.currentValue,
            "duplex": duplexCombo.currentValue,
            "negotiation": negotiationCheck.checked,
            "proxy_arp": proxyArpCheck.checked,
            "unreachables": unreachablesCheck.checked,
            "directed_broadcast": directedBroadcastCheck.checked,
            "tunnel_mode": tunnelModeCombo.currentText,
            "tunnel_src": tunnelSrcField.text.trim(),
            "tunnel_dst": tunnelDstField.text.trim(),
            "tunnel_key": tunnelKeyField.text.trim(),
            "keepalive_sec": keepaliveSecField.text.trim(),
            "keepalive_retry": keepaliveRetryField.text.trim(),
            "ipsec_profile": ipsecProfileField.text.trim(),
            "encap_type": encapCombo.currentText,
            "pppoe_dialer_pool": pppoePoolField.text.trim(),
            "ppp_auth": pppAuthCombo.currentText,
            "ppp_username": pppUsernameField.text.trim(),
            "ppp_password": pppPasswordField.text.trim(),
            "clock_rate": clockRateField.text.trim(),
            "lmi_type": lmiCombo.currentText
        }
    }

    SectionTitle {
        Layout.fillWidth: true
        text: editor.selectedIfaceId > 0 ? "Edit router interface" : "New router interface"
    }

    Text {
        Layout.fillWidth: true
        text: "Select a common port or enter the exact IOS interface name, then configure only the section that applies."
        color: Theme.textSecondary
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        wrapMode: Text.WordWrap
    }

    Flow {
        Layout.fillWidth: true
        spacing: Theme.spacing8
        Repeater {
            model: editor.portFamilies
            delegate: StandardButton {
                required property string modelData
                text: modelData
                type: editor.selectedFamily === modelData ? "Primary" : "Secondary"
                onClicked: {
                    editor.selectedFamily = modelData
                    editor.selectedKind = editor.kindForFamily(modelData)
                }
            }
        }
    }

    Flow {
        Layout.fillWidth: true
        spacing: Theme.spacing8
        Repeater {
            model: editor.quickPorts[editor.selectedFamily]
            delegate: Rectangle {
                id: portCard
                required property string modelData
                width: 106
                height: 46
                radius: Theme.radiusSmall
                color: Theme.contentPanelSurface
                border.color: ifaceField.text === modelData ? Theme.accentColor : Theme.contentPanelBorder
                border.width: ifaceField.text === modelData ? 2 : Theme.borderWidth

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacing8
                    spacing: Theme.spacing8
                    Rectangle {
                        width: 8
                        height: 8
                        radius: 4
                        color: editor.isSaved(portCard.modelData)
                               ? Theme.statusConnected : Theme.textDisabled
                    }
                    Text {
                        Layout.fillWidth: true
                        text: editor.shortName(portCard.modelData)
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        font.bold: true
                    }
                }
                HoverHandler { cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    onTapped: {
                        editor.selectedKind = editor.kindForFamily(editor.selectedFamily)
                        editor.interfaceRequested(portCard.modelData)
                    }
                }
            }
        }
    }

    FormSection {
        Layout.fillWidth: true
        title: "Identity and addressing"

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing12
            StandardTextField {
                id: ifaceField
                Layout.fillWidth: true
                labelText: "Interface name"
                placeholderText: "GigabitEthernet0/0"
                onEditingFinished: editor.interfaceRequested(text.trim())
            }
            StandardComboBox {
                Layout.preferredWidth: 132
                labelText: "Profile"
                model: ["L3", "WAN", "Tunnel"]
                valueModel: ["L3", "WAN", "Tunnel"]
                currentIndex: Math.max(0, ["L3", "WAN", "Tunnel"].indexOf(editor.selectedKind))
                onActivated: editor.selectedKind = currentValue
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: Theme.spacing12
            rowSpacing: Theme.spacing12
            StandardNetworkField { id: ipField; Layout.fillWidth: true; inputKind: "ipv4"; labelText: "IPv4 address"; placeholderText: "192.168.1.1" }
            StandardNetworkField { id: maskField; Layout.fillWidth: true; inputKind: "subnet"; labelText: "Subnet mask"; placeholderText: "255.255.255.0 or /24" }
            StandardTextField { id: descriptionField; Layout.fillWidth: true; Layout.columnSpan: 2; labelText: "Description"; placeholderText: "Link purpose or peer" }
        }

        Flow {
            Layout.fillWidth: true
            spacing: Theme.spacing12
            StandardCheckBox { id: shutdownCheck; text: "Administratively down" }
        }
    }

    FormSection {
        Layout.fillWidth: true
        visible: editor.selectedKind === "L3"
        title: "Layer 3 options"

        GridLayout {
            Layout.fillWidth: true
            columns: 3
            columnSpacing: Theme.spacing12
            rowSpacing: Theme.spacing12
            StandardNetworkField { id: secondaryIpField; Layout.fillWidth: true; inputKind: "ipv4"; labelText: "Secondary IP" }
            StandardNetworkField { id: secondaryMaskField; Layout.fillWidth: true; inputKind: "subnet"; labelText: "Secondary mask" }
            StandardTextField { id: mtuField; Layout.fillWidth: true; labelText: "MTU"; text: "1500" }
            StandardTextField { id: bandwidthField; Layout.fillWidth: true; labelText: "Bandwidth" }
            StandardTextField { id: delayField; Layout.fillWidth: true; labelText: "Delay" }
            StandardComboBox { id: speedCombo; Layout.fillWidth: true; labelText: "Speed"; model: ["Auto", "10", "100", "1000", "10000"]; valueModel: ["auto", "10", "100", "1000", "10000"] }
            StandardComboBox { id: duplexCombo; Layout.fillWidth: true; labelText: "Duplex"; model: ["Auto", "Full", "Half"]; valueModel: ["auto", "full", "half"] }
        }

        Flow {
            Layout.fillWidth: true
            spacing: Theme.spacing12
            StandardCheckBox { id: negotiationCheck; text: "Negotiation"; checked: true }
            StandardCheckBox { id: proxyArpCheck; text: "Proxy ARP"; checked: true }
            StandardCheckBox { id: unreachablesCheck; text: "Unreachables"; checked: true }
            StandardCheckBox { id: directedBroadcastCheck; text: "Directed broadcast" }
        }
    }

    FormSection {
        Layout.fillWidth: true
        visible: editor.selectedKind === "Tunnel"
        title: "Tunnel"

        GridLayout {
            Layout.fillWidth: true
            columns: 3
            columnSpacing: Theme.spacing12
            rowSpacing: Theme.spacing12
            StandardComboBox { id: tunnelModeCombo; Layout.fillWidth: true; labelText: "Mode"; model: ["gre", "ipip", "ipsec", "gre-ipsec"] }
            StandardTextField { id: tunnelSrcField; Layout.fillWidth: true; labelText: "Source" }
            StandardTextField { id: tunnelDstField; Layout.fillWidth: true; labelText: "Destination" }
            StandardTextField { id: tunnelKeyField; Layout.fillWidth: true; labelText: "Key" }
            StandardTextField { id: keepaliveSecField; Layout.fillWidth: true; labelText: "Keepalive sec" }
            StandardTextField { id: keepaliveRetryField; Layout.fillWidth: true; labelText: "Retries" }
            StandardTextField { id: ipsecProfileField; Layout.fillWidth: true; Layout.columnSpan: 3; labelText: "IPsec profile" }
        }
    }

    FormSection {
        Layout.fillWidth: true
        visible: editor.selectedKind === "WAN"
        title: "WAN encapsulation"

        GridLayout {
            Layout.fillWidth: true
            columns: 3
            columnSpacing: Theme.spacing12
            rowSpacing: Theme.spacing12
            StandardComboBox { id: encapCombo; Layout.fillWidth: true; labelText: "Encapsulation"; model: ["none", "pppoe", "hdlc", "ppp", "frame-relay"] }
            StandardTextField { id: pppoePoolField; Layout.fillWidth: true; labelText: "PPPoE pool" }
            StandardComboBox { id: pppAuthCombo; Layout.fillWidth: true; labelText: "PPP auth"; model: ["", "pap", "chap"] }
            StandardTextField { id: pppUsernameField; Layout.fillWidth: true; labelText: "PPP username" }
            StandardPasswordField { id: pppPasswordField; Layout.fillWidth: true; labelText: "PPP password" }
            StandardTextField { id: clockRateField; Layout.fillWidth: true; labelText: "Clock rate" }
            StandardComboBox { id: lmiCombo; Layout.fillWidth: true; labelText: "LMI"; model: ["", "cisco", "ansi", "q933a"] }
        }
    }

    Item { Layout.fillHeight: true }

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacing12
        StandardButton {
            Layout.fillWidth: true
            text: editor.selectedIfaceId > 0 ? "Update Interface" : "Save Interface"
            icon.source: AppAssets.actionSave
            type: "Primary"
            enabled: editor.currentHostIp !== "" && ifaceField.text.trim() !== ""
                     && (editor.selectedKind !== "Tunnel"
                         || (tunnelSrcField.text.trim() !== "" && tunnelDstField.text.trim() !== ""))
            onClicked: editor.saveRequested(editor.payload(), ifaceField.text.trim())
        }
        StandardButton {
            Layout.preferredWidth: 110
            text: "Clear"
            type: "Secondary"
            onClicked: editor.clearForm()
        }
    }
}
