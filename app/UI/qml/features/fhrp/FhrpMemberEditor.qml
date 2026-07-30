pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import UI

// Per-host fields are isolated from FhrpView's group-level orchestration.
Rectangle {
    id: root

    required property int memberIndex
    required property string host
    required property var interfaceOptions
    required property int ifaceId
    required property string priority
    required property bool preempt
    required property string authType
    required property string authSecret
    required property string protocol

    signal fieldChanged(int memberIndex, string field, var value)

    Layout.fillWidth: true
    implicitHeight: layout.implicitHeight + Theme.spacing24
    radius: Theme.cardRadius
    color: Theme.contentPanelSurface
    border.color: Theme.contentPanelBorder
    border.width: Theme.borderWidth

    function interfaceLabels() {
        return (interfaceOptions || []).map(
                    item => item.interface_name + " · " + item.ip_address
                            + " (" + item.network + ")")
    }

    function interfaceIds() {
        return (interfaceOptions || []).map(item => String(item.iface_id))
    }

    ColumnLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: Theme.spacing12
        spacing: Theme.spacing10

        Text {
            text: root.host
            color: Theme.accentColor
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeNormal
            font.bold: true
        }

        GridLayout {
            Layout.fillWidth: true
            columns: width < 720 ? 2 : 4
            columnSpacing: Theme.spacing12
            rowSpacing: Theme.spacing10

            StandardComboBox {
                Layout.fillWidth: true
                labelText: "Matching interface"
                model: root.interfaceLabels()
                valueModel: root.interfaceIds()
                currentIndex: {
                    const values = root.interfaceIds()
                    return Math.max(0, values.indexOf(String(root.ifaceId)))
                }
                onActivated: root.fieldChanged(
                                 root.memberIndex, "ifaceId",
                                 Number(root.interfaceIds()[currentIndex]))
            }
            StandardTextField {
                Layout.fillWidth: true
                labelText: "Priority"
                text: root.priority
                inputMethodHints: Qt.ImhDigitsOnly
                onTextEdited: value => root.fieldChanged(
                                  root.memberIndex, "priority", value)
            }
            StandardComboBox {
                Layout.fillWidth: true
                labelText: "Authentication"
                model: root.protocol === "vrrp"
                       ? ["None", "Plain"]
                       : ["None", "Plain", "MD5 key", "MD5 key-chain"]
                valueModel: root.protocol === "vrrp"
                            ? ["none", "plain"]
                            : ["none", "plain", "md5-key", "md5-keychain"]
                currentIndex: Math.max(0, valueModel.indexOf(root.authType))
                onActivated: root.fieldChanged(
                                 root.memberIndex, "authType", currentValue)
            }
            StandardPasswordField {
                Layout.fillWidth: true
                enabled: root.authType !== "none"
                labelText: "Authentication secret"
                text: root.authSecret
                onTextChanged: root.fieldChanged(
                                   root.memberIndex, "authSecret", text)
            }
        }

        Flow {
            Layout.fillWidth: true
            spacing: Theme.spacing12
            StandardCheckBox {
                text: "Preempt"
                checked: root.preempt
                onToggled: root.fieldChanged(
                               root.memberIndex, "preempt", checked)
            }
        }
    }
}
