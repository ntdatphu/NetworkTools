pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

ScrollView {
    id: root

    required property var draft
    property bool editing: false
    property bool allowRouted: false
    property bool routedOnly: false
    property string viewMode: "interfaces"
    readonly property bool hasContent: editing
                                       || String(value("if_name", "")).trim() !== ""

    signal fieldChanged(string name, var value)

    clip: true
    contentWidth: availableWidth
    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
    ScrollBar.vertical.policy: ScrollBar.AsNeeded

    function value(name, fallback) {
        const current = root.draft && root.draft[name]
        return current === undefined || current === null ? fallback : current
    }
    function comboIndex(model, value) {
        const index = model.indexOf(String(value))
        return index < 0 ? 0 : index
    }

    Item {
        width: root.availableWidth
        implicitHeight: root.hasContent
                        ? sections.implicitHeight + Theme.spacing24
                        : root.availableHeight

        EmptyState {
            anchors.fill: parent
            visible: !root.hasContent
            title: "No switch port selected"
            description: "Select a table row to inspect it, or choose Add to create one."
        }

        ColumnLayout {
            id: sections
            visible: root.hasContent
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.spacing8
            spacing: Theme.spacing12

            FormSection {
                Layout.fillWidth: true
                title: "Interface"

                StandardTextField {
                    Layout.fillWidth: true
                    labelText: "Interface name"
                    readOnly: !root.editing
                    text: String(root.value("if_name", ""))
                    onTextEdited: value => root.fieldChanged("if_name", value)
                }
                StandardTextField {
                    Layout.fillWidth: true
                    visible: root.viewMode === "interfaces"
                    labelText: "Description"
                    readOnly: !root.editing
                    text: String(root.value("description", ""))
                    onTextEdited: value => root.fieldChanged("description", value)
                }
                StandardComboBox {
                    Layout.fillWidth: true
                    labelText: "Admin status"
                    model: ["up", "down"]
                    enabled: root.editing
                    currentIndex: root.comboIndex(model, root.value("admin_status", "up"))
                    onActivated: index => root.fieldChanged("admin_status", model[index])
                }
                RowLayout {
                    Layout.fillWidth: true
                    visible: root.viewMode === "interfaces"
                    StandardComboBox {
                        Layout.fillWidth: true
                        labelText: "Speed"
                        model: ["auto", "10", "100", "1000", "10000"]
                        enabled: root.editing
                        currentIndex: root.comboIndex(model, root.value("speed", "auto"))
                        onActivated: index => root.fieldChanged("speed", model[index])
                    }
                    StandardComboBox {
                        Layout.fillWidth: true
                        labelText: "Duplex"
                        model: ["auto", "full", "half"]
                        enabled: root.editing
                        currentIndex: root.comboIndex(model, root.value("duplex", "auto"))
                        onActivated: index => root.fieldChanged("duplex", model[index])
                    }
                }
            }

            FormSection {
                Layout.fillWidth: true
                visible: root.viewMode === "interfaces"
                title: "Switching"

                StandardComboBox {
                    Layout.fillWidth: true
                    labelText: "Mode"
                    model: root.routedOnly ? ["routed"]
                         : root.allowRouted ? ["access", "trunk", "routed"]
                         : ["access", "trunk"]
                    enabled: root.editing
                    currentIndex: root.comboIndex(model, root.value("mode", "access"))
                    onActivated: index => root.fieldChanged("mode", model[index])
                }
                StandardTextField {
                    Layout.fillWidth: true
                    visible: root.value("mode", "access") === "access"
                    labelText: "Access VLAN"
                    readOnly: !root.editing
                    text: String(root.value("access_vlan", 1))
                    onTextEdited: value => root.fieldChanged("access_vlan", value)
                }
                StandardTextField {
                    Layout.fillWidth: true
                    visible: root.value("mode", "access") === "access"
                    labelText: "Voice VLAN (optional)"
                    readOnly: !root.editing
                    text: String(root.value("voice_vlan", ""))
                    onTextEdited: value => root.fieldChanged("voice_vlan", value)
                }
                StandardTextField {
                    Layout.fillWidth: true
                    visible: root.value("mode", "access") === "trunk"
                    labelText: "Allowed VLANs"
                    readOnly: !root.editing
                    text: String(root.value("allowed_vlans", "all"))
                    onTextEdited: value => root.fieldChanged("allowed_vlans", value)
                }
                StandardTextField {
                    Layout.fillWidth: true
                    visible: root.value("mode", "access") === "trunk"
                    labelText: "Native VLAN"
                    readOnly: !root.editing
                    text: String(root.value("native_vlan", 1))
                    onTextEdited: value => root.fieldChanged("native_vlan", value)
                }
            }

            FormSection {
                Layout.fillWidth: true
                title: "Loop Protection"
                visible: root.viewMode === "interfaces"
                         && root.value("mode", "access") !== "routed"

                StandardCheckBox {
                    text: "PortFast"
                    enabled: root.editing
                    checked: root.value("portfast", "disabled") === "enabled"
                    onToggled: root.fieldChanged("portfast", checked ? "enabled" : "disabled")
                }
                StandardCheckBox {
                    text: "BPDU Guard"
                    enabled: root.editing
                    checked: root.value("bpduguard", "disabled") === "enabled"
                    onToggled: root.fieldChanged("bpduguard", checked ? "enabled" : "disabled")
                }
                StandardCheckBox {
                    text: "Root Guard"
                    enabled: root.editing
                    checked: root.value("root_guard", "disabled") === "enabled"
                    onToggled: root.fieldChanged("root_guard", checked ? "enabled" : "disabled")
                }
            }

            FormSection {
                objectName: "switchPortSecuritySection"
                Layout.fillWidth: true
                title: "Port Security"
                visible: (root.viewMode === "interfaces" || root.viewMode === "portSecurity")
                         && root.value("mode", "access") !== "routed"

                StandardCheckBox {
                    text: "Enable port security"
                    enabled: root.editing
                    checked: Boolean(root.value("port_security_enabled", 0))
                    onToggled: root.fieldChanged("port_security_enabled", checked)
                }
                StandardTextField {
                    Layout.fillWidth: true
                    labelText: "Maximum MAC addresses"
                    readOnly: !root.editing
                    enabled: Boolean(root.value("port_security_enabled", 0))
                    text: String(root.value("max_mac", 1))
                    onTextEdited: value => root.fieldChanged("max_mac", value)
                }
                StandardComboBox {
                    Layout.fillWidth: true
                    labelText: "Violation action"
                    model: ["shutdown", "restrict", "protect"]
                    enabled: root.editing && Boolean(root.value("port_security_enabled", 0))
                    currentIndex: root.comboIndex(model, root.value("violation", "shutdown"))
                    onActivated: index => root.fieldChanged("violation", model[index])
                }
                StandardCheckBox {
                    text: "Sticky MAC learning"
                    enabled: root.editing && Boolean(root.value("port_security_enabled", 0))
                    checked: Boolean(root.value("sticky", 0))
                    onToggled: root.fieldChanged("sticky", checked)
                }
            }

            FormSection {
                objectName: "switchStormControlSection"
                Layout.fillWidth: true
                title: "Storm Control"
                visible: (root.viewMode === "interfaces" || root.viewMode === "stormControl")
                         && root.value("mode", "access") !== "routed"

                StandardCheckBox {
                    text: "Enable storm control"
                    enabled: root.editing
                    checked: Boolean(root.value("storm_enabled", 0))
                    onToggled: root.fieldChanged("storm_enabled", checked)
                }
                GridLayout {
                    Layout.fillWidth: true
                    columns: root.availableWidth >= 720 ? 3 : 1
                    columnSpacing: Theme.spacing8
                    rowSpacing: Theme.spacing8
                    enabled: Boolean(root.value("storm_enabled", 0))

                    StandardTextField {
                        Layout.fillWidth: true
                        labelText: "Broadcast %"
                        readOnly: !root.editing
                        text: String(root.value("bc_level", 20))
                        onTextEdited: value => root.fieldChanged("bc_level", value)
                    }
                    StandardTextField {
                        Layout.fillWidth: true
                        labelText: "Multicast %"
                        readOnly: !root.editing
                        text: String(root.value("mc_level", 20))
                        onTextEdited: value => root.fieldChanged("mc_level", value)
                    }
                    StandardTextField {
                        Layout.fillWidth: true
                        labelText: "Unknown unicast %"
                        readOnly: !root.editing
                        text: String(root.value("uc_level", 80))
                        onTextEdited: value => root.fieldChanged("uc_level", value)
                    }
                }
            }
        }
    }
}
