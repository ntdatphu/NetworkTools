pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

Rectangle {
    id: root
    color: Theme.contentBackground

    property var tools: []
    property string selectedApp: ""

    function refreshTools() {
        tools = externalTools.getTools()
    }

    function clearForm() {
        selectedApp = ""
        appName.text = ""
        typeBox.currentIndex = 0
        executable.text = ""
        arguments.text = ""
        enabled.checked = true
        description.text = ""
    }

    function loadTool(tool) {
        selectedApp = tool.app
        appName.text = tool.app
        typeBox.currentIndex = Math.max(0, typeBox.model.indexOf(tool.type))
        executable.text = tool.executable
        arguments.text = tool.arguments || ""
        enabled.checked = tool.enabled === 1
        description.text = tool.description || ""
    }

    Connections {
        target: externalTools
        function onToolsChanged() { root.refreshTools() }
    }

    Component.onCompleted: refreshTools()

    ScrollView {
        id: toolsScroll
        anchors.fill: parent
        clip: true
        contentWidth: availableWidth
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        ColumnLayout {
            width: toolsScroll.availableWidth
            spacing: 16

            Item { Layout.fillWidth: true; Layout.preferredHeight: 8 }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 24
                Layout.rightMargin: 24
                spacing: 12

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text: "External Tools"
                        color: Theme.textPrimary
                        font.pixelSize: Theme.fontSizeLarge
                        font.family: Theme.fontFamily
                        font.weight: Font.Bold
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Manage tools stored in external_tools.db and choose how device_network.db opens."
                        color: Theme.textSecondary
                        font.pixelSize: Theme.fontSizeSmall
                        font.family: Theme.fontFamily
                        wrapMode: Text.WordWrap
                    }
                }

            }

            Text {
                id: message
                Layout.fillWidth: true
                Layout.leftMargin: 24
                Layout.rightMargin: 24
                color: Theme.textSecondary
                font.pixelSize: Theme.fontSizeSmall
                font.family: Theme.fontFamily
                wrapMode: Text.WordWrap
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: 24
                Layout.rightMargin: 24
                Layout.preferredHeight: formLayout.implicitHeight + 24
                color: Theme.searchBackground2
                radius: Theme.borderRadius
                border.width: Theme.borderWidth
                border.color: Theme.borderColor

                ColumnLayout {
                    id: formLayout
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: 12
                        rowSpacing: 10

                        StandardTextField {
                            id: appName
                            Layout.fillWidth: true
                            labelText: "App"
                            placeholderText: "DB Browser for SQLite"
                        }

                        StandardComboBox {
                            id: typeBox
                            Layout.fillWidth: true
                            labelText: "Type"
                            model: externalTools.getToolTypes()
                        }

                        StandardTextField {
                            id: executable
                            Layout.fillWidth: true
                            labelText: "Executable"
                            placeholderText: "C:/Program Files/DB Browser for SQLite/DB Browser for SQLite.exe"
                        }

                        StandardTextField {
                            id: arguments
                            Layout.fillWidth: true
                            labelText: "Arguments"
                            placeholderText: "{db}"
                        }
                    }

                    StandardTextField {
                        id: description
                        Layout.fillWidth: true
                        labelText: "Description"
                        placeholderText: "Optional note"
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        StandardCheckBox {
                            id: enabled
                            text: "Enabled"
                            checked: true
                        }

                        Item { Layout.fillWidth: true }

                        StandardButton {
                            text: "New"
                            type: "Secondary"
                            onClicked: root.clearForm()
                        }

                        StandardButton {
                            text: "Delete"
                            type: "Danger"
                            enabled: root.selectedApp !== ""
                            onClicked: {
                                externalTools.deleteTool(root.selectedApp)
                                root.clearForm()
                                root.refreshTools()
                            }
                        }

                        StandardButton {
                            text: "Save"
                            type: "Primary"
                            onClicked: {
                                const result = externalTools.saveTool(appName.text, typeBox.currentText, executable.text, arguments.text, enabled.checked, description.text)
                                message.text = result.message || ""
                                if (result.ok) {
                                    root.selectedApp = appName.text
                                    root.refreshTools()
                                }
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 24
                Layout.rightMargin: 24
                Layout.preferredHeight: 260
                spacing: 12

                Rectangle {
                    Layout.preferredWidth: 260
                    Layout.fillHeight: true
                    color: Theme.searchBackground2
                    radius: Theme.borderRadius
                    border.width: Theme.borderWidth
                    border.color: Theme.borderColor

                    ListView {
                        anchors.fill: parent
                        anchors.margins: 8
                        clip: true
                        spacing: 6
                        model: root.tools

                        delegate: Rectangle {
                            required property var modelData
                            width: ListView.view.width
                            height: 58
                            radius: Theme.radiusSmall
                            color: root.selectedApp === modelData.app ? Theme.sideBarItemSelected : (toolHover.hovered ? Theme.sideBarItemHover : "transparent")

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 2

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.app
                                    color: Theme.textPrimary
                                    font.pixelSize: Theme.fontSizeNormal
                                    font.family: Theme.fontFamily
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.type + (modelData.enabled === 1 ? " / enabled" : " / disabled")
                                    color: Theme.textSecondary
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.family: Theme.fontFamily
                                    elide: Text.ElideRight
                                }
                            }

                            HoverHandler { id: toolHover }
                            TapHandler { onTapped: root.loadTool(modelData) }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: Theme.searchBackground2
                    radius: Theme.borderRadius
                    border.width: Theme.borderWidth
                    border.color: Theme.borderColor

                    Text {
                        anchors.centerIn: parent
                        visible: root.tools.length === 0
                        text: "No external tools yet."
                        color: Theme.textSecondary
                        font.pixelSize: Theme.fontSizeNormal
                        font.family: Theme.fontFamily
                    }
                }
            }

            Item { Layout.fillWidth: true; Layout.preferredHeight: 8 }
        }
    }
}
