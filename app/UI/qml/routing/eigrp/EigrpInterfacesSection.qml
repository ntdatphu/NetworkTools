pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import UI

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

        SectionTitle { text: qsTr("EIGRP INTERFACE SETTINGS") }

        GridLayout {
            Layout.fillWidth: true
            columns: width < 760 ? 2 : 4
            columnSpacing: Theme.spacing12
            rowSpacing: Theme.spacing8

            RoutingProcessComboBox { form: root.form; protocol: "EIGRP" }
            StandardTextField { id: ifaceField; Layout.fillWidth: true; labelText: qsTr("Interface"); placeholderText: qsTr("GigabitEthernet0/0") }
            StandardTextField { id: bandwidthField; Layout.fillWidth: true; labelText: qsTr("Bandwidth"); placeholderText: qsTr("optional") }
            StandardTextField { id: delayField; Layout.fillWidth: true; labelText: qsTr("Delay"); placeholderText: qsTr("optional") }
            StandardTextField { id: helloField; Layout.fillWidth: true; labelText: qsTr("Hello"); placeholderText: qsTr("optional") }
            StandardTextField { id: holdField; Layout.fillWidth: true; labelText: qsTr("Hold"); placeholderText: qsTr("optional") }
            StandardTextField { id: authField; Layout.fillWidth: true; labelText: qsTr("Auth Key Chain"); placeholderText: qsTr("optional") }
            StandardTextField { id: summaryIpField; Layout.fillWidth: true; labelText: qsTr("Summary IP"); placeholderText: qsTr("optional") }
            StandardTextField { id: summaryMaskField; Layout.fillWidth: true; labelText: qsTr("Summary Mask"); placeholderText: qsTr("optional") }
            StandardTextField { id: bwPercentField; Layout.fillWidth: true; labelText: qsTr("BW Percent"); placeholderText: qsTr("optional") }
            StandardTextField { id: bfdTxField; Layout.fillWidth: true; labelText: qsTr("BFD TX"); placeholderText: qsTr("optional") }
            StandardTextField { id: bfdRxField; Layout.fillWidth: true; labelText: qsTr("BFD RX"); placeholderText: qsTr("optional") }
            StandardTextField { id: bfdMultiplierField; Layout.fillWidth: true; labelText: qsTr("BFD Multiplier"); placeholderText: qsTr("optional") }
            StandardCheckBox { id: splitCheck; text: qsTr("Split Horizon"); checked: true; Layout.alignment: Qt.AlignBottom }
            StandardCheckBox { id: nextHopCheck; text: qsTr("Next Hop Self"); checked: false; Layout.alignment: Qt.AlignBottom }
            StandardCheckBox { id: bfdCheck; text: qsTr("BFD"); checked: false; Layout.alignment: Qt.AlignBottom }
        }

        RowLayout {
            Layout.fillWidth: true
            StandardButton {
                text: qsTr("+ Add Interface")
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
                Text { Layout.fillWidth: true; text: bandwidth ? (qsTr("bw ") + bandwidth) : ""; color: Theme.textPrimary; font.family: Theme.fontFamily; elide: Text.ElideRight }
                Text { Layout.fillWidth: true; text: delay ? (qsTr("delay ") + delay) : ""; color: Theme.textPrimary; font.family: Theme.fontFamily; elide: Text.ElideRight }
                Text { Layout.fillWidth: true; text: hello_interval || hold_time ? (qsTr("hello/hold ") + hello_interval + "/" + hold_time) : ""; color: Theme.textSecondary; font.family: Theme.fontFamily; elide: Text.ElideRight }
                Text { Layout.preferredWidth: 64; text: bfd ? qsTr("BFD") : ""; color: Theme.textSecondary; font.family: Theme.fontFamily }
                RemoveIconButton { tooltip: qsTr("Remove interface setting"); onClicked: root.form.removeInterfaceSettingFromSelectedProcess(index) }
            }
        }
    }
}
