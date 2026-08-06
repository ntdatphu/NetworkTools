pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import QtQuick.Controls.Basic
import QtQuick.Dialogs
import QtQuick.Layouts
import QtQuick.Effects
import UI

ApplicationWindow {
    id: root

    objectName: "welcomeWindow"
    visible: true
    title: "Welcome to NetworkTools"
    width: 1080
    height: 680
    minimumWidth: 820
    minimumHeight: 560
    color: Theme.contentBackground

    property string requestedMode: ""
    readonly property var backend:
        typeof welcomeController !== "undefined" ? welcomeController : null
    readonly property var fallbackRecentProjects: [
        {
            "id": "qml-demo-core",
            "name": "Core Lab",
            "path": "~/Documents/Core-Lab.ntp",
            "url": "file:///home/user/Documents/Core-Lab.ntp",
            "openedAtDisplay": "06/08/2026 09:42:00",
            "lastOpened": "Today, 09:42",
            "isMock": true
        },
        {
            "id": "qml-demo-campus",
            "name": "Campus Network",
            "path": "~/Documents/Campus-Network.ntp",
            "url": "file:///home/user/Documents/Campus-Network.ntp",
            "openedAtDisplay": "05/08/2026 16:10:00",
            "lastOpened": "Yesterday",
            "isMock": true
        }
    ]
    readonly property var recentProjects:
        backend !== null ? backend.recentProjects : fallbackRecentProjects
    readonly property var filteredRecentProjects: {
        const query = recentSearch.text.trim().toLowerCase()
        if (query === "")
            return recentProjects
        return recentProjects.filter(function(project) {
            return String(project.name || "").toLowerCase().indexOf(query) !== -1
                    || String(project.path || "").toLowerCase().indexOf(query) !== -1
                    || String(project.url || "").toLowerCase().indexOf(query) !== -1
        })
    }

    function openRequestedMode() {
        const mode = root.requestedMode
        root.requestedMode = ""
        if (mode === "create")
            createProjectDialog.open()
        else if (mode === "open")
            openProjectDialog.open()
        else if (mode === "settings")
            settingsDialog.open()
    }

    function openRecent(projectId) {
        if (root.backend !== null)
            root.backend.openRecent(String(projectId || ""))
    }

    function createProject(projectName, password) {
        if (root.backend !== null)
            root.backend.createProject(projectName, password)
    }

    onRequestedModeChanged: if (requestedMode !== "") Qt.callLater(openRequestedMode)

    Component.onCompleted: {
        ThemeState.backend = typeof themeSettings !== "undefined" ? themeSettings : null
        const available = Screen.desktopAvailableWidth > 0
                          && Screen.desktopAvailableHeight > 0
        if (available) {
            root.x = Screen.virtualX
                     + Math.round((Screen.desktopAvailableWidth - root.width) / 2)
            root.y = Screen.virtualY
                     + Math.round((Screen.desktopAvailableHeight - root.height) / 2)
        }
    }

    OpenProjectFileDialog {
        id: openProjectDialog
        onProjectSelected: function(projectUrl) {
            if (root.backend !== null)
                root.backend.openProject(projectUrl)
        }
    }

    CreateProjectDialog {
        id: createProjectDialog
        onCreateRequested: (projectName, password) => root.createProject(projectName, password)
    }

    WorkspacePasswordDialog {
        id: workspacePasswordDialog
        onUnlockRequested: password => {
            if (root.backend !== null)
                root.backend.unlockProject(password)
        }
    }

    MessageDialog {
        id: workspaceErrorDialog
        title: "NetworkTools"
        text: ""
        buttons: MessageDialog.Ok
    }

    Connections {
        target: root.backend
        enabled: root.backend !== null

        function onPasswordRequired(projectPath) {
            workspacePasswordDialog.projectPath = projectPath
            workspacePasswordDialog.open()
        }

        function onOperationFailed(title, message) {
            if (workspacePasswordDialog.opened && title === "Open Project") {
                workspacePasswordDialog.errorMessage = message
                return
            }
            workspaceErrorDialog.title = title
            workspaceErrorDialog.text = message
            workspaceErrorDialog.open()
        }

        function onWorkspaceRequested() {
            workspacePasswordDialog.accept()
        }
    }

    WelcomeSettingsDialog {
        id: settingsDialog
    }

    background: Rectangle {
        color: Theme.contentBackground
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.preferredWidth: Math.max(300, root.width * 0.31)
            Layout.fillHeight: true
            color: Theme.sideBarBackground
            border.color: Theme.borderColor
            border.width: Theme.borderWidth

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacing32
                spacing: Theme.spacing16

                Item { Layout.fillHeight: true }

                ThemedIcon {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 112
                    Layout.preferredHeight: 112
                    iconSource: AppAssets.brandLogo
                    iconSize: 112
                    preserveOriginalColors: true
                }

                Text {
                    Layout.fillWidth: true
                    text: "NetworkTools"
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeDisplay
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    Layout.fillWidth: true
                    text: "Design, inspect, and operate network workspaces from one desktop application."
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeNormal
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }

                Item { Layout.fillHeight: true }

                Text {
                    Layout.fillWidth: true
                    text: "NetworkTools 0.1"
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeCaption
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacing32
                spacing: Theme.spacing24

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacing4

                    Text {
                        text: "Welcome"
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeDisplay
                        font.bold: true
                    }

                    Text {
                        text: "Choose a project to continue"
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLarge
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacing12

                    WelcomeActionCard {
                        objectName: "welcomeCreateProjectButton"
                        Layout.fillWidth: true
                        actionIcon: AppAssets.actionAdd
                        titleText: "Create New"
                        descriptionText: "Start a new .ntp workspace"
                        onClicked: createProjectDialog.open()
                    }

                    WelcomeActionCard {
                        objectName: "welcomeOpenProjectButton"
                        Layout.fillWidth: true
                        actionIcon: AppAssets.fileFolder
                        titleText: "Open"
                        descriptionText: "Open a NetworkTools project"
                        onClicked: openProjectDialog.open()
                    }

                    WelcomeActionCard {
                        objectName: "welcomeSettingsButton"
                        Layout.fillWidth: true
                        actionIcon: AppAssets.navigationSettings
                        titleText: "Settings"
                        descriptionText: "Configure global appearance"
                        onClicked: settingsDialog.open()
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: Theme.contentPanelSurface
                    border.color: Theme.contentPanelBorder
                    border.width: Theme.borderWidth
                    radius: Theme.radiusLarge

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.spacing16
                        spacing: Theme.spacing12

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacing12

                            Text {
                                Layout.fillWidth: true
                                text: "Recent Projects"
                                color: Theme.textPrimary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeTitle
                                font.bold: true
                            }

                            StandardTextField {
                                id: recentSearch
                                objectName: "welcomeRecentSearch"
                                Layout.preferredWidth: 250
                                placeholderText: "Search projects"
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Theme.borderWidth
                            color: Theme.contentPanelBorder
                        }

                        ListView {
                            id: recentProjectList
                            objectName: "welcomeRecentProjectList"
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: Theme.spacing4
                            model: root.filteredRecentProjects
                            keyNavigationEnabled: true

                            delegate: RecentProjectDelegate {
                                required property var modelData
                                required property int index
                                width: recentProjectList.width
                                projectName: String(modelData.name || "")
                                projectPath: String(modelData.path || "")
                                projectUrl: String(modelData.url || modelData.path || "")
                                openedAt: String(modelData.openedAtDisplay
                                                 || modelData.lastOpened || "")
                                mockProject: modelData.isMock === true
                                onClicked: root.openRecent(modelData.id)
                                onRemoveClicked: if (root.backend !== null) root.backend.removeRecent(modelData.id)
                                Keys.onReturnPressed: clicked()
                                Keys.onEnterPressed: clicked()
                            }

                            ScrollBar.vertical: ScrollBar {}
                        }

                        Text {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            visible: root.filteredRecentProjects.length === 0
                            text: recentSearch.text.trim() === ""
                                  ? "No recent projects"
                                  : "No projects match your search"
                            color: Theme.textDisabled
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeNormal
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }
        }
    }
}
