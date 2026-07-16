pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import UI

Item {
    id: root
    required property string host
    property string viewName: "portCounters"
    ListModel { id: rowsModel }

    function load() {
        rowsModel.clear()
        const rows = viewName === "macTable"
                   ? dbManager.getSwitchMacTable(host)
                   : dbManager.getSwitchPortCounters(host)
        for (let i = 0; i < rows.length; i++)
            rowsModel.append(rows[i])
    }
    Component.onCompleted: load()
    onHostChanged: load()
    onViewNameChanged: load()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacing16
        spacing: Theme.spacing12

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: root.viewName === "macTable" ? "MAC Table" : "Port Counters"
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeTitle
                font.bold: true
            }
            Item { Layout.fillWidth: true }
            StandardButton {
                text: "Reload"
                icon.source: AppAssets.resource("resources/general/database-reload.svg")
                onClicked: root.load()
            }
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Theme.contentSurface
            border.color: Theme.borderColor
            ListView {
                anchors.fill: parent
                anchors.margins: Theme.spacing8
                model: rowsModel
                spacing: Theme.spacing4
                clip: true
                delegate: Rectangle {
                    id: row
                    required property int index
                    required property var model
                    width: ListView.view.width
                    height: 44
                    color: index % 2 ? Theme.contentPanelSurface : "transparent"
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.spacing12
                        Text { Layout.preferredWidth: 150; text: String(model.if_name || ""); color: Theme.textPrimary; font.family: Theme.fontFamily }
                        Text { Layout.preferredWidth: 160; text: root.viewName === "macTable" ? String(model.mac_addr || "") : "In: " + String(model.in_octets || 0); color: Theme.textPrimary; font.family: Theme.fontFamily }
                        Text { Layout.preferredWidth: 120; text: root.viewName === "macTable" ? "VLAN " + String(model.vlan_id || "") : "Out: " + String(model.out_octets || 0); color: Theme.textSecondary; font.family: Theme.fontFamily }
                        Text { Layout.fillWidth: true; text: root.viewName === "macTable" ? String(model.mac_type || "") : "Errors: " + String((model.in_errors || 0) + (model.out_errors || 0)); color: Theme.textSecondary; font.family: Theme.fontFamily }
                        Text { Layout.preferredWidth: 150; text: root.viewName === "macTable" ? String(model.learned_at || "") : String(model.last_flap || "never"); color: Theme.textSecondary; font.family: Theme.fontFamily }
                    }
                }
                Text {
                    anchors.centerIn: parent
                    visible: rowsModel.count === 0
                    text: "No collected data in SQLite"
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                }
            }
        }
    }
}
