pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import UI

Rectangle {
    id: root

    required property var form

    visible: String(form.currentHostIp || "").trim() !== ""
        && form.activeRoutingSection === "Tuning"
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

        SectionTitle { text: qsTr("OSPF TUNING") }

        GridLayout {
            Layout.fillWidth: true
            columns: width < 860 ? 2 : 5
            columnSpacing: Theme.spacing12
            rowSpacing: Theme.spacing8

            RoutingProcessComboBox { form: root.form; protocol: "OSPF" }
            StandardTextField { id: maxPathsField; Layout.fillWidth: true; labelText: qsTr("Max paths"); placeholderText: qsTr("optional") }
            StandardTextField { id: maxLsaField; Layout.fillWidth: true; labelText: qsTr("Max LSA"); placeholderText: qsTr("optional") }
            StandardTextField { id: spfDelayField; Layout.fillWidth: true; labelText: qsTr("SPF delay"); placeholderText: qsTr("optional") }
            StandardTextField { id: spfMinField; Layout.fillWidth: true; labelText: qsTr("SPF min"); placeholderText: qsTr("optional") }
            StandardTextField { id: spfMaxField; Layout.fillWidth: true; labelText: qsTr("SPF max"); placeholderText: qsTr("optional") }
            StandardTextField { id: lsaDelayField; Layout.fillWidth: true; labelText: qsTr("LSA delay"); placeholderText: qsTr("optional") }
            StandardTextField { id: lsaMinField; Layout.fillWidth: true; labelText: qsTr("LSA min"); placeholderText: qsTr("optional") }
            StandardTextField { id: lsaMaxField; Layout.fillWidth: true; labelText: qsTr("LSA max"); placeholderText: qsTr("optional") }
            StandardButton {
                text: qsTr("Apply")
                type: "Primary"
                Layout.alignment: Qt.AlignBottom
                onClicked: root.form.setTuningForSelectedProcess(maxPathsField.text, maxLsaField.text, spfDelayField.text, spfMinField.text, spfMaxField.text, lsaDelayField.text, lsaMinField.text, lsaMaxField.text)
            }
        }
    }
}
