pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

Rectangle {
    id: root
    color: Theme.contentBackground

    property string activeTable: ""
    property var tableData: ({ "columns": [], "rows": [], "message": "" })
    property bool editMode: false
    readonly property var toolsBackend: typeof externalTools !== "undefined" && externalTools !== null
                                        ? externalTools
                                        : null

    function reloadTable() {
        if (toolsBackend === null) {
            tableData = { "columns": [], "rows": [], "message": "Database backend is unavailable." }
            editMode = false
            return
        }
        if (activeTable === "") {
            tableData = { "columns": [], "rows": [], "message": "Select a table." }
            editMode = false
            return
        }
        tableData = toolsBackend.getTableRows(activeTable)
        if (!tableData.editable)
            editMode = false
    }

    function saveCell(rowData, columnName, value) {
        if (toolsBackend === null || !editMode || !tableData.editable || rowData.__rowid__ === undefined)
            return
        const oldValue = rowData[columnName] === undefined || rowData[columnName] === null ? "" : String(rowData[columnName])
        if (oldValue === value)
            return
        const result = toolsBackend.updateTableCell(activeTable, rowData.__rowid__, columnName, value)
        if (result.ok) {
            reloadTable()
        } else {
            tableData = Object.assign({}, tableData, {
                "message": result.message || "Update failed."
            })
        }
    }

    onToolsBackendChanged: reloadTable()
    onActiveTableChanged: reloadTable()
    Component.onCompleted: reloadTable()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                Text {
                    text: root.activeTable !== "" ? root.activeTable : "Database Browser"
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    text: root.tableData.message || "device_network.db"
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            StandardButton {
                text: "View"
                type: root.editMode ? "Secondary" : "Primary"
                onClicked: root.editMode = false
            }

            StandardButton {
                text: "Edit"
                type: root.editMode ? "Primary" : "Secondary"
                enabled: root.tableData.editable === true
                tooltip: root.tableData.editable === true ? "" : "This table cannot be edited with rowid."
                onClicked: root.editMode = true
            }

            StandardButton {
                text: "Reload"
                icon.source: AppAssets.resource("resources/general/database-reload.svg")
                type: "Secondary"
                onClicked: root.reloadTable()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Theme.searchBackground2
            radius: Theme.borderRadius
            border.width: Theme.borderWidth
            border.color: Theme.borderColor
            clip: true

            Text {
                anchors.centerIn: parent
                visible: (root.tableData.columns || []).length === 0
                text: root.activeTable === "" ? "Select a table from the left panel." : "This table has no columns."
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeNormal
            }

            ScrollView {
                id: tableScroll
                anchors.fill: parent
                anchors.margins: 10
                visible: (root.tableData.columns || []).length > 0
                clip: true

                Column {
                    width: Math.max(tableScroll.availableWidth, (root.tableData.columns || []).length * 160)

                    Row {
                        Repeater {
                            model: root.tableData.columns || []

                            delegate: Rectangle {
                                required property string modelData
                                width: 160
                                height: 36
                                color: Theme.contentSurface
                                border.width: Theme.borderWidth
                                border.color: Theme.borderColor

                                Text {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    text: modelData
                                    color: Theme.textPrimary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.DemiBold
                                    verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }

                    ListView {
                        id: tableRows
                        width: parent.width
                        height: Math.max(0, tableScroll.availableHeight - 36)
                        clip: true
                        model: root.tableData.rows || []

                        delegate: Row {
                            required property var modelData
                            property var rowData: modelData

                            Repeater {
                                model: root.tableData.columns || []

                                delegate: Rectangle {
                                    required property string modelData
                                    property string columnName: modelData
                                    width: 160
                                    height: 32
                                    color: "transparent"
                                    border.width: Theme.borderWidth
                                    border.color: Theme.borderColor

                                    Text {
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        text: rowData[columnName] === undefined || rowData[columnName] === null ? "" : String(rowData[columnName])
                                        visible: !root.editMode
                                        color: Theme.textSecondary
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeSmall
                                        verticalAlignment: Text.AlignVCenter
                                        elide: Text.ElideRight
                                    }

                                    TextField {
                                        id: editField
                                        anchors.fill: parent
                                        anchors.margins: 2
                                        visible: root.editMode
                                        text: rowData[columnName] === undefined || rowData[columnName] === null ? "" : String(rowData[columnName])
                                        color: Theme.textPrimary
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeSmall
                                        selectByMouse: true
                                        verticalAlignment: TextInput.AlignVCenter
                                        leftPadding: 6
                                        rightPadding: 6

                                        background: Rectangle {
                                            color: editField.activeFocus ? Theme.inputBackground : "transparent"
                                            border.width: editField.activeFocus ? Theme.borderWidth : 0
                                            border.color: Theme.inputBorderFocusColor
                                            radius: Theme.radiusSmall
                                        }

                                        onAccepted: root.saveCell(rowData, columnName, text)
                                        onEditingFinished: root.saveCell(rowData, columnName, text)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
