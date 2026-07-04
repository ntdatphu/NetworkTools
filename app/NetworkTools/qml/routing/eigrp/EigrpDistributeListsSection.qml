pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import NetworkTools

Rectangle {
    id: root
    required property var form

    visible: String(form.currentHostIp || "").trim() !== ""
        && form.activeRoutingSection === "Distribute list"
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

        Text { text: "EIGRP DISTRIBUTE LISTS"; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeLarge; font.family: Theme.fontFamily; font.bold: true }

        GridLayout {
            Layout.fillWidth: true
            columns: width < 760 ? 2 : 4
            columnSpacing: Theme.spacing12
            rowSpacing: Theme.spacing8
            StandardComboBox { Layout.fillWidth: true; labelText: "EIGRP Process"; model: root.form.processOptions; currentIndex: root.form.selectedNetworkProcessIndex; onCurrentIndexChanged: if (currentIndex >= 0) root.form.selectedNetworkProcessIndex = currentIndex }
            StandardTextField { id: nameField; Layout.fillWidth: true; labelText: "List Name"; placeholderText: "ACL_OR_PREFIX" }
            StandardComboBox { id: directionCombo; Layout.fillWidth: true; labelText: "Direction"; model: ["in", "out"] }
            StandardTextField { id: ifaceField; Layout.fillWidth: true; labelText: "Interface"; placeholderText: "optional" }
        }

        RowLayout {
            Layout.fillWidth: true
            StandardButton {
                text: "+ Add Distribute List"
                type: "Primary"
                onClicked: {
                    if (root.form.addDistributeListToSelectedProcess(nameField.text, directionCombo.currentText, ifaceField.text)) {
                        nameField.clear()
                        ifaceField.clear()
                    }
                }
            }
            Item { Layout.fillWidth: true }
        }

        Repeater {
            model: {
                const revision = root.form.statsRevision
                const item = root.form.selectedProcessItem()
                return item ? item.distributeLists : null
            }
            delegate: RowLayout {
                required property string list_name
                required property string direction
                required property string interface_name
                required property int index
                Layout.fillWidth: true
                Text { Layout.fillWidth: true; text: list_name; color: Theme.accentColor; font.family: Theme.fontFamily }
                Text { Layout.fillWidth: true; text: direction; color: Theme.textPrimary; font.family: Theme.fontFamily }
                Text { Layout.fillWidth: true; text: interface_name; color: Theme.textSecondary; font.family: Theme.fontFamily }
                StandardButton { Layout.preferredWidth: 34; type: "Icon"; icon.source: AppPaths.resource("resources/devicetabs/close.svg"); tooltip: "Remove distribute list"; onClicked: root.form.removeDistributeListFromSelectedProcess(index) }
            }
        }
    }
}
