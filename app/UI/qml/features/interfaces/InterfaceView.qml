pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

Rectangle {
    id: interfaceView
    readonly property bool compactLayout: width < Theme.dataWorkspaceBreakpoint
    color: Theme.contentBackground

    property string currentHostIp: ""
    property string selectedFamily: "GigabitEthernet"
    property string selectedKind: "L3"
    property int selectedIfaceId: -1
    property int selectedListIndex: -1
    property var contextInterfaceRow: ({})
    readonly property bool isViewLoading: false
    readonly property bool textInputActive: {
        const focusItem = Window.window ? Window.window.activeFocusItem : null
        return focusItem instanceof TextInput || focusItem instanceof TextEdit
    }
    readonly property bool collectionShortcutsEnabled: interfaceView.visible
                                                           && !UiState.windowLock
                                                           && !textInputActive

    function reloadData(reason) {
        reloadInterfaces()
        return currentHostIp !== ""
    }

    readonly property var portFamilies: ["GigabitEthernet", "FastEthernet", "Serial", "Tunnel", "Loopback"]
    readonly property var quickPorts: ({
        "GigabitEthernet": ["GigabitEthernet0/0", "GigabitEthernet0/1", "GigabitEthernet0/2", "GigabitEthernet0/3", "GigabitEthernet1/0", "GigabitEthernet1/1"],
        "FastEthernet": ["FastEthernet0/0", "FastEthernet0/1", "FastEthernet1/0", "FastEthernet1/1"],
        "Serial": ["Serial0/0/0", "Serial0/0/1", "Serial0/1/0", "Serial0/1/1"],
        "Tunnel": ["Tunnel0", "Tunnel1", "Tunnel2"],
        "Loopback": ["Loopback0", "Loopback1", "Loopback2"]
    })

    function kindForFamily(family) {
        if (family === "Tunnel") return "Tunnel"
        if (family === "Serial") return "WAN"
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
        for (let i = 0; i < interfaceModel.count; i++) {
            if (interfaceModel.get(i).interface_name === name)
                return true
        }
        return false
    }

    function referenceTables(row) {
        const refs = []
        if (Number(row.has_l3 || 0) === 1) refs.push("router_iface_l3")
        if (Number(row.has_tunnel || 0) === 1) refs.push("router_iface_tunnel")
        if (Number(row.has_wan || 0) === 1) refs.push("router_iface_wan")
        if (Number(row.has_qos || 0) === 1) refs.push("router_iface_qos")
        return refs
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
        enableQosCheck.checked = false
        trustCombo.currentIndex = 0
        policyInField.text = ""
        policyOutField.text = ""
        shapeRateField.text = ""
        policeRateField.text = ""
        policeBurstField.text = ""
    }

    function applyRow(row) {
        clearForm()
        selectedIfaceId = Number(row.iface_id || -1)
        ifaceField.text = row.interface_name || ""
        ipField.text = row.ip_address || ""
        maskField.text = row.subnet_mask || ""
        descriptionField.text = row.description || ""
        shutdownCheck.checked = Number(row.shutdown || 0) === 1
        selectedKind = row.interface_kind || selectedKind
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
        enableQosCheck.checked = Number(row.has_qos || 0) === 1
        trustCombo.currentIndex = Math.max(0, ["none", "cos", "dscp", "ip-precedence"].indexOf(row.trust_mode || "none"))
        policyInField.text = row.policy_in || ""
        policyOutField.text = row.policy_out || ""
        shapeRateField.text = row.shape_rate ? String(row.shape_rate) : ""
        policeRateField.text = row.police_rate ? String(row.police_rate) : ""
        policeBurstField.text = row.police_burst ? String(row.police_burst) : ""
    }

    function loadInterface(name) {
        if (currentHostIp === "" || name === "") return
        const row = dbManager.getRouterInterfaceByName(currentHostIp, name)
        if (row && row.iface_id !== undefined) {
            applyRow(row)
        } else {
            clearForm()
            ifaceField.text = name
        }
    }

    function reloadInterfaces() {
        selectedListIndex = -1
        contextInterfaceRow = ({})
        interfaceModel.clear()
        if (currentHostIp === "") return
        const rows = dbManager.getRouterInterfaces(currentHostIp)
        for (let i = 0; i < rows.length; i++) {
            const row = rows[i]
            for (const key in row) {
                if (row[key] === null || row[key] === undefined) {
                    row[key] = ""
                }
            }
            interfaceModel.append(row)
        }
    }

    function selectInterfaceRow(index, row) {
        selectedListIndex = index
        contextInterfaceRow = row || ({})
    }

    function editSelectedInterface() {
        if (selectedListIndex < 0 || !contextInterfaceRow)
            return
        applyRow(contextInterfaceRow)
    }

    function deleteSelectedInterface() {
        if (selectedListIndex < 0 || !contextInterfaceRow)
            return
        const ifaceId = Number(contextInterfaceRow.iface_id || -1)
        if (ifaceId < 0)
            return
        dbManager.deleteRouterInterface(ifaceId)
        reloadInterfaces()
        if (selectedIfaceId === ifaceId)
            clearForm()
    }

    function openInterfaceContext(index, row, sceneX, sceneY) {
        selectInterfaceRow(index, row)
        interfaceContextMenu.openAt(sceneX, sceneY)
    }

    function openContextForSelectedInterface() {
        if (selectedListIndex < 0)
            return
        const item = interfaceList.itemAtIndex(selectedListIndex)
        if (!item)
            return
        const point = item.mapToItem(
            null,
            Math.min(item.width - Theme.spacing8, 180),
            item.height / 2
        )
        interfaceContextMenu.openAt(point.x, point.y)
    }

    function saveForm() {
        const ok = dbManager.saveRouterInterface({
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
            "lmi_type": lmiCombo.currentText,
            "enable_qos": enableQosCheck.checked,
            "trust_mode": trustCombo.currentText,
            "policy_in": policyInField.text.trim(),
            "policy_out": policyOutField.text.trim(),
            "shape_rate": shapeRateField.text.trim(),
            "police_rate": policeRateField.text.trim(),
            "police_burst": policeBurstField.text.trim()
        })
        if (ok) {
            reloadInterfaces()
            loadInterface(ifaceField.text.trim())
        }
    }

    onCurrentHostIpChanged: {
        clearForm()
        reloadInterfaces()
    }
    Component.onCompleted: reloadInterfaces()

    ListModel { id: interfaceModel }

    InterfaceContextMenu {
        id: interfaceContextMenu
        parent: Window.window ? Window.window.contentItem : interfaceView
        hasTarget: interfaceView.selectedListIndex >= 0
        onEditRequested: interfaceView.editSelectedInterface()
        onDeleteRequested: interfaceView.deleteSelectedInterface()
        onRefreshRequested: interfaceView.reloadInterfaces()
    }

    SplitView {
        objectName: "interfaceResponsiveSplit"
        anchors.fill: parent
        orientation: interfaceView.compactLayout ? Qt.Vertical : Qt.Horizontal
        handle: StandardSplitHandle {}

        SplitFormPane {
            SplitView.fillWidth: true
            SplitView.preferredWidth: interfaceView.compactLayout ? parent.width : 640
            SplitView.minimumWidth: interfaceView.compactLayout ? 0 : 520
            SplitView.minimumHeight: interfaceView.compactLayout ? 300 : 0
            SplitView.preferredHeight: interfaceView.compactLayout ? 420 : parent.height
            spacing: 12

            Text {
                text: "Router / Layer 3 Interface"
                color: Theme.textPrimary
                font.pixelSize: Theme.fontSizeLarge
                font.family: Theme.fontFamily
                font.bold: true
            }

            Text {
                Layout.fillWidth: true
                text: "Choose a port or enter the full interface name. Saved rows are read back from interface_name and the related router_iface_* tables."
                color: Theme.textSecondary
                font.pixelSize: Theme.fontSizeSmall
                font.family: Theme.fontFamily
                wrapMode: Text.WordWrap
            }

            Flow {
                Layout.fillWidth: true
                spacing: 8
                Repeater {
                    model: interfaceView.portFamilies
                    delegate: StandardButton {
                        required property string modelData
                        text: modelData
                        type: interfaceView.selectedFamily === modelData ? "Primary" : "Secondary"
                        onClicked: {
                            interfaceView.selectedFamily = modelData
                            interfaceView.selectedKind = interfaceView.kindForFamily(modelData)
                        }
                    }
                }
            }

            Flow {
                Layout.fillWidth: true
                spacing: 8
                Repeater {
                    model: interfaceView.quickPorts[interfaceView.selectedFamily]
                    delegate: Rectangle {
                        id: quickPort
                        required property string modelData
                        width: 118
                        height: 54
                        radius: Theme.radiusSmall
                        color: Theme.inputBackground
                        border.color: ifaceField.text === modelData ? Theme.accentColor : Theme.inputBorderColor
                        border.width: Theme.borderWidth

                        Column {
                            anchors.centerIn: parent
                            spacing: 5
                            Rectangle {
                                width: 10
                                height: 10
                                radius: 5
                                anchors.horizontalCenter: parent.horizontalCenter
                                color: interfaceView.isSaved(quickPort.modelData) ? Theme.statusConnected : Theme.alertError
                            }
                            Text {
                                text: interfaceView.shortName(quickPort.modelData)
                                color: Theme.textPrimary
                                font.pixelSize: Theme.fontSizeNormal
                                font.family: Theme.fontFamily
                                font.bold: true
                            }
                        }

                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            onTapped: {
                                interfaceView.selectedKind = interfaceView.kindForFamily(interfaceView.selectedFamily)
                                interfaceView.loadInterface(quickPort.modelData)
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                StandardTextField {
                    id: ifaceField
                    Layout.fillWidth: true
                    labelText: "Interface name"
                    placeholderText: "e.g. GigabitEthernet0/0 or Loopback1"
                    onEditingFinished: interfaceView.loadInterface(text.trim())
                }
                StandardComboBox {
                    id: kindCombo
                    Layout.preferredWidth: 130
                    labelText: "DB detail"
                    model: ["L3", "WAN", "Tunnel"]
                    valueModel: ["L3", "WAN", "Tunnel"]
                    currentIndex: Math.max(0, ["L3", "WAN", "Tunnel"].indexOf(interfaceView.selectedKind))
                    onActivated: interfaceView.selectedKind = currentValue
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 10
                rowSpacing: 10
                StandardNetworkField { id: ipField; Layout.fillWidth: true; inputKind: "ipv4"; labelText: "IP address"; placeholderText: "192.168.1.1" }
                StandardNetworkField { id: maskField; Layout.fillWidth: true; inputKind: "subnet"; labelText: "Subnet mask (/24)"; placeholderText: "255.255.255.0 or /24" }
                StandardTextField { id: descriptionField; Layout.fillWidth: true; Layout.columnSpan: 2; labelText: "Description"; placeholderText: "Link to core / WAN / customer" }
            }

            RowLayout {
                Layout.fillWidth: true
                StandardCheckBox { id: shutdownCheck; text: "Shutdown" }
                StandardCheckBox { id: enableQosCheck; text: "QoS reference" }
                Item { Layout.fillWidth: true }
            }

            Rectangle { Layout.fillWidth: true; height: Theme.borderWidth; color: Theme.splitHandleColor }

            ColumnLayout {
                Layout.fillWidth: true
                visible: interfaceView.selectedKind === "L3"
                spacing: 10
                GridLayout {
                    Layout.fillWidth: true
                    columns: 3
                    columnSpacing: 10
                    rowSpacing: 10
                    StandardNetworkField { id: secondaryIpField; Layout.fillWidth: true; inputKind: "ipv4"; labelText: "Secondary IP" }
                    StandardNetworkField { id: secondaryMaskField; Layout.fillWidth: true; inputKind: "subnet"; labelText: "Secondary mask (/24)" }
                    StandardTextField { id: mtuField; Layout.fillWidth: true; labelText: "MTU"; text: "1500" }
                    StandardTextField { id: bandwidthField; Layout.fillWidth: true; labelText: "Bandwidth" }
                    StandardTextField { id: delayField; Layout.fillWidth: true; labelText: "Delay" }
                    StandardComboBox { id: speedCombo; Layout.fillWidth: true; labelText: "Speed"; model: ["Auto", "10", "100", "1000", "10000"]; valueModel: ["auto", "10", "100", "1000", "10000"] }
                    StandardComboBox { id: duplexCombo; Layout.fillWidth: true; labelText: "Duplex"; model: ["Auto", "Full", "Half"]; valueModel: ["auto", "full", "half"] }
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: 10
                    StandardCheckBox { id: negotiationCheck; text: "Negotiation"; checked: true }
                    StandardCheckBox { id: proxyArpCheck; text: "Proxy ARP"; checked: true }
                    StandardCheckBox { id: unreachablesCheck; text: "Unreachables"; checked: true }
                    StandardCheckBox { id: directedBroadcastCheck; text: "Directed broadcast" }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 3
                columnSpacing: 10
                rowSpacing: 10
                visible: interfaceView.selectedKind === "Tunnel"
                StandardComboBox { id: tunnelModeCombo; Layout.fillWidth: true; labelText: "Tunnel mode"; model: ["gre", "ipip", "ipsec", "gre-ipsec"] }
                StandardTextField { id: tunnelSrcField; Layout.fillWidth: true; labelText: "Tunnel source" }
                StandardTextField { id: tunnelDstField; Layout.fillWidth: true; labelText: "Tunnel destination" }
                StandardTextField { id: tunnelKeyField; Layout.fillWidth: true; labelText: "Tunnel key" }
                StandardTextField { id: keepaliveSecField; Layout.fillWidth: true; labelText: "Keepalive sec" }
                StandardTextField { id: keepaliveRetryField; Layout.fillWidth: true; labelText: "Keepalive retry" }
                StandardTextField { id: ipsecProfileField; Layout.fillWidth: true; Layout.columnSpan: 3; labelText: "IPsec profile" }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 3
                columnSpacing: 10
                rowSpacing: 10
                visible: interfaceView.selectedKind === "WAN"
                StandardComboBox { id: encapCombo; Layout.fillWidth: true; labelText: "Encapsulation"; model: ["none", "pppoe", "hdlc", "ppp", "frame-relay"] }
                StandardTextField { id: pppoePoolField; Layout.fillWidth: true; labelText: "PPPoE pool" }
                StandardComboBox { id: pppAuthCombo; Layout.fillWidth: true; labelText: "PPP auth"; model: ["", "pap", "chap"] }
                StandardTextField { id: pppUsernameField; Layout.fillWidth: true; labelText: "PPP username" }
                StandardPasswordField { id: pppPasswordField; Layout.fillWidth: true; labelText: "PPP password" }
                StandardTextField { id: clockRateField; Layout.fillWidth: true; labelText: "Clock rate" }
                StandardComboBox { id: lmiCombo; Layout.fillWidth: true; labelText: "LMI"; model: ["", "cisco", "ansi", "q933a"] }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 3
                columnSpacing: 10
                rowSpacing: 10
                visible: enableQosCheck.checked
                StandardComboBox { id: trustCombo; Layout.fillWidth: true; labelText: "Trust mode"; model: ["none", "cos", "dscp", "ip-precedence"] }
                StandardTextField { id: policyInField; Layout.fillWidth: true; labelText: "Policy in" }
                StandardTextField { id: policyOutField; Layout.fillWidth: true; labelText: "Policy out" }
                StandardTextField { id: shapeRateField; Layout.fillWidth: true; labelText: "Shape rate" }
                StandardTextField { id: policeRateField; Layout.fillWidth: true; labelText: "Police rate" }
                StandardTextField { id: policeBurstField; Layout.fillWidth: true; labelText: "Police burst" }
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.fillWidth: true
                StandardButton {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    text: selectedIfaceId > 0 ? "Update Interface" : "Save Interface"
                    icon.source: AppAssets.actionSave
                    type: "Primary"
                    enabled: currentHostIp !== "" && ifaceField.text.trim() !== ""
                             && (selectedKind !== "Tunnel" || (tunnelSrcField.text.trim() !== "" && tunnelDstField.text.trim() !== ""))
                    onClicked: interfaceView.saveForm()
                }
                StandardButton {
                    Layout.preferredWidth: 120
                    Layout.preferredHeight: 36
                    text: "Clear"
                    type: "Secondary"
                    onClicked: interfaceView.clearForm()
                }
            }
        }

        SavedListPanel {
            SplitView.fillWidth: true
            SplitView.fillHeight: true
            SplitView.minimumWidth: interfaceView.compactLayout ? 0 : 320
            SplitView.minimumHeight: interfaceView.compactLayout ? 240 : 0
            title: "Database reference"
            count: interfaceModel.count
            emptyText: "No router interfaces saved yet."

            ListView {
                id: interfaceList
                objectName: "interfaceSavedList"
                anchors.fill: parent
                model: interfaceModel
                clip: true
                spacing: 0
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                delegate: SavedListRow {
                    id: rowDelegate
                    required property int index
                    required property var model
                    rowIndex: index
                    height: 72
                    selected: interfaceView.selectedListIndex === index

                    RowLayout {
                        anchors.fill: parent
                        spacing: Theme.spacing8

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                Layout.fillWidth: true
                                text: model.interface_name || ""
                                color: Theme.textPrimary
                                font.pixelSize: Theme.fontSizeNormal
                                font.family: Theme.fontFamily
                                font.bold: true
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                text: (model.ip_address || "no ip") + " / " + (model.subnet_mask || "no mask")
                                color: Theme.textSecondary
                                font.pixelSize: Theme.fontSizeSmall
                                font.family: Theme.fontFamily
                                elide: Text.ElideRight
                            }
                            Flow {
                                Layout.fillWidth: true
                                spacing: 5
                                Repeater {
                                    model: interfaceView.referenceTables(rowDelegate.model)
                                    delegate: Rectangle {
                                        required property string modelData
                                        height: 20
                                        width: refText.implicitWidth + 12
                                        radius: Theme.radiusSmall
                                        color: Theme.searchBackground2
                                        border.color: Theme.borderColor
                                        Text {
                                            id: refText
                                            anchors.centerIn: parent
                                            text: modelData
                                            color: Theme.textSecondary
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.family: Theme.fontFamily
                                        }
                                    }
                                }
                            }
                        }

                        IconButton {
                            buttonSize: 28
                            iconSize: Theme.iconSizeNormal
                            iconSource: AppAssets.actionEdit
                            tooltip: "Edit interface"
                            onClicked: {
                                interfaceView.selectInterfaceRow(
                                    rowDelegate.index,
                                    rowDelegate.model
                                )
                                interfaceView.editSelectedInterface()
                            }
                        }
                        IconButton {
                            buttonSize: 28
                            iconSize: Theme.iconSizeNormal
                            iconSource: AppAssets.actionDelete
                            danger: true
                            tooltip: "Delete interface"
                            onClicked: {
                                interfaceView.selectInterfaceRow(
                                    rowDelegate.index,
                                    rowDelegate.model
                                )
                                interfaceView.deleteSelectedInterface()
                            }
                        }
                    }

                    TapHandler {
                        acceptedButtons: Qt.LeftButton
                        onTapped: interfaceView.selectInterfaceRow(
                            rowDelegate.index,
                            rowDelegate.model
                        )
                    }
                    TapHandler {
                        acceptedButtons: Qt.RightButton
                        onTapped: function(eventPoint, button) {
                            interfaceView.openInterfaceContext(
                                rowDelegate.index,
                                rowDelegate.model,
                                eventPoint.scenePosition.x,
                                eventPoint.scenePosition.y
                            )
                        }
                    }
                }
            }
        }
    }

    Shortcut {
        sequence: "F2"
        enabled: interfaceView.collectionShortcutsEnabled
                 && interfaceView.selectedListIndex >= 0
        onActivated: interfaceView.editSelectedInterface()
    }
    Shortcut {
        sequence: "Delete"
        enabled: interfaceView.collectionShortcutsEnabled
                 && interfaceView.selectedListIndex >= 0
        onActivated: interfaceView.deleteSelectedInterface()
    }
    Shortcut {
        sequence: "F5"
        enabled: interfaceView.collectionShortcutsEnabled
        onActivated: interfaceView.reloadInterfaces()
    }
    Shortcut {
        sequence: "Shift+F10"
        enabled: interfaceView.collectionShortcutsEnabled
                 && interfaceView.selectedListIndex >= 0
        onActivated: interfaceView.openContextForSelectedInterface()
    }
}
