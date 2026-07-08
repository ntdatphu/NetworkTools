pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import UI

Rectangle {
    id: root
    required property var form

    visible: String(form.currentHostIp || "").trim() !== ""
        && form.activeRoutingSection === "Offset list"
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

        SectionTitle { text: qsTr("EIGRP OFFSET LISTS") }

        GridLayout {
            Layout.fillWidth: true
            columns: width < 760 ? 2 : 5
            columnSpacing: Theme.spacing12
            rowSpacing: Theme.spacing8
            RoutingProcessComboBox { form: root.form; protocol: "EIGRP" }
            StandardTextField { id: nameField; Layout.fillWidth: true; labelText: qsTr("List Name"); placeholderText: qsTr("ACL_OR_PREFIX") }
            StandardComboBox { id: directionCombo; Layout.fillWidth: true; labelText: qsTr("Direction"); model: [qsTr("In"), qsTr("Out")]; valueModel: ["in", "out"] }
            StandardTextField { id: valueField; Layout.fillWidth: true; labelText: qsTr("Offset"); placeholderText: "10" }
            StandardTextField { id: ifaceField; Layout.fillWidth: true; labelText: qsTr("Interface"); placeholderText: qsTr("optional") }
        }

        RowLayout {
            Layout.fillWidth: true
            StandardButton {
                text: qsTr("+ Add Offset List")
                type: "Primary"
                onClicked: {
                    if (root.form.addOffsetListToSelectedProcess(nameField.text, directionCombo.currentValue, valueField.text, ifaceField.text)) {
                        nameField.clear()
                        valueField.clear()
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
                return item ? item.offsetLists : null
            }
            delegate: RowLayout {
                required property string list_name
                required property string direction
                required property string value
                required property string interface_name
                required property int index
                Layout.fillWidth: true
                Text { Layout.fillWidth: true; text: list_name; color: Theme.accentColor; font.family: Theme.fontFamily }
                Text { Layout.fillWidth: true; text: direction; color: Theme.textPrimary; font.family: Theme.fontFamily }
                Text { Layout.fillWidth: true; text: qsTr("offset ") + value; color: Theme.textPrimary; font.family: Theme.fontFamily }
                Text { Layout.fillWidth: true; text: interface_name; color: Theme.textSecondary; font.family: Theme.fontFamily }
                RemoveIconButton { tooltip: qsTr("Remove offset list"); onClicked: root.form.removeOffsetListFromSelectedProcess(index) }
            }
        }
    }
}
