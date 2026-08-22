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

    function displayValue(value) {
        return value === undefined || value === null ? "" : String(value)
    }

    function refreshFields() {
        const item = form.selectedProcessItem()
        const values = item && item.distance ? item.distance : ({})
        externalField.text = displayValue(values.external)
        intraField.text = displayValue(values.intra_area)
        interField.text = displayValue(values.inter_area)
    }

    Component.onCompleted: Qt.callLater(refreshFields)

    Connections {
        target: root.form
        function onSelectedNetworkProcessIndexChanged() { root.refreshFields() }
        function onStatsRevisionChanged() {
            if (!externalField.activeFocus && !intraField.activeFocus && !interField.activeFocus)
                root.refreshFields()
        }
    }

    ColumnLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: Theme.spacing16
        spacing: Theme.spacing12

        SectionTitle { text: "OSPF DISTANCE" }

        GridLayout {
            Layout.fillWidth: true
            columns: width < 760 ? 2 : 5
            columnSpacing: Theme.spacing12
            rowSpacing: Theme.spacing8

            RoutingProcessComboBox { form: root.form; protocol: "OSPF" }
            StandardTextField { id: externalField; objectName: "ospfDistanceExternalField"; Layout.fillWidth: true; labelText: "External"; placeholderText: "110" }
            StandardTextField { id: intraField; objectName: "ospfDistanceIntraField"; Layout.fillWidth: true; labelText: "Intra-area"; placeholderText: "110" }
            StandardTextField { id: interField; objectName: "ospfDistanceInterField"; Layout.fillWidth: true; labelText: "Inter-area"; placeholderText: "110" }
            StandardButton {
                text: "Apply"
                type: "Primary"
                Layout.alignment: Qt.AlignBottom
                onClicked: root.form.setDistanceForSelectedProcess(externalField.text, intraField.text, interField.text)
            }
        }
    }
}
