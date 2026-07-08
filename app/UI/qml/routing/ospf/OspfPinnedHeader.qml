pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import UI

ColumnLayout {
    id: root
    spacing: Theme.spacing12

    required property var form

    component SectionTab: SegmentTab {
        minWidth: 92
        idleBorderColor: Theme.borderColor
    }

    GridLayout {
        visible: String(root.form.currentHostIp || "").trim() !== ""
        Layout.fillWidth: true
        Layout.leftMargin: 24
        Layout.rightMargin: 24
        Layout.topMargin: 6
        columns: width < 760 ? 2 : 4
        columnSpacing: Theme.spacing12
        rowSpacing: Theme.spacing12

        Repeater {
            model: [
                { label: qsTr("OSPF PROCESS"), value: String(root.form.processCount), detail: qsTr("active cards"), accent: false },
                { label: qsTr("NETWORKS"), value: String(root.form.totalNetworkCount()), detail: qsTr("advertised entries"), accent: true },
                { label: qsTr("HOST"), value: root.form.currentHostIp, detail: qsTr("selected device"), accent: false },
                { label: qsTr("STATE"), value: root.form.hasPendingLocalChanges ? qsTr("DIRTY") : qsTr("SYNC"), detail: root.form.hasPendingLocalChanges ? qsTr("pending save") : qsTr("database"), state: true }
            ]

            delegate: Rectangle {
                required property var modelData

                Layout.fillWidth: true
                implicitHeight: 76
                radius: Theme.cardRadius
                color: modelData.state
                    ? (root.form.hasPendingLocalChanges ? Theme.alertWarningSubtle : Theme.alertSuccessSubtle)
                    : Theme.contentPanelSurface
                border.color: modelData.state
                    ? (root.form.hasPendingLocalChanges ? Theme.alertWarning : Theme.alertSuccess)
                    : Theme.contentPanelBorder
                border.width: Theme.borderWidth

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacing12
                    spacing: Theme.spacing2

                    Text {
                        text: modelData.label
                        color: Theme.textSecondary
                        font.pixelSize: Theme.fontSizeSmall
                        font.family: Theme.fontFamily
                        font.bold: true
                    }

                    Text {
                        Layout.fillWidth: true
                        text: modelData.value
                        color: modelData.state
                            ? (root.form.hasPendingLocalChanges ? Theme.alertWarning : Theme.alertSuccess)
                            : (modelData.accent ? Theme.accentColor : Theme.textPrimary)
                        font.pixelSize: Theme.fontSizeTitle
                        font.family: Theme.fontFamily
                        font.bold: true
                        elide: Text.ElideRight
                    }

                    Text {
                        text: modelData.detail
                        color: Theme.textDisabled
                        font.pixelSize: Theme.fontSizeSmall
                        font.family: Theme.fontFamily
                    }
                }
            }
        }
    }

    RowLayout {
        visible: String(root.form.currentHostIp || "").trim() !== ""
        Layout.fillWidth: true
        Layout.leftMargin: 24
        Layout.rightMargin: 24
        Layout.bottomMargin: Theme.spacing12
        spacing: Theme.spacing4

        SectionTab { label: qsTr("Process"); selected: root.form.activeRoutingSection === "Process"; onClicked: root.form.selectRoutingSection("Process") }
        SectionTab { label: qsTr("Networks"); selected: root.form.activeRoutingSection === "Networks"; onClicked: root.form.selectRoutingSection("Networks") }
        SectionTab { label: qsTr("Areas"); selected: root.form.activeRoutingSection === "Areas"; onClicked: root.form.selectRoutingSection("Areas") }
        SectionTab { label: qsTr("Distance"); selected: root.form.activeRoutingSection === "Distance"; onClicked: root.form.selectRoutingSection("Distance") }
        SectionTab { label: qsTr("Redistribute"); selected: root.form.activeRoutingSection === "Redistribute"; onClicked: root.form.selectRoutingSection("Redistribute") }
        SectionTab { label: qsTr("Interfaces"); selected: root.form.activeRoutingSection === "Interfaces"; onClicked: root.form.selectRoutingSection("Interfaces") }
        SectionTab { label: qsTr("Passive iface"); selected: root.form.activeRoutingSection === "Passive iface"; onClicked: root.form.selectRoutingSection("Passive iface") }
        SectionTab { label: qsTr("Tuning"); selected: root.form.activeRoutingSection === "Tuning"; onClicked: root.form.selectRoutingSection("Tuning") }
        Item { Layout.fillWidth: true }
    }
}
