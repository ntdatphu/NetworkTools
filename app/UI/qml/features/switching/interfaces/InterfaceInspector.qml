pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import UI

SwitchInspectorPane {
    id: root

    required property var draft
    property bool allowRouted: false
    property bool routedOnly: false
    property string viewMode: "interfaces"

    readonly property bool hasPort: String(value("if_name", "")).trim() !== ""
    readonly property bool accessPort: value("mode", "access") === "access"
    readonly property bool trunkPort: value("mode", "access") === "trunk"
    readonly property bool layer2Port: value("mode", "access") !== "routed"
    readonly property string profileTitle: viewMode === "portSecurity" ? "Port Security"
                                                   : viewMode === "stormControl" ? "Storm Control"
                                                   : routedOnly ? "Routed Port" : "Switch Port"

    signal fieldChanged(string name, var value)

    function value(name, fallback) {
        const current = root.draft && root.draft[name]
        return current === undefined || current === null ? fallback : current
    }

    function comboIndex(model, value) {
        const index = model.indexOf(String(value))
        return index < 0 ? 0 : index
    }

    function enabledLabel(value) {
        return value === true || value === 1 || String(value) === "enabled" ? "Enabled" : "Disabled"
    }

    function vlanSummary() {
        if (root.accessPort) {
            const voice = root.value("voice_vlan", "")
            return "Access " + root.value("access_vlan", 1)
                    + (voice ? " · Voice " + voice : "")
        }
        if (root.trunkPort)
            return "Native " + root.value("native_vlan", 1)
                    + " · Allowed " + root.value("allowed_vlans", "all")
        return "Layer 3"
    }

    title: root.hasPort ? String(root.value("if_name", root.profileTitle)) : root.profileTitle
    subtitle: root.viewMode === "interfaces" ? "Port configuration"
             : root.viewMode === "portSecurity" ? "MAC admission policy"
             : "Traffic suppression policy"
    hasContent: root.editing || root.hasPort
    emptyTitle: "No port selected"
    emptyDescription: "Select a row to inspect it, then choose Edit to make changes."

    SwitchInspectorSection {
        Layout.fillWidth: true
        title: root.viewMode === "interfaces" ? "Identity and link" : "Target interface"
        description: root.viewMode === "interfaces"
                     ? "The physical identity and administrative link settings."
                     : "Security profiles are attached to an existing Layer 2 port."

        SwitchPropertyRow {
            visible: !root.editing || root.viewMode !== "interfaces"
            label: "Interface"
            value: String(root.value("if_name", "—"))
            emphasize: true
        }
        SwitchPropertyRow {
            visible: !root.editing && root.viewMode === "interfaces"
            label: "Description"
            value: String(root.value("description", "—"))
        }
        SwitchPropertyRow {
            visible: !root.editing || root.viewMode !== "interfaces"
            label: "Mode"
            value: String(root.value("mode", "access"))
        }
        SwitchPropertyRow {
            visible: !root.editing
            label: "Admin / Link"
            value: String(root.value("admin_status", "up")) + " / "
                   + String(root.value("oper_status", "unknown"))
            valueColor: root.value("oper_status", "unknown") === "up"
                        ? Theme.alertSuccess : Theme.textSecondary
        }
        SwitchPropertyRow {
            visible: !root.editing && root.viewMode === "interfaces"
            label: "Speed / Duplex"
            value: String(root.value("speed", "auto")) + " / "
                   + String(root.value("duplex", "auto"))
        }

        StandardTextField {
            Layout.fillWidth: true
            visible: root.editing && root.viewMode === "interfaces"
            labelText: "Interface name"
            text: String(root.value("if_name", ""))
            onTextEdited: value => root.fieldChanged("if_name", value)
        }
        StandardTextField {
            Layout.fillWidth: true
            visible: root.editing && root.viewMode === "interfaces"
            labelText: "Description"
            text: String(root.value("description", ""))
            onTextEdited: value => root.fieldChanged("description", value)
        }
        StandardComboBox {
            Layout.fillWidth: true
            visible: root.editing && root.viewMode === "interfaces"
            labelText: "Admin status"
            model: ["up", "down"]
            currentIndex: root.comboIndex(model, root.value("admin_status", "up"))
            onActivated: index => root.fieldChanged("admin_status", model[index])
        }
        RowLayout {
            Layout.fillWidth: true
            visible: root.editing && root.viewMode === "interfaces"

            StandardComboBox {
                Layout.fillWidth: true
                labelText: "Speed"
                model: ["auto", "10", "100", "1000", "10000"]
                currentIndex: root.comboIndex(model, root.value("speed", "auto"))
                onActivated: index => root.fieldChanged("speed", model[index])
            }
            StandardComboBox {
                Layout.fillWidth: true
                labelText: "Duplex"
                model: ["auto", "full", "half"]
                currentIndex: root.comboIndex(model, root.value("duplex", "auto"))
                onActivated: index => root.fieldChanged("duplex", model[index])
            }
        }
    }

    SwitchInspectorSection {
        Layout.fillWidth: true
        visible: root.viewMode === "interfaces"
        title: root.routedOnly ? "Layer 3 mode" : "VLAN membership"
        description: root.routedOnly
                     ? "Routed ports do not participate in Layer 2 VLAN forwarding."
                     : "Only fields relevant to the selected access or trunk mode are shown."

        SwitchPropertyRow {
            visible: !root.editing
            label: "Mode"
            value: String(root.value("mode", "access"))
            emphasize: true
        }
        SwitchPropertyRow {
            visible: !root.editing && root.layer2Port
            label: "Membership"
            value: root.vlanSummary()
        }
        SwitchPropertyRow {
            visible: !root.editing && root.trunkPort
            label: "Encapsulation"
            value: String(root.value("encapsulation", "dot1q"))
        }
        SwitchPropertyRow {
            visible: !root.editing && root.trunkPort
            label: "Pruning"
            value: String(root.value("pruning_vlans", "none"))
        }

        StandardComboBox {
            Layout.fillWidth: true
            visible: root.editing
            labelText: "Mode"
            model: root.routedOnly ? ["routed"]
                 : root.allowRouted ? ["access", "trunk", "routed"]
                 : ["access", "trunk"]
            currentIndex: root.comboIndex(model, root.value("mode", "access"))
            onActivated: index => root.fieldChanged("mode", model[index])
        }
        RowLayout {
            Layout.fillWidth: true
            visible: root.editing && root.accessPort

            StandardTextField {
                Layout.fillWidth: true
                labelText: "Access VLAN"
                text: String(root.value("access_vlan", 1))
                onTextEdited: value => root.fieldChanged("access_vlan", value)
            }
            StandardTextField {
                Layout.fillWidth: true
                labelText: "Voice VLAN"
                placeholderText: "Optional"
                text: String(root.value("voice_vlan", ""))
                onTextEdited: value => root.fieldChanged("voice_vlan", value)
            }
        }
        StandardTextField {
            Layout.fillWidth: true
            visible: root.editing && root.trunkPort
            labelText: "Allowed VLANs"
            placeholderText: "all or 10,20-30"
            text: String(root.value("allowed_vlans", "all"))
            onTextEdited: value => root.fieldChanged("allowed_vlans", value)
        }
        RowLayout {
            Layout.fillWidth: true
            visible: root.editing && root.trunkPort

            StandardTextField {
                Layout.fillWidth: true
                labelText: "Native VLAN"
                text: String(root.value("native_vlan", 1))
                onTextEdited: value => root.fieldChanged("native_vlan", value)
            }
            StandardComboBox {
                Layout.fillWidth: true
                labelText: "Encapsulation"
                model: ["dot1q", "isl"]
                currentIndex: root.comboIndex(model, root.value("encapsulation", "dot1q"))
                onActivated: index => root.fieldChanged("encapsulation", model[index])
            }
        }
        StandardTextField {
            Layout.fillWidth: true
            visible: root.editing && root.trunkPort
            labelText: "Pruning VLANs"
            placeholderText: "none or 10,20-30"
            text: String(root.value("pruning_vlans", "none"))
            onTextEdited: value => root.fieldChanged("pruning_vlans", value)
        }
    }

    SwitchInspectorSection {
        Layout.fillWidth: true
        visible: root.viewMode === "interfaces" && root.layer2Port
        title: "Loop protection"
        description: "Edge and guard controls for Layer 2 topology safety."
        showDivider: false

        SwitchPropertyRow { visible: !root.editing; label: "PortFast"; value: root.enabledLabel(root.value("portfast", "disabled")) }
        SwitchPropertyRow { visible: !root.editing; label: "BPDU Guard"; value: root.enabledLabel(root.value("bpduguard", "disabled")) }
        SwitchPropertyRow { visible: !root.editing; label: "BPDU Filter"; value: root.enabledLabel(root.value("bpdufilter", "disabled")) }
        SwitchPropertyRow { visible: !root.editing; label: "Root Guard"; value: root.enabledLabel(root.value("root_guard", "disabled")) }
        SwitchPropertyRow { visible: !root.editing; label: "Loop Guard"; value: root.enabledLabel(root.value("loop_guard", "disabled")) }

        GridLayout {
            Layout.fillWidth: true
            visible: root.editing
            columns: root.width >= 390 ? 2 : 1
            columnSpacing: Theme.spacing12
            rowSpacing: Theme.spacing4

            StandardCheckBox { text: "PortFast"; checked: root.value("portfast", "disabled") === "enabled"; onToggled: root.fieldChanged("portfast", checked ? "enabled" : "disabled") }
            StandardCheckBox { text: "BPDU Guard"; checked: root.value("bpduguard", "disabled") === "enabled"; onToggled: root.fieldChanged("bpduguard", checked ? "enabled" : "disabled") }
            StandardCheckBox { text: "BPDU Filter"; checked: root.value("bpdufilter", "disabled") === "enabled"; onToggled: root.fieldChanged("bpdufilter", checked ? "enabled" : "disabled") }
            StandardCheckBox { text: "Root Guard"; checked: root.value("root_guard", "disabled") === "enabled"; onToggled: root.fieldChanged("root_guard", checked ? "enabled" : "disabled") }
            StandardCheckBox { text: "Loop Guard"; checked: root.value("loop_guard", "disabled") === "enabled"; onToggled: root.fieldChanged("loop_guard", checked ? "enabled" : "disabled") }
        }
    }

    SwitchInspectorSection {
        objectName: "switchPortSecuritySection"
        Layout.fillWidth: true
        visible: root.viewMode === "portSecurity" && root.layer2Port
        title: "MAC admission policy"
        description: "Limit learned source addresses and define violation handling."
        showDivider: false

        SwitchPropertyRow { visible: !root.editing; label: "Policy"; value: root.enabledLabel(Boolean(root.value("port_security_enabled", 0))); valueColor: root.value("port_security_enabled", 0) ? Theme.alertSuccess : Theme.textSecondary }
        SwitchPropertyRow { visible: !root.editing; label: "Maximum MAC"; value: String(root.value("max_mac", 1)) }
        SwitchPropertyRow { visible: !root.editing; label: "Violation"; value: String(root.value("violation", "shutdown")) }
        SwitchPropertyRow { visible: !root.editing; label: "Sticky learning"; value: root.value("sticky", 0) ? "Enabled" : "Disabled" }
        SwitchPropertyRow { visible: !root.editing; label: "Aging"; value: String(root.value("aging_type", "absolute")) + " · " + String(root.value("aging_time", 0)) }

        StandardToggleButton {
            Layout.fillWidth: true
            visible: root.editing
            text: "Enable Port Security"
            description: "Enforce the MAC admission policy on this access port."
            checked: Boolean(root.value("port_security_enabled", 0))
            onToggled: root.fieldChanged("port_security_enabled", checked)
        }
        RowLayout {
            Layout.fillWidth: true
            visible: root.editing
            enabled: Boolean(root.value("port_security_enabled", 0))

            StandardTextField {
                Layout.fillWidth: true
                labelText: "Maximum MAC"
                text: String(root.value("max_mac", 1))
                onTextEdited: value => root.fieldChanged("max_mac", value)
            }
            StandardComboBox {
                Layout.fillWidth: true
                labelText: "Violation action"
                model: ["shutdown", "restrict", "protect"]
                currentIndex: root.comboIndex(model, root.value("violation", "shutdown"))
                onActivated: index => root.fieldChanged("violation", model[index])
            }
        }
        StandardCheckBox {
            visible: root.editing
            enabled: Boolean(root.value("port_security_enabled", 0))
            text: "Sticky MAC learning"
            checked: Boolean(root.value("sticky", 0))
            onToggled: root.fieldChanged("sticky", checked)
        }
        RowLayout {
            Layout.fillWidth: true
            visible: root.editing
            enabled: Boolean(root.value("port_security_enabled", 0))

            StandardComboBox {
                Layout.fillWidth: true
                labelText: "Aging type"
                model: ["absolute", "inactivity"]
                currentIndex: root.comboIndex(model, root.value("aging_type", "absolute"))
                onActivated: index => root.fieldChanged("aging_type", model[index])
            }
            StandardTextField {
                Layout.fillWidth: true
                labelText: "Aging time"
                text: String(root.value("aging_time", 0))
                onTextEdited: value => root.fieldChanged("aging_time", value)
            }
        }
    }

    SwitchInspectorSection {
        objectName: "switchStormControlSection"
        Layout.fillWidth: true
        visible: root.viewMode === "stormControl" && root.layer2Port
        title: "Traffic thresholds"
        description: "Apply percentage thresholds per traffic class and choose a response."
        showDivider: false

        SwitchPropertyRow { visible: !root.editing; label: "Policy"; value: root.enabledLabel(Boolean(root.value("storm_enabled", 0))); valueColor: root.value("storm_enabled", 0) ? Theme.alertSuccess : Theme.textSecondary }
        SwitchPropertyRow { visible: !root.editing; label: "Broadcast"; value: String(root.value("bc_level", 20)) + "%" }
        SwitchPropertyRow { visible: !root.editing; label: "Multicast"; value: String(root.value("mc_level", 20)) + "%" }
        SwitchPropertyRow { visible: !root.editing; label: "Unknown unicast"; value: String(root.value("uc_level", 80)) + "%" }
        SwitchPropertyRow { visible: !root.editing; label: "Action"; value: String(root.value("storm_action", "shutdown")) }

        StandardToggleButton {
            Layout.fillWidth: true
            visible: root.editing
            text: "Enable Storm Control"
            description: "Enforce traffic suppression thresholds on this port."
            checked: Boolean(root.value("storm_enabled", 0))
            onToggled: root.fieldChanged("storm_enabled", checked)
        }
        GridLayout {
            Layout.fillWidth: true
            visible: root.editing
            enabled: Boolean(root.value("storm_enabled", 0))
            columns: root.width >= 390 ? 3 : 1
            columnSpacing: Theme.spacing8
            rowSpacing: Theme.spacing8

            StandardTextField { Layout.fillWidth: true; labelText: "Broadcast %"; text: String(root.value("bc_level", 20)); onTextEdited: value => root.fieldChanged("bc_level", value) }
            StandardTextField { Layout.fillWidth: true; labelText: "Multicast %"; text: String(root.value("mc_level", 20)); onTextEdited: value => root.fieldChanged("mc_level", value) }
            StandardTextField { Layout.fillWidth: true; labelText: "Unicast %"; text: String(root.value("uc_level", 80)); onTextEdited: value => root.fieldChanged("uc_level", value) }
        }
        StandardComboBox {
            Layout.fillWidth: true
            visible: root.editing
            enabled: Boolean(root.value("storm_enabled", 0))
            labelText: "Threshold action"
            model: ["shutdown", "trap", "none"]
            currentIndex: root.comboIndex(model, root.value("storm_action", "shutdown"))
            onActivated: index => root.fieldChanged("storm_action", model[index])
        }
    }
}
