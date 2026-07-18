pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import UI

Item {
    id: root

    signal tableSelected(string tableName)

    property var tables: []
    property var filteredTables: []
    property string selectedTable: ""
    readonly property var toolsBackend: typeof externalTools !== "undefined" && externalTools !== null
                                        ? externalTools
                                        : null

    function reloadTables() {
        if (toolsBackend === null) {
            tables = []
            filteredTables = []
            selectedTable = ""
            return
        }
        tables = toolsBackend.getDatabaseTables()
        applyFilter()
        if (selectedTable === "" || tables.indexOf(selectedTable) === -1)
            selectedTable = tables.length > 0 ? tables[0] : ""
    }

    function applyFilter() {
        const q = searchBar.text.toLowerCase().trim()
        if (q === "") {
            filteredTables = tables
            return
        }
        filteredTables = tables.filter(function(tableName) {
            return tableName.toLowerCase().indexOf(q) !== -1
        })
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.panelSideBarBackground
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            color: Theme.panelSideBarBackground

            Text {
                anchors.fill: parent
                anchors.leftMargin: 16
                verticalAlignment: Text.AlignVCenter
                text: "DATABASE"
                color: Theme.panelSideBarTextSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                font.capitalization: Font.AllUppercase
                font.weight: Font.Medium
            }

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: Theme.borderWidth
                color: Theme.panelSideBarBorderColor
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 8
            spacing: 8

            Text {
                Layout.fillWidth: true
                text: "Tables"
                color: Theme.panelSideBarTextPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeNormal
                font.weight: Font.Medium
            }

            StandardButton {
                type: "Icon"
                icon.source: AppAssets.actionRefresh
                tooltip: "Reload tables"
                enabled: root.toolsBackend !== null
                onClicked: root.reloadTables()
            }
        }

        SideBarSearch {
            id: searchBar
            Layout.fillWidth: true
            Layout.leftMargin: 8
            Layout.rightMargin: 8
            Layout.bottomMargin: 8
            placeholderText: "Search tables..."
            onTextChanged: root.applyFilter()
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.policy: ScrollBar.AsNeeded

            ColumnLayout {
                width: parent.width
                spacing: 6

                Repeater {
                    model: root.filteredTables

                    delegate: Rectangle {
                        required property string modelData

                        Layout.fillWidth: true
                        Layout.leftMargin: 8
                        Layout.rightMargin: 8
                        implicitHeight: 38
                        radius: Theme.borderRadius
                        color: root.selectedTable === modelData
                               ? Theme.panelSideBarItemSelected
                               : (tableHover.hovered ? Theme.panelSideBarItemHover : "transparent")

                        Text {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            verticalAlignment: Text.AlignVCenter
                            text: modelData
                            color: Theme.panelSideBarTextPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            elide: Text.ElideRight
                        }

                        HoverHandler { id: tableHover }
                        TapHandler {
                            onTapped: root.selectedTable = modelData
                        }
                    }
                }

                Text {
                    visible: root.filteredTables.length === 0
                    text: root.tables.length === 0 ? "No tables found." : "No matching tables."
                    color: Theme.panelSideBarTextSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    Layout.leftMargin: 12
                    Layout.rightMargin: 12
                }
            }
        }
    }

    Connections {
        target: root.toolsBackend
        function onBrowserChanged() { root.reloadTables() }
    }

    onToolsBackendChanged: reloadTables()
    onSelectedTableChanged: if (selectedTable !== "") tableSelected(selectedTable)

    Component.onCompleted: {
        reloadTables()
        if (selectedTable !== "")
            tableSelected(selectedTable)
    }
}
