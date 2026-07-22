pragma ComponentBehavior: Bound

import QtQuick
import UI

Column {
    id: root
    objectName: "databaseTableSection"

    property string groupKey: ""
    property string sectionTitle: ""
    property url groupIcon: AppAssets.fileTypeDatabase
    property color groupColor: Theme.panelSideBarTextSecondary
    property var tables: []
    property string selectedTable: ""
    property bool expanded: true

    signal tableClicked(string tableName)
    signal expansionChanged(bool expanded)

    visible: tables.length > 0

    Rectangle {
        width: root.width
        height: Theme.listItemHeight
        color: headerHover.hovered ? Theme.panelSideBarItemHover : "transparent"

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            ThemedIcon {
                anchors.verticalCenter: parent.verticalCenter
                iconSource: root.expanded
                            ? AppAssets.navigationChevronDown
                            : AppAssets.navigationChevronRight
                iconSize: Theme.iconSizeSmall
                iconColor: Theme.panelSideBarTextSecondary
            }

            ThemedIcon {
                anchors.verticalCenter: parent.verticalCenter
                iconSource: root.groupIcon
                iconSize: 14
                iconColor: root.groupColor
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.sectionTitle + " (" + root.tables.length + ")"
                color: Theme.panelSideBarTextSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                font.capitalization: Font.AllUppercase
                font.weight: Font.Medium
            }
        }

        HoverHandler { id: headerHover }
        TapHandler {
            onTapped: {
                root.expanded = !root.expanded
                root.expansionChanged(root.expanded)
            }
        }
    }

    Column {
        width: root.width
        visible: root.expanded

        Repeater {
            model: root.tables

            delegate: DatabaseTableItem {
                required property int index
                required property string modelData

                width: root.width
                tableName: modelData
                groupKey: root.groupKey
                domainIcon: root.groupIcon
                domainColor: root.groupColor
                isSelected: root.selectedTable === modelData
                onClicked: root.tableClicked(tableName)
            }
        }
    }
}
