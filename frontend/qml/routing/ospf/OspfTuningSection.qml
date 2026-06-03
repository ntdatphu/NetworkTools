pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import NetworkTools

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

        Text { text: "OSPF TUNING"; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeLarge; font.family: Theme.fontFamily; font.bold: true }

        GridLayout {
            Layout.fillWidth: true
            columns: width < 860 ? 2 : 5
            columnSpacing: Theme.spacing12
            rowSpacing: Theme.spacing8

            StandardComboBox { Layout.fillWidth: true; labelText: "OSPF Process"; model: root.form.processOptions; currentIndex: root.form.selectedNetworkProcessIndex; onCurrentIndexChanged: if (currentIndex >= 0) root.form.selectedNetworkProcessIndex = currentIndex }
            StandardTextField { id: maxPathsField; Layout.fillWidth: true; labelText: "Max paths"; placeholderText: "optional" }
            StandardTextField { id: maxLsaField; Layout.fillWidth: true; labelText: "Max LSA"; placeholderText: "optional" }
            StandardTextField { id: spfDelayField; Layout.fillWidth: true; labelText: "SPF delay"; placeholderText: "optional" }
            StandardTextField { id: spfMinField; Layout.fillWidth: true; labelText: "SPF min"; placeholderText: "optional" }
            StandardTextField { id: spfMaxField; Layout.fillWidth: true; labelText: "SPF max"; placeholderText: "optional" }
            StandardTextField { id: lsaDelayField; Layout.fillWidth: true; labelText: "LSA delay"; placeholderText: "optional" }
            StandardTextField { id: lsaMinField; Layout.fillWidth: true; labelText: "LSA min"; placeholderText: "optional" }
            StandardTextField { id: lsaMaxField; Layout.fillWidth: true; labelText: "LSA max"; placeholderText: "optional" }
            StandardButton {
                text: "Apply"
                type: "Primary"
                Layout.alignment: Qt.AlignBottom
                onClicked: root.form.setTuningForSelectedProcess(maxPathsField.text, maxLsaField.text, spfDelayField.text, spfMinField.text, spfMaxField.text, lsaDelayField.text, lsaMinField.text, lsaMaxField.text)
            }
        }
    }
}
