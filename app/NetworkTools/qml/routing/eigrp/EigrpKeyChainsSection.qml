pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import NetworkTools

Rectangle {
    id: root
    required property var form

    visible: String(form.currentHostIp || "").trim() !== ""
        && form.activeRoutingSection === "Key chains"
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

        Text { text: "EIGRP KEY CHAINS"; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeLarge; font.family: Theme.fontFamily; font.bold: true }

        GridLayout {
            Layout.fillWidth: true
            columns: width < 760 ? 2 : 4
            columnSpacing: Theme.spacing12
            rowSpacing: Theme.spacing8
            StandardComboBox { Layout.fillWidth: true; labelText: "EIGRP Process"; model: root.form.processOptions; currentIndex: root.form.selectedNetworkProcessIndex; onCurrentIndexChanged: if (currentIndex >= 0) root.form.selectedNetworkProcessIndex = currentIndex }
            StandardTextField { id: chainField; Layout.fillWidth: true; labelText: "Chain Name"; placeholderText: "KC_EIGRP" }
            StandardTextField { id: keyIdField; Layout.fillWidth: true; labelText: "Key ID"; placeholderText: "1" }
            StandardTextField { id: keyStringField; Layout.fillWidth: true; labelText: "Key String"; placeholderText: "secret" }
            StandardTextField { id: acceptField; Layout.fillWidth: true; labelText: "Accept Lifetime"; placeholderText: "optional" }
            StandardTextField { id: sendField; Layout.fillWidth: true; labelText: "Send Lifetime"; placeholderText: "optional" }
        }

        RowLayout {
            Layout.fillWidth: true
            StandardButton {
                text: "+ Add Key"
                type: "Primary"
                onClicked: {
                    if (root.form.addKeyChainToSelectedProcess(chainField.text, keyIdField.text, keyStringField.text, acceptField.text, sendField.text)) {
                        chainField.clear()
                        keyIdField.clear()
                        keyStringField.clear()
                        acceptField.clear()
                        sendField.clear()
                    }
                }
            }
            Item { Layout.fillWidth: true }
        }

        Repeater {
            model: {
                const revision = root.form.statsRevision
                const item = root.form.selectedProcessItem()
                return item ? item.keyChains : null
            }
            delegate: RowLayout {
                required property string chain_name
                required property string key_id
                required property string key_string
                required property string accept_lifetime
                required property string send_lifetime
                required property int index
                Layout.fillWidth: true
                Text { Layout.fillWidth: true; text: chain_name; color: Theme.accentColor; font.family: Theme.fontFamily }
                Text { Layout.preferredWidth: 80; text: "key " + key_id; color: Theme.textPrimary; font.family: Theme.fontFamily }
                Text { Layout.fillWidth: true; text: key_string; color: Theme.textSecondary; font.family: Theme.fontFamily; elide: Text.ElideRight }
                Text { Layout.fillWidth: true; text: accept_lifetime; color: Theme.textSecondary; font.family: Theme.fontFamily; elide: Text.ElideRight }
                Text { Layout.fillWidth: true; text: send_lifetime; color: Theme.textSecondary; font.family: Theme.fontFamily; elide: Text.ElideRight }
                StandardButton { Layout.preferredWidth: 34; type: "Icon"; icon.source: AppAssets.resource("resources/devicetabs/close.svg"); tooltip: "Remove key chain"; onClicked: root.form.removeKeyChainFromSelectedProcess(index) }
            }
        }
    }
}
