pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

ItemDelegate {
    id: root

    property string projectName: ""
    property string projectPath: ""
    property string lastOpened: ""
    property bool mockProject: false

    Accessible.role: Accessible.ListItem
    Accessible.name: projectName
    Accessible.description: projectPath
    focusPolicy: Qt.StrongFocus

    implicitHeight: 70
    padding: Theme.spacing12

    HoverHandler {
        id: hoverHandler
        cursorShape: Qt.PointingHandCursor
    }

    background: Rectangle {
        radius: Theme.radiusSmall
        color: root.down
               ? Theme.sideBarItemSelected
               : (hoverHandler.hovered ? Theme.sideBarItemHover : "transparent")
        border.color: root.visualFocus ? Theme.accentColor : "transparent"
        border.width: root.visualFocus ? 2 : 0
    }

    contentItem: RowLayout {
        spacing: Theme.spacing12

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing2

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacing8

                Text {
                    Layout.fillWidth: true
                    text: root.projectName
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeNormal
                    font.bold: true
                    elide: Text.ElideRight
                }

                Text {
                    visible: root.mockProject
                    text: "DEMO"
                    color: Theme.notificationInfoAccent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeCaption
                    font.bold: true
                }

                Text {
                    text: root.lastOpened
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeCaption
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.projectPath
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideMiddle
            }
        }

        ThemedIcon {
            Layout.preferredWidth: Theme.iconSizeSmall
            Layout.preferredHeight: Theme.iconSizeSmall
            iconSource: AppAssets.navigationChevronRight
            iconSize: Theme.iconSizeSmall
            iconColor: hoverHandler.hovered ? Theme.textPrimary : Theme.textSecondary
        }
    }
}
