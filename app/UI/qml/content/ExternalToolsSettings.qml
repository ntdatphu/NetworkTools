pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Dialogs
import QtQuick.Layouts
import UI

Rectangle {
    id: root
    objectName: "externalToolsSettings"
    color: Theme.contentBackground

    property var tools: []
    property var discoveredTools: []
    property var toolTypes: []
    property var displayRows: []
    property var selectedCandidate: null
    property var pathValidation: ({
        "ok": false,
        "exists": false,
        "path": "",
        "message": "Choose an executable to continue."
    })

    property string selectedApp: ""
    property string selectedKey: ""
    property string editorMode: "empty" // empty | new | configured | detected
    property string typeFilter: "All"
    property string savedSignature: ""
    property string messageText: ""
    property string messageType: "info"
    property string detectionSource: ""
    property string detectionConfidence: ""
    property string detectionDefaultFor: ""
    property bool advancedExpanded: false
    property bool discoveryPending: false

    readonly property bool compactLayout: width < 920
    readonly property bool editorVisible: editorMode !== "empty"
    readonly property bool isConfiguredEditor: editorMode === "configured"
    readonly property bool argumentsUnsafe: safeText(arguments.text).toLowerCase().indexOf("{password}") !== -1
    readonly property bool duplicateName: hasDuplicateAppName(appName.text)
    readonly property bool formValid: editorVisible
                                      && safeText(appName.text).trim() !== ""
                                      && typeBox.currentIndex >= 0
                                      && pathValidation.ok === true
                                      && !argumentsUnsafe
                                      && !duplicateName
    readonly property bool canSave: formValid
                                    && (dirty || editorMode === "detected")
                                    && toolsBackend !== null
    readonly property bool dirty: editorVisible && formSignature() !== savedSignature
    readonly property int configuredCount: tools.length
    readonly property int detectedCount: discoveredTools.filter(function(tool) {
        return tool.alreadyConfigured !== true
    }).length
    readonly property var toolsBackend: typeof externalTools !== "undefined" && externalTools !== null
                                        ? externalTools
                                        : null

    function safeText(value) {
        return value === undefined || value === null ? "" : String(value)
    }

    function toolIcon(toolType) {
        if (toolType === "DB Browser")
            return AppAssets.navigationDatabaseSearch
        return AppAssets.navigationTerminal
    }

    function defaultArgumentsForType(toolType) {
        if (toolType === "SSH Client")
            return "{ip}"
        if (toolType === "DB Browser")
            return "{db}"
        return ""
    }

    function placeholderHelpForType(toolType) {
        if (toolType === "SSH Client")
            return "Available placeholders: {ip} and {username}. Passwords are never passed on the command line."
        if (toolType === "DB Browser")
            return "Use {db} where the NetworkTools database path should be inserted."
        return "Optional arguments passed when the terminal starts."
    }

    function previewCommand() {
        const rawPath = safeText(executable.text).trim()
        const quotedPath = rawPath.indexOf(" ") !== -1 ? "\"" + rawPath + "\"" : rawPath
        let previewArgs = safeText(arguments.text)
        previewArgs = previewArgs.replace(/\{ip\}/gi, "192.0.2.10")
        previewArgs = previewArgs.replace(/\{username\}/gi, "network-admin")
        previewArgs = previewArgs.replace(/\{db\}/gi, "C:\\…\\device_network.db")
        previewArgs = previewArgs.replace(/\{password\}/gi, "[BLOCKED]")
        return (quotedPath + (previewArgs.trim() !== "" ? " " + previewArgs.trim() : "")).trim()
    }

    function formSignature() {
        return JSON.stringify([
            safeText(appName.text).trim(),
            safeText(typeBox.currentText),
            safeText(executable.text).trim(),
            safeText(arguments.text),
            enabledToggle.checked === true,
            safeText(description.text)
        ])
    }

    function captureSignature() {
        savedSignature = formSignature()
    }

    function setMessage(text, type) {
        messageText = String(text || "")
        messageType = String(type || "info")
    }

    function notify(text, type) {
        setMessage(text, type)
        if (typeof statusBar !== "undefined" && statusBar !== null)
            statusBar.showMessage(text, type)
    }

    function hasDuplicateAppName(value) {
        const candidate = String(value || "").trim().toLowerCase()
        if (candidate === "")
            return false
        for (let i = 0; i < tools.length; i++) {
            const existing = String(tools[i].app || "").trim().toLowerCase()
            if (existing === candidate && existing !== String(selectedApp || "").toLowerCase())
                return true
        }
        return false
    }

    function matchesFilters(row) {
        if (typeFilter !== "All" && row.type !== typeFilter)
            return false
        const query = safeText(toolSearch.text).trim().toLowerCase()
        if (query === "")
            return true
        const haystack = [row.app, row.type, row.executable, row.description, row.source]
            .join(" ").toLowerCase()
        return haystack.indexOf(query) !== -1
    }

    function rebuildDisplayRows() {
        const rows = []
        for (let i = 0; i < tools.length; i++) {
            const tool = tools[i]
            const row = {
                "section": "Configured",
                "kind": "configured",
                "key": "configured|" + tool.app,
                "app": tool.app,
                "type": tool.type,
                "executable": tool.executable,
                "arguments": tool.arguments || "",
                "enabled": tool.enabled,
                "description": tool.description || "",
                "isDefault": false,
                "defaultFor": [],
                "source": "Saved configuration",
                "confidence": "",
                "isAmbiguous": false
            }
            if (matchesFilters(row))
                rows.push(row)
        }
        for (let i = 0; i < discoveredTools.length; i++) {
            const tool = discoveredTools[i]
            if (tool.alreadyConfigured === true)
                continue
            const row = {
                "section": "Detected on Windows",
                "kind": "detected",
                "key": "detected|" + tool.candidateId,
                "candidateId": tool.candidateId,
                "app": tool.app,
                "type": tool.type,
                "executable": tool.executable,
                "arguments": tool.arguments || "",
                "enabled": 1,
                "description": tool.description || "",
                "isDefault": tool.isDefault === true,
                "explicitDefault": tool.explicitDefault === true,
                "defaultFor": tool.defaultFor || [],
                "source": tool.source || "Windows",
                "confidence": tool.confidence || "",
                "isAmbiguous": tool.isAmbiguous === true
            }
            if (matchesFilters(row))
                rows.push(row)
        }
        displayRows = rows
    }

    function refreshTools() {
        if (toolsBackend === null) {
            tools = []
            toolTypes = []
            rebuildDisplayRows()
            return
        }
        tools = toolsBackend.getTools() || []
        toolTypes = toolsBackend.getToolTypes() || []
        rebuildDisplayRows()
    }

    function discoverTools() {
        if (toolsBackend === null || !toolsBackend.discoverWindowsTools) {
            discoveredTools = []
            rebuildDisplayRows()
            return
        }
        discoveryPending = true
        discoveryTimer.restart()
    }

    function validatePath(normalizePath) {
        if (toolsBackend === null || !toolsBackend.validateExecutable) {
            const currentPath = safeText(executable.text).trim()
            pathValidation = {
                "ok": currentPath !== "",
                "exists": false,
                "path": currentPath,
                "message": "Executable validation is not available."
            }
            return pathValidation
        }
        const result = toolsBackend.validateExecutable(safeText(executable.text))
        pathValidation = result
        if (normalizePath === true && result.ok && result.path)
            executable.text = result.path
        return result
    }

    function resetDetectionMetadata() {
        detectionSource = ""
        detectionConfidence = ""
        detectionDefaultFor = ""
    }

    function clearForm() {
        editorMode = "new"
        selectedApp = ""
        selectedKey = "new"
        selectedCandidate = null
        appName.text = ""
        typeBox.currentIndex = toolTypes.length > 0 ? 0 : -1
        executable.text = ""
        arguments.text = defaultArgumentsForType(typeBox.currentText)
        enabledToggle.checked = true
        description.text = ""
        advancedExpanded = false
        pathValidation = {
            "ok": false,
            "exists": false,
            "path": "",
            "message": "Choose an executable to continue."
        }
        resetDetectionMetadata()
        setMessage("", "info")
        Qt.callLater(captureSignature)
        Qt.callLater(function() { appName.forceActiveFocus() })
    }

    function loadTool(tool) {
        editorMode = "configured"
        selectedApp = String(tool.app || "")
        selectedKey = "configured|" + selectedApp
        selectedCandidate = null
        appName.text = selectedApp
        typeBox.currentIndex = Math.max(0, typeBox.model.indexOf(tool.type))
        executable.text = String(tool.executable || "")
        arguments.text = String(tool.arguments || "")
        enabledToggle.checked = tool.enabled === 1 || tool.enabled === true
        description.text = String(tool.description || "")
        advancedExpanded = arguments.text !== ""
        resetDetectionMetadata()
        setMessage("", "info")
        validatePath(false)
        Qt.callLater(captureSignature)
    }

    function loadDetectedTool(tool) {
        editorMode = "detected"
        selectedApp = ""
        selectedKey = String(tool.key || ("detected|" + tool.candidateId))
        selectedCandidate = tool
        appName.text = String(tool.app || "")
        typeBox.currentIndex = Math.max(0, typeBox.model.indexOf(tool.type))
        executable.text = String(tool.executable || "")
        arguments.text = String(tool.arguments || defaultArgumentsForType(tool.type))
        enabledToggle.checked = true
        description.text = String(tool.description || "")
        advancedExpanded = arguments.text !== ""
        detectionSource = String(tool.source || "Windows")
        detectionConfidence = String(tool.confidence || "")
        detectionDefaultFor = (tool.defaultFor || []).join(", ")
        setMessage(tool.isAmbiguous ? "Multiple installations were found. Confirm the executable path before saving." : "", tool.isAmbiguous ? "warning" : "info")
        validatePath(false)
        Qt.callLater(captureSignature)
    }

    function activateDisplayRow(tool) {
        if (!tool)
            return
        if (tool.kind === "configured")
            loadTool(tool)
        else
            loadDetectedTool(tool)
    }

    function findConfiguredTool(app) {
        for (let i = 0; i < tools.length; i++) {
            if (String(tools[i].app || "") === String(app || ""))
                return tools[i]
        }
        return null
    }

    function cancelChanges() {
        if (editorMode === "configured") {
            const tool = findConfiguredTool(selectedApp)
            if (tool)
                loadTool(tool)
            return
        }
        if (editorMode === "detected" && selectedCandidate !== null) {
            loadDetectedTool(selectedCandidate)
            return
        }
        clearForm()
    }

    function saveCurrentTool() {
        if (toolsBackend === null)
            return
        const validation = validatePath(true)
        if (!validation.ok) {
            setMessage(validation.message || "Choose a valid executable.", "error")
            return
        }
        if (duplicateName) {
            setMessage("A tool with this name already exists. Choose the configured entry to edit it.", "error")
            return
        }
        if (argumentsUnsafe) {
            setMessage("{password} is blocked because command-line credentials can be exposed.", "error")
            return
        }
        const result = toolsBackend.saveTool(
            appName.text,
            typeBox.currentText,
            executable.text,
            arguments.text,
            enabledToggle.checked,
            description.text
        )
        if (!result || !result.ok) {
            setMessage(result && result.message ? result.message : "External tool could not be saved.", "error")
            return
        }
        const savedApp = safeText(appName.text).trim()
        refreshTools()
        const savedTool = findConfiguredTool(savedApp)
        if (savedTool)
            loadTool(savedTool)
        notify(result.message || "External tool saved.", "success")
        discoverTools()
    }

    function deleteSelectedTool() {
        if (toolsBackend === null || selectedApp === "")
            return
        if (!toolsBackend.deleteTool(selectedApp)) {
            setMessage("External tool could not be removed.", "error")
            return
        }
        const deletedApp = selectedApp
        editorMode = "empty"
        selectedApp = ""
        selectedKey = ""
        selectedCandidate = null
        refreshTools()
        discoverTools()
        notify("Removed " + deletedApp + ".", "success")
    }

    Connections {
        target: root.toolsBackend
        function onToolsChanged() { root.refreshTools() }
    }

    onToolsBackendChanged: {
        refreshTools()
        discoverTools()
    }
    onTypeFilterChanged: rebuildDisplayRows()

    Component.onCompleted: {
        refreshTools()
        discoverTools()
    }

    Timer {
        id: discoveryTimer
        interval: 0
        repeat: false
        onTriggered: {
            try {
                root.discoveredTools = root.toolsBackend.discoverWindowsTools() || []
                root.rebuildDisplayRows()
            } catch (error) {
                root.discoveredTools = []
                root.setMessage("Windows application detection failed: " + error, "error")
                root.rebuildDisplayRows()
            }
            root.discoveryPending = false
        }
    }

    Timer {
        id: pathValidationTimer
        interval: 220
        repeat: false
        onTriggered: root.validatePath(false)
    }

    FileDialog {
        id: executableDialog
        title: "Choose an external application"
        fileMode: FileDialog.OpenFile
        nameFilters: ["Windows applications (*.exe *.com *.bat *.cmd)", "All files (*)"]
        onAccepted: {
            const result = root.toolsBackend !== null && root.toolsBackend.validateExecutable
                         ? root.toolsBackend.validateExecutable(selectedFile.toString())
                         : ({ "ok": true, "path": selectedFile.toString(), "message": "Selected file." })
            if (result.path)
                executable.text = result.path
            root.pathValidation = result
        }
    }

    Dialog {
        id: deleteDialog
        modal: true
        width: 420
        x: Math.max(0, (root.width - width) / 2)
        y: Math.max(0, (root.height - height) / 2)
        closePolicy: Popup.CloseOnEscape

        background: Rectangle {
            color: Theme.contentSurface
            radius: Theme.radiusMedium
            border.color: Theme.borderColor
            border.width: Theme.borderWidth
        }

        contentItem: ColumnLayout {
            spacing: Theme.spacing16

            Text {
                Layout.fillWidth: true
                text: "Remove external tool?"
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLarge
                font.bold: true
            }

            Text {
                Layout.fillWidth: true
                text: "“%1” will be removed from NetworkTools. The application itself will not be uninstalled.".arg(root.selectedApp)
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeNormal
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                StandardButton {
                    text: "Cancel"
                    type: "Text"
                    onClicked: deleteDialog.close()
                }
                StandardButton {
                    text: "Remove"
                    type: "Danger"
                    onClicked: {
                        deleteDialog.close()
                        root.deleteSelectedTool()
                    }
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 88
            color: Theme.contentSurface

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: Theme.borderWidth
                color: Theme.borderColor
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.spacing24
                anchors.rightMargin: Theme.spacing24
                spacing: Theme.spacing16

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3

                    Text {
                        text: "External Tools"
                        color: Theme.textPrimary
                        font.pixelSize: Theme.fontSizeTitle
                        font.family: Theme.fontFamily
                        font.bold: true
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Connect NetworkTools with applications already installed on Windows. Nothing is selected or changed without confirmation."
                        color: Theme.textSecondary
                        font.pixelSize: Theme.fontSizeSmall
                        font.family: Theme.fontFamily
                        elide: Text.ElideRight
                    }
                }

                StandardButton {
                    text: "Windows defaults"
                    type: "Text"
                    visible: !root.compactLayout
                    onClicked: Qt.openUrlExternally("ms-settings:defaultapps")
                }

                StandardButton {
                    objectName: "externalToolsScanButton"
                    text: root.discoveryPending ? "Scanning…" : "Scan Windows"
                    type: "Secondary"
                    icon.source: AppAssets.actionRefresh
                    enabled: root.toolsBackend !== null && !root.discoveryPending
                    onClicked: root.discoverTools()
                }

                StandardButton {
                    objectName: "externalToolsNewButton"
                    text: "New Tool"
                    type: "Primary"
                    onClicked: root.clearForm()
                }
            }
        }

        SplitView {
            id: mainSplit
            objectName: "externalToolsMainSplit"
            Layout.fillWidth: true
            Layout.fillHeight: true
            orientation: root.compactLayout ? Qt.Vertical : Qt.Horizontal
            handle: StandardSplitHandle {}

            Rectangle {
                id: masterPane
                SplitView.preferredWidth: root.compactLayout ? mainSplit.width : 340
                SplitView.minimumWidth: root.compactLayout ? mainSplit.width : 280
                SplitView.maximumWidth: root.compactLayout ? mainSplit.width : 430
                SplitView.preferredHeight: root.compactLayout ? 280 : mainSplit.height
                SplitView.minimumHeight: root.compactLayout ? 220 : mainSplit.height
                color: Theme.contentBackground

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacing16
                    spacing: Theme.spacing12

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "Applications"
                            color: Theme.textPrimary
                            font.pixelSize: Theme.fontSizeLarge
                            font.family: Theme.fontFamily
                            font.bold: true
                        }

                        StandardBadge {
                            text: String(root.configuredCount + root.detectedCount)
                            badgeColor: Theme.accentEmphasis
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Item { Layout.fillWidth: true }

                        LoadingSpinner {
                            objectName: "externalToolsDiscoverySpinner"
                            width: Theme.iconSizeLarge
                            height: Theme.iconSizeLarge
                            running: root.discoveryPending
                        }
                    }

                    StandardTextField {
                        id: toolSearch
                        objectName: "externalToolsSearchField"
                        Layout.fillWidth: true
                        placeholderText: "Search applications…"
                        onTextEdited: root.rebuildDisplayRows()
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: Theme.spacing4

                        Repeater {
                            model: [
                                { "label": "All", "type": "All" },
                                { "label": "SSH", "type": "SSH Client" },
                                { "label": "Terminal", "type": "Terminal" },
                                { "label": "Database", "type": "DB Browser" }
                            ]

                            delegate: SegmentTab {
                                required property var modelData
                                label: modelData.label
                                minWidth: modelData.type === "Terminal" || modelData.type === "DB Browser" ? 72 : 48
                                selected: root.typeFilter === modelData.type
                                onClicked: root.typeFilter = modelData.type
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Text {
                            anchors.centerIn: parent
                            width: Math.min(parent.width - 24, 260)
                            visible: root.displayRows.length === 0 && !root.discoveryPending
                            text: root.safeText(toolSearch.text).trim() !== ""
                                  ? "No applications match the current search."
                                  : "No compatible applications were found. Use New Tool or Browse to add one manually."
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeNormal
                            font.family: Theme.fontFamily
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                        }

                        ListView {
                            id: toolList
                            objectName: "externalToolsMasterList"
                            anchors.fill: parent
                            visible: root.displayRows.length > 0
                            clip: true
                            spacing: Theme.spacing4
                            model: root.displayRows
                            currentIndex: -1
                            activeFocusOnTab: visible
                            keyNavigationEnabled: true
                            Accessible.role: Accessible.List
                            Accessible.name: "Configured and detected external applications"

                            Keys.onReturnPressed: root.activateDisplayRow(currentItem ? currentItem.modelData : null)
                            Keys.onEnterPressed: root.activateDisplayRow(currentItem ? currentItem.modelData : null)
                            Keys.onSpacePressed: root.activateDisplayRow(currentItem ? currentItem.modelData : null)

                            section.property: "section"
                            section.criteria: ViewSection.FullString
                            section.delegate: Rectangle {
                                required property string section
                                width: toolList.width
                                height: 32
                                color: Theme.contentBackground

                                Text {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: parent.section.toUpperCase()
                                    color: Theme.textSecondary
                                    font.pixelSize: Theme.fontSizeCaption
                                    font.family: Theme.fontFamily
                                    font.weight: Font.Medium
                                    font.letterSpacing: 0.4
                                }
                            }

                            delegate: Rectangle {
                                id: toolRow
                                required property var modelData
                                required property int index
                                readonly property bool detectedOnly: modelData.kind === "detected"
                                width: ListView.view.width
                                height: 72
                                radius: Theme.radiusSmall
                                color: root.selectedKey === modelData.key
                                       ? Theme.sideBarItemSelected
                                       : (rowHover.hovered
                                          ? Theme.sideBarItemHover
                                          : (detectedOnly ? Theme.contentBackground : Theme.contentSurface))
                                border.width: Theme.borderWidth
                                border.color: root.selectedKey === modelData.key
                                              ? Theme.accentColor
                                              : Theme.borderColor
                                Accessible.role: Accessible.ListItem
                                Accessible.name: modelData.app + ", " + modelData.type
                                Accessible.description: modelData.kind === "configured"
                                                        ? (modelData.enabled === 1 ? "Configured and enabled" : "Configured and disabled")
                                                        : "Detected via " + modelData.source

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: Theme.spacing8
                                    spacing: Theme.spacing8

                                    Rectangle {
                                        Layout.preferredWidth: 34
                                        Layout.preferredHeight: 34
                                        Layout.alignment: Qt.AlignVCenter
                                        radius: Theme.radiusSmall
                                        color: toolRow.detectedOnly
                                               ? Theme.contentPanelSurface
                                               : Theme.sideBarItemSelected
                                        border.width: toolRow.detectedOnly ? Theme.borderWidth : 0
                                        border.color: Theme.contentPanelBorder

                                        ThemedIcon {
                                            anchors.centerIn: parent
                                            iconSource: root.toolIcon(toolRow.modelData.type)
                                            iconSize: Theme.iconSizeLarge
                                            iconColor: toolRow.detectedOnly || toolRow.modelData.enabled === 0
                                                       ? Theme.textDisabled
                                                       : Theme.accentColor
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: Theme.spacing4

                                            Text {
                                                Layout.fillWidth: true
                                                text: toolRow.modelData.app
                                                color: toolRow.detectedOnly ? Theme.textSecondary : Theme.textPrimary
                                                font.pixelSize: Theme.fontSizeNormal
                                                font.family: Theme.fontFamily
                                                font.weight: Font.Medium
                                                elide: Text.ElideRight
                                            }

                                            Rectangle {
                                                visible: toolRow.modelData.isDefault === true
                                                implicitWidth: defaultLabel.implicitWidth + 10
                                                implicitHeight: 18
                                                radius: 9
                                                color: toolRow.detectedOnly
                                                       ? Theme.contentPanelSurface
                                                       : Theme.alertInfoSubtle
                                                border.color: toolRow.detectedOnly
                                                              ? Theme.textDisabled
                                                              : Theme.notificationInfoAccent
                                                border.width: Theme.borderWidth

                                                Text {
                                                    id: defaultLabel
                                                    anchors.centerIn: parent
                                                    text: "Default"
                                                    color: toolRow.detectedOnly
                                                           ? Theme.textSecondary
                                                           : Theme.notificationInfoAccent
                                                    font.pixelSize: Theme.fontSizeCaption
                                                    font.family: Theme.fontFamily
                                                    font.weight: Font.Medium
                                                }
                                            }
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: toolRow.modelData.type
                                                  + (toolRow.modelData.kind === "configured"
                                                     ? (toolRow.modelData.enabled === 1 ? " · Enabled" : " · Disabled")
                                                     : " · " + toolRow.modelData.source)
                                            color: toolRow.detectedOnly ? Theme.textDisabled : Theme.textSecondary
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.family: Theme.fontFamily
                                            elide: Text.ElideRight
                                        }
                                    }
                                }

                                HoverHandler { id: rowHover; cursorShape: Qt.PointingHandCursor }
                                TapHandler {
                                    onTapped: {
                                        toolList.currentIndex = toolRow.index
                                        toolList.forceActiveFocus()
                                        root.activateDisplayRow(toolRow.modelData)
                                    }
                                }
                            }

                            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                        }
                    }
                }
            }

            Rectangle {
                id: detailPane
                SplitView.fillWidth: true
                SplitView.fillHeight: true
                SplitView.minimumWidth: root.compactLayout ? mainSplit.width : 520
                color: Theme.contentPanelSurface

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 72

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.spacing24
                            anchors.rightMargin: Theme.spacing24
                            spacing: Theme.spacing12

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    text: {
                                        if (root.editorMode === "configured") return root.selectedApp
                                        if (root.editorMode === "detected") return "Review detected application"
                                        if (root.editorMode === "new") return "New external tool"
                                        return "Choose an application"
                                    }
                                    color: Theme.textPrimary
                                    font.pixelSize: Theme.fontSizeLarge
                                    font.family: Theme.fontFamily
                                    font.bold: true
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: {
                                        if (root.editorMode === "configured")
                                            return root.dirty ? "Unsaved changes" : "Saved configuration"
                                        if (root.editorMode === "detected")
                                            return "Confirm the detected path before saving"
                                        if (root.editorMode === "new")
                                            return "Create a reusable Windows application connection"
                                        return "Select a configured or detected application from the list"
                                    }
                                    color: root.dirty ? Theme.alertWarning : Theme.textSecondary
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.family: Theme.fontFamily
                                    elide: Text.ElideRight
                                }
                            }

                            StandardBadge {
                                visible: root.editorVisible && root.dirty
                                text: "Unsaved"
                                badgeColor: Theme.alertWarning
                                textColor: Theme.buttonTextSolid
                            }
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: Theme.borderWidth
                            color: Theme.borderColor
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.leftMargin: Theme.spacing24
                        Layout.rightMargin: Theme.spacing24
                        Layout.topMargin: Theme.spacing8
                        Layout.preferredHeight: messageLayout.implicitHeight + Theme.spacing16
                        visible: root.messageText !== ""
                        radius: Theme.radiusSmall
                        color: root.messageType === "error"
                               ? Theme.notificationErrorBackground
                               : (root.messageType === "warning"
                                  ? Theme.notificationWarningBackground
                                  : (root.messageType === "success"
                                     ? Theme.notificationSuccessBackground
                                     : Theme.notificationInfoBackground))
                        border.width: Theme.borderWidth
                        border.color: root.messageType === "error"
                                      ? Theme.notificationErrorAccent
                                      : (root.messageType === "warning"
                                         ? Theme.notificationWarningAccent
                                         : (root.messageType === "success"
                                            ? Theme.notificationSuccessAccent
                                            : Theme.notificationInfoAccent))

                        RowLayout {
                            id: messageLayout
                            anchors.fill: parent
                            anchors.margins: Theme.spacing8
                            spacing: Theme.spacing8

                            ThemedIcon {
                                Layout.alignment: Qt.AlignTop
                                iconSource: root.messageType === "error"
                                            ? AppAssets.statusError
                                            : (root.messageType === "warning"
                                               ? AppAssets.statusWarning
                                               : AppAssets.statusInfo)
                                iconSize: Theme.iconSizeNormal
                                iconColor: root.messageType === "error"
                                           ? Theme.notificationErrorAccent
                                           : (root.messageType === "warning"
                                              ? Theme.notificationWarningAccent
                                              : Theme.notificationInfoAccent)
                            }

                            Text {
                                Layout.fillWidth: true
                                text: root.messageText
                                color: Theme.textPrimary
                                font.pixelSize: Theme.fontSizeSmall
                                font.family: Theme.fontFamily
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        ColumnLayout {
                            anchors.centerIn: parent
                            width: Math.min(parent.width - 48, 520)
                            visible: !root.editorVisible
                            spacing: Theme.spacing16

                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredWidth: 54
                                Layout.preferredHeight: 54
                                radius: 27
                                color: Theme.sideBarItemSelected

                                ThemedIcon {
                                    anchors.centerIn: parent
                                    iconSource: AppAssets.navigationTerminal
                                    iconSize: Theme.iconSizeXLarge
                                    iconColor: Theme.accentColor
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: root.configuredCount === 0
                                      ? "Connect your first application"
                                      : "Select an application to review"
                                color: Theme.textPrimary
                                font.pixelSize: Theme.fontSizeTitle
                                font.family: Theme.fontFamily
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                            }

                            Text {
                                Layout.fillWidth: true
                                text: root.detectedCount > 0
                                      ? "%1 compatible Windows application(s) are ready for review. Detected paths are never saved automatically.".arg(root.detectedCount)
                                      : "Scan Windows or add a tool manually. NetworkTools checks App Paths, PATH, default associations, and a small set of known install locations."
                                color: Theme.textSecondary
                                font.pixelSize: Theme.fontSizeNormal
                                font.family: Theme.fontFamily
                                wrapMode: Text.WordWrap
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }

                        ScrollView {
                            id: editorScroll
                            anchors.fill: parent
                            visible: root.editorVisible
                            clip: true
                            contentWidth: availableWidth
                            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                            ScrollBar.vertical.policy: ScrollBar.AsNeeded

                            ColumnLayout {
                                width: editorScroll.availableWidth
                                spacing: Theme.spacing16

                                Item { Layout.preferredHeight: Theme.spacing8 }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.leftMargin: Theme.spacing24
                                    Layout.rightMargin: Theme.spacing24
                                    Layout.preferredHeight: basicLayout.implicitHeight + Theme.spacing32
                                    radius: Theme.radiusMedium
                                    color: Theme.contentSurface
                                    border.color: Theme.borderColor
                                    border.width: Theme.borderWidth

                                    ColumnLayout {
                                        id: basicLayout
                                        anchors.fill: parent
                                        anchors.margins: Theme.spacing16
                                        spacing: Theme.spacing12

                                        Text {
                                            text: "Basic information"
                                            color: Theme.textPrimary
                                            font.pixelSize: Theme.fontSizeNormal
                                            font.family: Theme.fontFamily
                                            font.bold: true
                                        }

                                        GridLayout {
                                            Layout.fillWidth: true
                                            columns: root.compactLayout ? 1 : 2
                                            columnSpacing: Theme.spacing12
                                            rowSpacing: Theme.spacing12

                                            StandardTextField {
                                                id: appName
                                                objectName: "externalToolAppName"
                                                Layout.fillWidth: true
                                                labelText: "Application name"
                                                placeholderText: "e.g., PuTTY"
                                                readOnly: root.isConfiguredEditor
                                            }

                                            StandardComboBox {
                                                id: typeBox
                                                objectName: "externalToolType"
                                                Layout.fillWidth: true
                                                labelText: "Tool type"
                                                model: root.toolTypes
                                                onActivated: {
                                                    if (root.safeText(arguments.text).trim() === "")
                                                        arguments.text = root.defaultArgumentsForType(currentText)
                                                }
                                            }
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            visible: root.duplicateName
                                            text: "A configured tool already uses this name."
                                            color: Theme.alertError
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.family: Theme.fontFamily
                                        }

                                        StandardTextField {
                                            id: description
                                            objectName: "externalToolDescription"
                                            Layout.fillWidth: true
                                            labelText: "Description"
                                            placeholderText: "What this application is used for"
                                        }

                                        StandardToggleButton {
                                            id: enabledToggle
                                            objectName: "externalToolEnabledToggle"
                                            Layout.fillWidth: true
                                            text: "Available to NetworkTools"
                                            description: "Disabled tools remain saved but are not used to open devices or databases."
                                            checked: true
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.leftMargin: Theme.spacing24
                                    Layout.rightMargin: Theme.spacing24
                                    Layout.preferredHeight: executableLayout.implicitHeight + Theme.spacing32
                                    radius: Theme.radiusMedium
                                    color: Theme.contentSurface
                                    border.color: Theme.borderColor
                                    border.width: Theme.borderWidth

                                    ColumnLayout {
                                        id: executableLayout
                                        anchors.fill: parent
                                        anchors.margins: Theme.spacing16
                                        spacing: Theme.spacing12

                                        RowLayout {
                                            Layout.fillWidth: true

                                            Text {
                                                Layout.fillWidth: true
                                                text: "Executable"
                                                color: Theme.textPrimary
                                                font.pixelSize: Theme.fontSizeNormal
                                                font.family: Theme.fontFamily
                                                font.bold: true
                                            }

                                            Text {
                                                visible: root.detectionConfidence !== ""
                                                text: root.detectionConfidence + " confidence"
                                                color: Theme.textSecondary
                                                font.pixelSize: Theme.fontSizeSmall
                                                font.family: Theme.fontFamily
                                            }
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: Theme.spacing8

                                            StandardTextField {
                                                id: executable
                                                objectName: "externalToolExecutable"
                                                Layout.fillWidth: true
                                                labelText: "Application path"
                                                placeholderText: "C:\\Program Files\\…\\application.exe"
                                                onTextEdited: {
                                                    root.pathValidation = {
                                                        "ok": false,
                                                        "exists": false,
                                                        "path": text,
                                                        "message": "Checking executable…"
                                                    }
                                                    pathValidationTimer.restart()
                                                }
                                                onAccepted: root.validatePath(true)
                                            }

                                            StandardButton {
                                                Layout.alignment: Qt.AlignBottom
                                                text: "Browse"
                                                type: "Secondary"
                                                onClicked: executableDialog.open()
                                            }
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: Theme.spacing8

                                            Rectangle {
                                                Layout.preferredWidth: 8
                                                Layout.preferredHeight: 8
                                                radius: 4
                                                color: root.pathValidation.ok
                                                       ? Theme.alertSuccess
                                                       : (root.safeText(executable.text).trim() === "" ? Theme.textDisabled : Theme.alertError)
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: root.pathValidation.message || "Choose an executable."
                                                color: root.pathValidation.ok ? Theme.textSecondary : Theme.alertError
                                                font.pixelSize: Theme.fontSizeSmall
                                                font.family: Theme.fontFamily
                                                wrapMode: Text.WordWrap
                                            }
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            visible: root.detectionSource !== ""
                                            text: "Detected via %1%2".arg(root.detectionSource)
                                                  .arg(root.detectionDefaultFor !== "" ? " · Default for " + root.detectionDefaultFor : "")
                                            color: Theme.textSecondary
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.family: Theme.fontFamily
                                            wrapMode: Text.WordWrap
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.leftMargin: Theme.spacing24
                                    Layout.rightMargin: Theme.spacing24
                                    Layout.preferredHeight: advancedLayout.implicitHeight + Theme.spacing32
                                    radius: Theme.radiusMedium
                                    color: Theme.contentSurface
                                    border.color: Theme.borderColor
                                    border.width: Theme.borderWidth

                                    ColumnLayout {
                                        id: advancedLayout
                                        anchors.fill: parent
                                        anchors.margins: Theme.spacing16
                                        spacing: Theme.spacing12

                                        RowLayout {
                                            Layout.fillWidth: true

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 2

                                                Text {
                                                    text: "Launch preview"
                                                    color: Theme.textPrimary
                                                    font.pixelSize: Theme.fontSizeNormal
                                                    font.family: Theme.fontFamily
                                                    font.bold: true
                                                }

                                                Text {
                                                    text: "Review exactly how NetworkTools will launch this application."
                                                    color: Theme.textSecondary
                                                    font.pixelSize: Theme.fontSizeSmall
                                                    font.family: Theme.fontFamily
                                                }
                                            }

                                            StandardButton {
                                                text: root.advancedExpanded ? "Hide advanced" : "Show advanced"
                                                type: "Text"
                                                onClicked: root.advancedExpanded = !root.advancedExpanded
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            visible: root.advancedExpanded
                                            spacing: Theme.spacing8

                                            StandardTextField {
                                                id: arguments
                                                objectName: "externalToolArguments"
                                                Layout.fillWidth: true
                                                labelText: "Arguments"
                                                placeholderText: root.defaultArgumentsForType(typeBox.currentText)
                                            }

                                            RowLayout {
                                                Layout.fillWidth: true

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: root.placeholderHelpForType(typeBox.currentText)
                                                    color: root.argumentsUnsafe ? Theme.alertError : Theme.textSecondary
                                                    font.pixelSize: Theme.fontSizeSmall
                                                    font.family: Theme.fontFamily
                                                    wrapMode: Text.WordWrap
                                                }

                                                StandardButton {
                                                    visible: root.defaultArgumentsForType(typeBox.currentText) !== ""
                                                    text: "Use recommended"
                                                    type: "Text"
                                                    onClicked: arguments.text = root.defaultArgumentsForType(typeBox.currentText)
                                                }
                                            }
                                        }

                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: Math.max(54, previewText.implicitHeight + Theme.spacing24)
                                            radius: Theme.radiusSmall
                                            color: Theme.contentPanelSurface
                                            border.color: root.argumentsUnsafe ? Theme.alertError : Theme.contentPanelBorder
                                            border.width: Theme.borderWidth

                                            Text {
                                                id: previewText
                                                anchors.fill: parent
                                                anchors.margins: Theme.spacing12
                                                text: root.previewCommand() !== "" ? root.previewCommand() : "Command preview will appear here."
                                                color: root.argumentsUnsafe ? Theme.alertError : Theme.textSecondary
                                                font.pixelSize: Theme.fontSizeSmall
                                                font.family: "Cascadia Mono"
                                                wrapMode: Text.WrapAnywhere
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                        }
                                    }
                                }

                                Item { Layout.preferredHeight: Theme.spacing8 }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.editorVisible ? 58 : 0
                        visible: root.editorVisible
                        color: Theme.contentSurface

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            height: Theme.borderWidth
                            color: Theme.borderColor
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.spacing24
                            anchors.rightMargin: Theme.spacing24
                            spacing: Theme.spacing8

                            StandardButton {
                                visible: root.isConfiguredEditor
                                text: "Delete"
                                type: "Danger"
                                onClicked: deleteDialog.open()
                            }

                            Item { Layout.fillWidth: true }

                            StandardButton {
                                text: "Cancel Changes"
                                type: "Text"
                                enabled: root.dirty
                                onClicked: root.cancelChanges()
                            }

                            StandardButton {
                                objectName: "externalToolSaveButton"
                                text: root.editorMode === "detected" ? "Add Tool" : "Save"
                                icon.source: root.editorMode === "detected"
                                             ? ""
                                             : AppAssets.actionSave
                                type: "Primary"
                                enabled: root.canSave
                                onClicked: root.saveCurrentTool()
                            }
                        }
                    }
                }
            }
        }
    }
}
