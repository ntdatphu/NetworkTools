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

        Text { text: "EIGRP INTERFACE SETTINGS"; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeLarge; font.family: Theme.fontFamily; font.bold: true }

        GridLayout {
            Layout.fillWidth: true
            columns: width < 760 ? 2 : 4
            columnSpacing: Theme.spacing12
            rowSpacing: Theme.spacing8

            StandardComboBox { Layout.fillWidth: true; labelText: "EIGRP Process"; model: root.form.processOptions; currentIndex: root.form.selectedNetworkProcessIndex; onCurrentIndexChanged: if (currentIndex >= 0) root.form.selectedNetworkProcessIndex = currentIndex }
            StandardTextField { id: ifaceField; Layout.fillWidth: true; labelText: "Interface"; placeholderText: "GigabitEthernet0/0" }
            StandardTextField { id: bandwidthField; Layout.fillWidth: true; labelText: "Bandwidth"; placeholderText: "optional" }
            StandardTextField { id: delayField; Layout.fillWidth: true; labelText: "Delay"; placeholderText: "optional" }
            StandardTextField { id: helloField; Layout.fillWidth: true; labelText: "Hello"; placeholderText: "optional" }
            StandardTextField { id: holdField; Layout.fillWidth: true; labelText: "Hold"; placeholderText: "optional" }
            StandardTextField { id: authField; Layout.fillWidth: true; labelText: "Auth Key Chain"; placeholderText: "optional" }
            StandardTextField { id: summaryIpField; Layout.fillWidth: true; labelText: "Summary IP"; placeholderText: "optional" }
            StandardTextField { id: summaryMaskField; Layout.fillWidth: true; labelText: "Summary Mask"; placeholderText: "optional" }
            StandardTextField { id: bwPercentField; Layout.fillWidth: true; labelText: "BW Percent"; placeholderText: "optional" }
            StandardTextField { id: bfdTxField; Layout.fillWidth: true; labelText: "BFD TX"; placeholderText: "optional" }
            StandardTextField { id: bfdRxField; Layout.fillWidth: true; labelText: "BFD RX"; placeholderText: "optional" }
            StandardTextField { id: bfdMultiplierField; Layout.fillWidth: true; labelText: "BFD Multiplier"; placeholderText: "optional" }
            StandardCheckBox { id: splitCheck; text: "Split Horizon"; checked: true; Layout.alignment: Qt.AlignBottom }
            StandardCheckBox { id: nextHopCheck; text: "Next Hop Self"; checked: false; Layout.alignment: Qt.AlignBottom }
            StandardCheckBox { id: bfdCheck; text: "BFD"; checked: false; Layout.alignment: Qt.AlignBottom }
        }

        RowLayout {
            Layout.fillWidth: true
            StandardButton {
                text: "+ Add Interface"
                type: "Primary"
                onClicked: root.form.addInterfaceSettingToSelectedProcess(ifaceField.text, bandwidthField.text, delayField.text, helloField.text, holdField.text, authField.text, summaryIpField.text, summaryMaskField.text, splitCheck.checked, bwPercentField.text, nextHopCheck.checked, bfdCheck.checked, bfdTxField.text, bfdRxField.text, bfdMultiplierField.text)
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
                required property string bandwidth
                required property string delay
                required property string hello_interval
                required property string hold_time
                required property bool bfd
                required property int index
                Layout.fillWidth: true
                Text { Layout.fillWidth: true; text: interface_name; color: Theme.accentColor; font.family: Theme.fontFamily; elide: Text.ElideRight }
                Text { Layout.fillWidth: true; text: bandwidth ? ("bw " + bandwidth) : ""; color: Theme.textPrimary; font.family: Theme.fontFamily; elide: Text.ElideRight }
                Text { Layout.fillWidth: true; text: delay ? ("delay " + delay) : ""; color: Theme.textPrimary; font.family: Theme.fontFamily; elide: Text.ElideRight }
                Text { Layout.fillWidth: true; text: hello_interval || hold_time ? ("hello/hold " + hello_interval + "/" + hold_time) : ""; color: Theme.textSecondary; font.family: Theme.fontFamily; elide: Text.ElideRight }
                Text { Layout.preferredWidth: 64; text: bfd ? "BFD" : ""; color: Theme.textSecondary; font.family: Theme.fontFamily }
                StandardButton { Layout.preferredWidth: 34; type: "Icon"; icon.source: "qrc:/qt/qml/NetworkTools/resources/devicetabs/close.svg"; tooltip: "Remove interface setting"; onClicked: root.form.removeInterfaceSettingFromSelectedProcess(index) }
            }
        }
    }
}
