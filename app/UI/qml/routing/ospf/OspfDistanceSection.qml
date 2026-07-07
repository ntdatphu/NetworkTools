pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import UI

Rectangle {
    id: root

    required property var form

    visible: String(form.currentHostIp || "").trim() !== ""
        && form.activeRoutingSection === "Distance"
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

        Text { text: "OSPF DISTANCE"; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeLarge; font.family: Theme.fontFamily; font.bold: true }

        GridLayout {
            Layout.fillWidth: true
            columns: width < 760 ? 2 : 5
            columnSpacing: Theme.spacing12
            rowSpacing: Theme.spacing8

            StandardComboBox {
                Layout.fillWidth: true
                labelText: "OSPF Process"
                model: root.form.processOptions
                currentIndex: root.form.selectedNetworkProcessIndex
                onCurrentIndexChanged: if (currentIndex >= 0) root.form.selectedNetworkProcessIndex = currentIndex
            }
            StandardTextField { id: externalField; Layout.fillWidth: true; labelText: "External"; placeholderText: "110" }
            StandardTextField { id: intraField; Layout.fillWidth: true; labelText: "Intra-area"; placeholderText: "110" }
            StandardTextField { id: interField; Layout.fillWidth: true; labelText: "Inter-area"; placeholderText: "110" }
            StandardButton {
                text: "Apply"
                type: "Primary"
                Layout.alignment: Qt.AlignBottom
                onClicked: root.form.setDistanceForSelectedProcess(externalField.text, intraField.text, interField.text)
            }
        }
    }
}
