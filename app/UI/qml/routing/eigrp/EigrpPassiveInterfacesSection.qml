pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import UI

Rectangle {
    id: root
    required property var form

    visible: String(form.currentHostIp || "").trim() !== ""
        && form.activeRoutingSection === "Passive iface"
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

        Text { text: "EIGRP PASSIVE INTERFACES"; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeLarge; font.family: Theme.fontFamily; font.bold: true }

        GridLayout {
            Layout.fillWidth: true
            columns: width < 760 ? 2 : 4
            columnSpacing: Theme.spacing12
            rowSpacing: Theme.spacing8
            StandardComboBox { Layout.fillWidth: true; labelText: "EIGRP Process"; model: root.form.processOptions; currentIndex: root.form.selectedNetworkProcessIndex; onCurrentIndexChanged: if (currentIndex >= 0) root.form.selectedNetworkProcessIndex = currentIndex }
            StandardTextField { id: ifaceField; Layout.fillWidth: true; labelText: "Interface"; placeholderText: "GigabitEthernet0/0" }
            StandardComboBox { id: modeCombo; Layout.fillWidth: true; labelText: "Mode"; model: ["passive", "no-passive"] }
            StandardButton { text: "+ Add"; type: "Primary"; Layout.alignment: Qt.AlignBottom; onClicked: if (root.form.addPassiveInterfaceToSelectedProcess(ifaceField.text, modeCombo.currentText)) ifaceField.clear() }
        }

        Repeater {
            model: {
                const revision = root.form.statsRevision
                const item = root.form.selectedProcessItem()
                return item ? item.passiveInterfaces : null
            }
            delegate: RowLayout {
                required property string interface_name
                required property string mode
                required property int index
                Layout.fillWidth: true
                Text { Layout.fillWidth: true; text: interface_name; color: Theme.accentColor; font.family: Theme.fontFamily }
                Text { Layout.fillWidth: true; text: mode; color: Theme.textPrimary; font.family: Theme.fontFamily }
                StandardButton { Layout.preferredWidth: 34; type: "Icon"; icon.source: AppPaths.resource("resources/devicetabs/close.svg"); tooltip: "Remove passive interface"; onClicked: root.form.removePassiveInterfaceFromSelectedProcess(index) }
            }
        }
    }
}
