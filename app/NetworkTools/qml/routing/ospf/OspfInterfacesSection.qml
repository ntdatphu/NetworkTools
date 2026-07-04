pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import NetworkTools

Rectangle {
    id: root

    required property var form

    visible: String(form.currentHostIp || "").trim() !== ""
        && form.activeRoutingSection === "Interfaces"
        && form.processCount > 0
    Layout.fillWidth: true
    Layout.leftMargin: 24
    Layout.rightMargin: 24
    implicitHeight: layout.implicitHeight + Theme.spacing32
    radius: Theme.cardRadius
    color: Theme.contentPanelSurface
    border.color: Theme.contentPanelBorder
    border.width: Theme.borderWidth

    ColumnLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: Theme.spacing16
        spacing: Theme.spacing12

        Text { text: "OSPF INTERFACE SETTINGS"; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeLarge; font.family: Theme.fontFamily; font.bold: true }

        GridLayout {
            Layout.fillWidth: true
            columns: width < 860 ? 2 : 5
            columnSpacing: Theme.spacing12
            rowSpacing: Theme.spacing8

            StandardComboBox { Layout.fillWidth: true; labelText: "OSPF Process"; model: root.form.processOptions; currentIndex: root.form.selectedNetworkProcessIndex; onCurrentIndexChanged: if (currentIndex >= 0) root.form.selectedNetworkProcessIndex = currentIndex }
            StandardTextField { id: nameField; Layout.fillWidth: true; labelText: "Interface"; placeholderText: "GigabitEthernet0/0" }
            StandardTextField { id: areaField; Layout.fillWidth: true; labelText: "Area"; placeholderText: "0" }
            StandardTextField { id: costField; Layout.fillWidth: true; labelText: "Cost"; placeholderText: "optional" }
            StandardTextField { id: helloField; Layout.fillWidth: true; labelText: "Hello"; placeholderText: "optional" }
            StandardTextField { id: deadField; Layout.fillWidth: true; labelText: "Dead"; placeholderText: "optional" }
            StandardComboBox { id: networkTypeCombo; Layout.fillWidth: true; labelText: "Network type"; model: ["", "broadcast", "non-broadcast", "point-to-point", "point-to-multipoint"] }
            StandardComboBox { id: authTypeCombo; Layout.fillWidth: true; labelText: "Auth"; model: ["", "plain", "message-digest"] }
            StandardCheckBox { id: mtuCheck; text: "MTU ignore"; Layout.alignment: Qt.AlignBottom }
            StandardCheckBox { id: bfdCheck; text: "BFD"; Layout.alignment: Qt.AlignBottom }
        }

        RowLayout {
            Layout.fillWidth: true
            StandardButton {
                text: "+ Add Interface Setting"
                type: "Primary"
                onClicked: root.form.addInterfaceSettingToSelectedProcess(nameField.text, areaField.text, costField.text, helloField.text, deadField.text, mtuCheck.checked, bfdCheck.checked, networkTypeCombo.currentText, authTypeCombo.currentText)
            }
            Item { Layout.fillWidth: true }
        }

        Repeater {
            model: {
                const revision = root.form.statsRevision
                const item = root.form.selectedProcessItem()
                return item ? item.interfaceSettings : null
            }
            delegate: RowLayout {
                required property string interface_name
                required property string area
                required property string cost
                required property string hello_interval
                required property string dead_interval
                required property string network_type
                required property string auth_type
                required property int index
                Layout.fillWidth: true
                Text { Layout.fillWidth: true; text: interface_name; color: Theme.accentColor; font.family: Theme.fontFamily; elide: Text.ElideRight }
                Text { Layout.preferredWidth: 72; text: "area " + area; color: Theme.textPrimary; font.family: Theme.fontFamily }
                Text { Layout.fillWidth: true; text: cost ? ("cost " + cost) : ""; color: Theme.textSecondary; font.family: Theme.fontFamily }
                Text { Layout.fillWidth: true; text: hello_interval || dead_interval ? ("hello/dead " + hello_interval + "/" + dead_interval) : ""; color: Theme.textSecondary; font.family: Theme.fontFamily }
                Text { Layout.fillWidth: true; text: network_type || auth_type; color: Theme.textSecondary; font.family: Theme.fontFamily; elide: Text.ElideRight }
                StandardButton { Layout.preferredWidth: 34; type: "Icon"; icon.source: AppPaths.resource("resources/devicetabs/close.svg"); tooltip: "Remove interface setting"; onClicked: root.form.removeInterfaceSettingFromSelectedProcess(index) }
            }
        }
    }
}
