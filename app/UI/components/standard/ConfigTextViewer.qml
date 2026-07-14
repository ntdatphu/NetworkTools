pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

Item {
    id: root

    property string text: ""
    property string sourceLabel: "Configuration text"
    property string emptyText: "No configuration data is available."
    property string errorText: ""
    property bool loading: false
    property string loadingText: "Loading configuration..."
    property string searchText: ""
    property int minimumFontPixelSize: 9
    property int maximumFontPixelSize: 40
    property int defaultFontPixelSize: Theme.fontSizeNormal
    property int fontPixelSize: defaultFontPixelSize
    property int currentMatchIndex: -1
    property var matchPositions: []
    property int textRevision: 0
    property int searchedTextRevision: -1
    property string searchedQuery: ""
    property var lineStarts: [0]
    property string lineNumberText: "1"
    property int maximumSearchMatches: 10000
    property bool searchResultsTruncated: false
    property bool syntaxHighlightingEnabled: true
    property int syntaxHighlightCharacterLimit: 1000000
    property int highlightingChunkLineCount: 250
    property bool highlightingInProgress: false
    property bool highlightingReady: false
    property bool highlightingSkippedForLargeText: false
    property string highlightedText: ""
    property string pendingHighlightSource: ""
    property int pendingHighlightOffset: 0
    property var pendingHighlightOutput: []
    property bool verticalScrollSnapInProgress: false
    property real verticalWheelRemainder: 0
    property int wheelScrollLineCount: 3

    property color syntaxIpAddressColor: Theme.syntaxIpAddress
    property color syntaxPrefixColor: Theme.syntaxPrefix
    property color syntaxMaskColor: Theme.syntaxMask
    property color syntaxWildcardColor: Theme.syntaxWildcard
    property color syntaxInterfaceColor: Theme.syntaxInterface
    property color syntaxNumberColor: Theme.syntaxNumber
    property color syntaxBooleanColor: Theme.syntaxBoolean
    property color syntaxDateTimeColor: Theme.syntaxDateTime
    property color syntaxPermitColor: Theme.syntaxPermit
    property color syntaxDenyColor: Theme.syntaxDeny
    property color syntaxInsideColor: Theme.syntaxInside
    property color syntaxOutsideColor: Theme.syntaxOutside
    property color syntaxCommentColor: Theme.syntaxComment

    readonly property int matchCount: matchPositions.length
    readonly property int lineCount: lineStarts.length
    readonly property string selectedText: configTextArea.selectedText
    readonly property bool searchInputActiveFocus: searchField.inputActiveFocus
    readonly property bool copyFeedbackVisible: viewerClipboardCopyButton.copied
    readonly property real codeLineHeight: Math.max(1, codeFontMetrics.lineSpacing)
    readonly property real verticalScrollContentY: textScroll.contentItem
                                                   ? textScroll.contentItem.contentY
                                                   : 0
    readonly property bool syntaxHighlightingActive: syntaxHighlightingEnabled
                                                      && highlightingReady
                                                      && !highlightingSkippedForLargeText
                                                      && text !== ""
    readonly property string syntaxPaletteKey: [
        String(syntaxIpAddressColor),
        String(syntaxPrefixColor),
        String(syntaxMaskColor),
        String(syntaxWildcardColor),
        String(syntaxInterfaceColor),
        String(syntaxNumberColor),
        String(syntaxBooleanColor),
        String(syntaxDateTimeColor),
        String(syntaxPermitColor),
        String(syntaxDenyColor),
        String(syntaxInsideColor),
        String(syntaxOutsideColor),
        String(syntaxCommentColor)
    ].join("|")

    signal copyAllSucceeded(string copiedText)

    function rebuildLineStarts() {
        const value = String(root.text || "")
        const starts = [0]
        for (let index = 0; index < value.length; index++) {
            const code = value.charCodeAt(index)
            if (code === 10) {
                starts.push(index + 1)
            } else if (code === 13 && (index + 1 >= value.length || value.charCodeAt(index + 1) !== 10)) {
                starts.push(index + 1)
            }
        }
        root.lineStarts = starts
        const numbers = new Array(starts.length)
        for (let lineIndex = 0; lineIndex < starts.length; lineIndex++)
            numbers[lineIndex] = String(lineIndex + 1)
        root.lineNumberText = numbers.join("\n")
    }

    function runSearchNow() {
        searchDebounce.stop()
        const query = String(root.searchText || "")
        const haystack = String(root.text || "")
        const positions = []
        root.searchResultsTruncated = false
        root.currentMatchIndex = -1
        root.searchedQuery = query
        root.searchedTextRevision = root.textRevision

        if (query === "" || haystack === "") {
            root.matchPositions = positions
            configTextArea.deselect()
            return
        }

        const normalizedText = haystack.toLocaleLowerCase()
        const normalizedQuery = query.toLocaleLowerCase()
        let position = 0
        while (position <= normalizedText.length - normalizedQuery.length) {
            const matchPosition = normalizedText.indexOf(normalizedQuery, position)
            if (matchPosition < 0)
                break
            positions.push(matchPosition)
            if (positions.length >= root.maximumSearchMatches) {
                root.searchResultsTruncated = true
                break
            }
            position = matchPosition + Math.max(1, normalizedQuery.length)
        }
        root.matchPositions = positions
    }

    function ensureSearchCurrent() {
        if (root.searchedQuery !== String(root.searchText || "")
                || root.searchedTextRevision !== root.textRevision)
            root.runSearchNow()
    }

    function escapeHtml(value) {
        return String(value || "")
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;")
    }

    function htmlColor(value) {
        const colorText = String(value || "")
        if (/^#[0-9a-fA-F]{8}$/.test(colorText))
            return "#" + colorText.slice(3)
        return colorText
    }

    function isIpv4Token(token) {
        return /^(?:\d{1,3}\.){3}\d{1,3}(?:\/\d{1,2})?$/.test(String(token || ""))
    }

    function isLikelySubnetMask(token) {
        const octets = String(token || "").split(".")
        if (octets.length !== 4 || Number(octets[0]) !== 255)
            return false
        let bits = ""
        for (let index = 0; index < octets.length; index++) {
            const octet = Number(octets[index])
            if (!Number.isInteger(octet) || octet < 0 || octet > 255)
                return false
            bits += ("00000000" + octet.toString(2)).slice(-8)
        }
        return /^1+0*$/.test(bits)
    }

    function addressSyntaxColor(token, line, matchIndex, addressOrdinal) {
        const value = String(token || "")
        if (value.indexOf("/") >= 0)
            return root.syntaxPrefixColor

        const source = String(line || "")
        const lowerLine = source.toLocaleLowerCase()
        const before = source.slice(0, matchIndex).toLocaleLowerCase()
        if (/\b(?:wildcard|wildcard-mask)\s*$/.test(before))
            return root.syntaxWildcardColor
        if (/\b(?:mask|subnet-mask)\s*$/.test(before))
            return root.syntaxMaskColor
        if (addressOrdinal > 0 && /\bip\s+address\b/.test(lowerLine))
            return root.syntaxMaskColor
        if (addressOrdinal > 0 && /\bnetwork\b/.test(lowerLine))
            return root.syntaxWildcardColor
        if (root.isLikelySubnetMask(value))
            return root.syntaxMaskColor
        return root.syntaxIpAddressColor
    }

    function syntaxColorForToken(token, line, matchIndex, addressOrdinal) {
        const value = String(token || "")
        const lower = value.toLocaleLowerCase()

        if (/^\d{4}-\d{2}-\d{2}/.test(value))
            return root.syntaxDateTimeColor
        if (root.isIpv4Token(value))
            return root.addressSyntaxColor(value, line, matchIndex, addressOrdinal)
        if (/^(?:interface|gigabitethernet|fastethernet|ethernet|loopback|serial|vlan|tunnel|port-channel)/i.test(value))
            return root.syntaxInterfaceColor
        if (lower === "permit")
            return root.syntaxPermitColor
        if (lower === "deny")
            return root.syntaxDenyColor
        if (lower === "inside")
            return root.syntaxInsideColor
        if (lower === "outside")
            return root.syntaxOutsideColor
        if (lower === "yes" || lower === "no" || lower === "true" || lower === "false"
                || lower === "up" || lower === "down")
            return root.syntaxBooleanColor
        if (/^\d+$/.test(value))
            return root.syntaxNumberColor
        return Theme.textPrimary
    }

    function tokenHasLetters(token) {
        return /[A-Za-z]/.test(String(token || ""))
    }

    function highlightLine(line) {
        const value = String(line || "")
        if (/^\s*[!#]/.test(value)) {
            return '<span style="color:' + root.htmlColor(root.syntaxCommentColor) + '">'
                    + root.escapeHtml(value) + "</span>"
        }

        const tokenPattern = /\b(?:\d{4}-\d{2}-\d{2}(?:[T ]\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:?\d{2})?)?|(?:\d{1,3}\.){3}\d{1,3}(?:\/\d{1,2})?|(?:interface|GigabitEthernet|FastEthernet|Ethernet|Loopback|Serial|Vlan|Tunnel|Port-channel)[^\s]*|permit|deny|inside|outside|yes|no|true|false|up|down|\d+|[A-Za-z][A-Za-z0-9_-]*)\b/gi
        const output = []
        let cursor = 0
        let addressOrdinal = 0
        let match = tokenPattern.exec(value)
        while (match !== null) {
            output.push(root.escapeHtml(value.slice(cursor, match.index)))
            const tokenColor = root.syntaxColorForToken(match[0], value, match.index, addressOrdinal)
            const tokenWeight = root.tokenHasLetters(match[0]) ? ";font-weight:600" : ""
            output.push(
                '<span style="color:' + root.htmlColor(tokenColor) + tokenWeight + '">'
                + root.escapeHtml(match[0]) + "</span>"
            )
            if (root.isIpv4Token(match[0]))
                addressOrdinal += 1
            cursor = match.index + match[0].length
            match = tokenPattern.exec(value)
        }
        output.push(root.escapeHtml(value.slice(cursor)))
        return output.join("")
    }

    function scheduleHighlighting() {
        highlightChunkTimer.stop()
        root.highlightingInProgress = false
        root.highlightingReady = false
        root.highlightedText = ""
        root.startHighlighting()
    }

    function startHighlighting() {
        highlightChunkTimer.stop()
        root.highlightingReady = false
        root.highlightedText = ""
        root.highlightingSkippedForLargeText = false
        root.pendingHighlightSource = String(root.text || "")
        root.pendingHighlightOffset = 0
        root.pendingHighlightOutput = []

        if (!root.syntaxHighlightingEnabled || root.pendingHighlightSource === "") {
            root.highlightingInProgress = false
            return false
        }
        if (root.pendingHighlightSource.length > root.syntaxHighlightCharacterLimit) {
            root.highlightingInProgress = false
            root.highlightingSkippedForLargeText = true
            return false
        }

        root.highlightingInProgress = true
        highlightChunkTimer.start()
        return true
    }

    function finishHighlighting() {
        highlightChunkTimer.stop()
        const trailingLineKeeper = /\n$/.test(root.pendingHighlightSource) ? "&#8203;" : ""
        root.highlightedText = '<pre style="margin:0">'
                             + root.pendingHighlightOutput.join("\n")
                             + trailingLineKeeper
                             + "</pre>"
        root.pendingHighlightSource = ""
        root.pendingHighlightOutput = []
        root.highlightingInProgress = false
        root.highlightingReady = true
    }

    function processHighlightChunk() {
        if (!root.highlightingInProgress)
            return

        const source = root.pendingHighlightSource
        let linesProcessed = 0
        while (linesProcessed < root.highlightingChunkLineCount
                && root.pendingHighlightOffset <= source.length) {
            const newlineIndex = source.indexOf("\n", root.pendingHighlightOffset)
            let line = ""
            if (newlineIndex < 0) {
                line = source.slice(root.pendingHighlightOffset)
                root.pendingHighlightOffset = source.length + 1
            } else {
                line = source.slice(root.pendingHighlightOffset, newlineIndex)
                root.pendingHighlightOffset = newlineIndex + 1
            }
            if (line.length > 0 && line.charAt(line.length - 1) === "\r")
                line = line.slice(0, -1)
            root.pendingHighlightOutput.push(root.highlightLine(line))
            linesProcessed += 1
        }

        if (root.pendingHighlightOffset > source.length)
            root.finishHighlighting()
    }

    function revealPosition(position) {
        const flickable = textScroll.contentItem
        if (!flickable || !configTextArea.positionToRectangle)
            return
        const target = configTextArea.positionToRectangle(position)
        const topMargin = root.codeLineHeight
        const bottomMargin = root.codeLineHeight * 2
        if (target.y < flickable.contentY + topMargin) {
            root.setVerticalScrollPosition(target.y - topMargin)
        } else if (target.y + target.height > flickable.contentY + flickable.height - bottomMargin) {
            root.setVerticalScrollPosition(
                target.y + target.height - flickable.height + bottomMargin
            )
        }
    }

    function maximumLineAlignedContentY() {
        const flickable = textScroll.contentItem
        if (!flickable)
            return 0
        const lineHeight = Math.max(1, root.codeLineHeight)
        const maximumContentY = Math.max(0, flickable.contentHeight - flickable.height)
        return Math.floor(maximumContentY / lineHeight) * lineHeight
    }

    function lineAlignedContentY(value) {
        const lineHeight = Math.max(1, root.codeLineHeight)
        const requestedLine = Math.round(Math.max(0, Number(value) || 0) / lineHeight)
        return Math.min(requestedLine * lineHeight, root.maximumLineAlignedContentY())
    }

    function setVerticalScrollPosition(value) {
        const flickable = textScroll.contentItem
        if (!flickable)
            return false
        const alignedValue = root.lineAlignedContentY(value)
        if (Math.abs(flickable.contentY - alignedValue) < 0.01)
            return false
        root.verticalScrollSnapInProgress = true
        flickable.contentY = alignedValue
        root.verticalScrollSnapInProgress = false
        return true
    }

    function snapVerticalScroll() {
        if (root.verticalScrollSnapInProgress)
            return false
        return root.setVerticalScrollPosition(root.verticalScrollContentY)
    }

    function scrollByLines(lineCount) {
        const lineHeight = Math.max(1, root.codeLineHeight)
        const currentLine = Math.round(root.verticalScrollContentY / lineHeight)
        return root.setVerticalScrollPosition((currentLine + Number(lineCount || 0)) * lineHeight)
    }

    function handleVerticalWheel(angleDeltaY, pixelDeltaY) {
        const angleDelta = Number(angleDeltaY || 0)
        const pixelDelta = Number(pixelDeltaY || 0)
        const usesAngleDelta = angleDelta !== 0
        const delta = usesAngleDelta ? angleDelta : pixelDelta
        if (delta === 0)
            return false

        const threshold = usesAngleDelta ? 120 : Math.max(1, root.codeLineHeight)
        if (root.verticalWheelRemainder !== 0
                && Math.sign(root.verticalWheelRemainder) !== Math.sign(delta))
            root.verticalWheelRemainder = 0
        root.verticalWheelRemainder += delta
        const steps = root.verticalWheelRemainder > 0
                    ? Math.floor(root.verticalWheelRemainder / threshold)
                    : Math.ceil(root.verticalWheelRemainder / threshold)
        if (steps !== 0) {
            root.verticalWheelRemainder -= steps * threshold
            root.scrollByLines(-steps * (usesAngleDelta ? root.wheelScrollLineCount : 1))
        }
        return true
    }

    function selectMatch(index) {
        if (index < 0 || index >= root.matchPositions.length)
            return false
        const start = Number(root.matchPositions[index])
        root.currentMatchIndex = index
        configTextArea.select(start, start + String(root.searchText || "").length)
        root.revealPosition(start)
        return true
    }

    function findNext() {
        root.ensureSearchCurrent()
        if (root.matchCount === 0)
            return false
        return root.selectMatch((root.currentMatchIndex + 1) % root.matchCount)
    }

    function findPrevious() {
        root.ensureSearchCurrent()
        if (root.matchCount === 0)
            return false
        const previous = root.currentMatchIndex < 0
                       ? root.matchCount - 1
                       : (root.currentMatchIndex - 1 + root.matchCount) % root.matchCount
        return root.selectMatch(previous)
    }

    function selectLine(lineIndex) {
        if (lineIndex < 0 || lineIndex >= root.lineStarts.length)
            return false
        const start = Number(root.lineStarts[lineIndex])
        let end = lineIndex + 1 < root.lineStarts.length
                ? Number(root.lineStarts[lineIndex + 1])
                : String(root.text || "").length
        const value = String(root.text || "")
        while (end > start && (value.charAt(end - 1) === "\n" || value.charAt(end - 1) === "\r"))
            end -= 1
        configTextArea.select(start, end)
        configTextArea.forceActiveFocus()
        root.revealPosition(start)
        return true
    }

    function zoomIn() {
        root.fontPixelSize = Math.min(root.maximumFontPixelSize, root.fontPixelSize + 1)
    }

    function zoomOut() {
        root.fontPixelSize = Math.max(root.minimumFontPixelSize, root.fontPixelSize - 1)
    }

    function resetZoom() {
        root.fontPixelSize = Math.max(
            root.minimumFontPixelSize,
            Math.min(root.maximumFontPixelSize, root.defaultFontPixelSize)
        )
    }

    function focusSearch() {
        searchField.forceActiveFocus()
        searchField.selectAll()
    }

    function copyAll() {
        return viewerClipboardCopyButton.copyText()
    }

    onTextChanged: {
        root.textRevision += 1
        rebuildLineStarts()
        searchDebounce.restart()
        scheduleHighlighting()
    }
    onSearchTextChanged: searchDebounce.restart()
    onDefaultFontPixelSizeChanged: resetZoom()
    onCodeLineHeightChanged: Qt.callLater(root.snapVerticalScroll)
    onSyntaxHighlightingEnabledChanged: scheduleHighlighting()
    onSyntaxPaletteKeyChanged: scheduleHighlighting()
    Component.onCompleted: {
        rebuildLineStarts()
        resetZoom()
        runSearchNow()
        startHighlighting()
    }

    FontMetrics {
        id: codeFontMetrics
        font.family: "Consolas"
        font.pixelSize: root.fontPixelSize
    }

    Timer {
        id: searchDebounce
        interval: 180
        repeat: false
        onTriggered: root.runSearchNow()
    }

    Timer {
        id: highlightChunkTimer
        interval: 1
        repeat: true
        onTriggered: root.processHighlightChunk()
    }

    CopyButton {
        id: viewerClipboardCopyButton
        objectName: "configViewerCopyButton"
        visible: false
        textToCopy: root.text
        copyTooltip: "Copy all"
        onCopySucceeded: function(copiedText) { root.copyAllSucceeded(copiedText) }
    }

    Shortcut {
        sequence: "Ctrl+F"
        context: Qt.WindowShortcut
        enabled: root.visible && root.enabled
        onActivated: root.focusSearch()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spacing8

        Rectangle {
            objectName: "configViewerContent"
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Theme.inputBackground
            border.color: Theme.inputBorderColor
            border.width: Theme.borderWidth
            radius: Theme.radiusSmall
            clip: true

            Text {
                anchors.centerIn: parent
                width: Math.max(0, parent.width - Theme.spacing32)
                visible: root.loading
                text: root.loadingText
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeNormal
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            Text {
                anchors.centerIn: parent
                width: Math.max(0, parent.width - Theme.spacing32)
                visible: !root.loading && root.errorText !== ""
                text: root.errorText
                color: Theme.alertWarning
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeNormal
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            Text {
                anchors.centerIn: parent
                width: Math.max(0, parent.width - Theme.spacing32)
                visible: !root.loading && root.errorText === "" && root.text === ""
                text: root.emptyText
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeNormal
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: Theme.borderWidth
                spacing: 0
                visible: !root.loading && root.errorText === "" && root.text !== ""

                Rectangle {
                    id: lineNumberGutter
                    Layout.fillHeight: true
                    Layout.preferredWidth: Math.max(
                        42,
                        codeFontMetrics.averageCharacterWidth * String(root.lineCount).length + Theme.spacing16
                    )
                    color: Theme.contentPanelSurface

                    Rectangle {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        width: Theme.borderWidth
                        color: Theme.inputBorderColor
                    }

                    TextArea {
                        id: lineNumberArea
                        objectName: "configViewerLineNumbers"
                        x: 0
                        y: -root.verticalScrollContentY
                        width: lineNumberGutter.width - Theme.borderWidth
                        height: Math.max(
                            lineNumberGutter.height + root.verticalScrollContentY,
                            contentHeight + root.codeLineHeight
                        )
                        text: root.syntaxHighlightingActive
                              ? '<pre style="margin:0">' + root.lineNumberText + "</pre>"
                              : root.lineNumberText
                        textFormat: root.syntaxHighlightingActive
                                    ? TextEdit.RichText
                                    : TextEdit.PlainText
                        readOnly: true
                        selectByMouse: false
                        wrapMode: TextEdit.NoWrap
                        color: Theme.textDisabled
                        font.family: "Consolas"
                        font.pixelSize: root.fontPixelSize
                        horizontalAlignment: Text.AlignRight
                        leftPadding: 0
                        rightPadding: Theme.spacing8
                        topPadding: 0
                        bottomPadding: root.codeLineHeight
                        background: null

                        Accessible.ignored: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: function(mouse) {
                            const visibleLine = Math.floor(
                                (mouse.y + root.verticalScrollContentY) / root.codeLineHeight
                            )
                            root.selectLine(Math.max(0, Math.min(root.lineCount - 1, visibleLine)))
                        }

                        WheelHandler {
                            target: null
                            acceptedModifiers: Qt.ControlModifier
                            onWheel: function(event) {
                                if (event.angleDelta.y > 0)
                                    root.zoomIn()
                                else if (event.angleDelta.y < 0)
                                    root.zoomOut()
                                event.accepted = true
                            }
                        }

                        WheelHandler {
                            target: null
                            acceptedModifiers: Qt.NoModifier
                            onWheel: function(event) {
                                if (root.handleVerticalWheel(event.angleDelta.y, event.pixelDelta.y))
                                    event.accepted = true
                            }
                        }
                    }
                }

                ScrollView {
                    id: textScroll
                    objectName: "configViewerScrollView"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    ScrollBar.horizontal.policy: ScrollBar.AsNeeded
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded

                    Connections {
                        target: textScroll.contentItem
                        function onContentYChanged() {
                            root.snapVerticalScroll()
                        }
                    }

                    TextArea {
                        id: configTextArea
                        objectName: "configViewerTextArea"
                        text: root.syntaxHighlightingActive ? root.highlightedText : root.text
                        readOnly: true
                        selectByMouse: true
                        persistentSelection: true
                        textFormat: root.syntaxHighlightingActive
                                    ? TextEdit.RichText
                                    : TextEdit.PlainText
                        wrapMode: TextEdit.NoWrap
                        color: Theme.textPrimary
                        selectedTextColor: Theme.selectionForeground
                        selectionColor: Theme.selectionBackground
                        font.family: "Consolas"
                        font.pixelSize: root.fontPixelSize
                        leftPadding: Theme.spacing8
                        rightPadding: Theme.spacing8
                        topPadding: 0
                        bottomPadding: root.codeLineHeight
                        background: null

                        Accessible.role: Accessible.StaticText
                        Accessible.name: root.sourceLabel

                        WheelHandler {
                            objectName: "configViewerZoomWheelHandler"
                            target: null
                            acceptedModifiers: Qt.ControlModifier
                            onWheel: function(event) {
                                if (event.angleDelta.y > 0)
                                    root.zoomIn()
                                else if (event.angleDelta.y < 0)
                                    root.zoomOut()
                                event.accepted = true
                            }
                        }

                        WheelHandler {
                            objectName: "configViewerLineScrollWheelHandler"
                            target: null
                            acceptedModifiers: Qt.NoModifier
                            onWheel: function(event) {
                                if (root.handleVerticalWheel(event.angleDelta.y, event.pixelDelta.y))
                                    event.accepted = true
                            }
                        }
                    }
                }
            }
        }

        RowLayout {
            id: viewerBottomToolbar
            objectName: "configViewerBottomToolbar"
            Layout.fillWidth: true
            spacing: Theme.spacing4

            StandardTextField {
                id: searchField
                objectName: "configViewerSearchField"
                Layout.minimumWidth: 180
                Layout.preferredWidth: 300
                Layout.maximumWidth: 420
                placeholderText: "Find in configuration (Ctrl+F)"
                text: root.searchText
                enabled: !root.loading && root.errorText === "" && root.text !== ""
                onTextEdited: function(value) { root.searchText = value }
                onAccepted: root.findNext()
                onReverseAccepted: root.findPrevious()
            }

            Text {
                Layout.preferredWidth: 72
                text: {
                    if (root.searchText === "") return ""
                    if (root.matchCount === 0) return "No matches"
                    const current = root.currentMatchIndex < 0 ? "–" : String(root.currentMatchIndex + 1)
                    return current + " / " + root.matchCount + (root.searchResultsTruncated ? "+" : "")
                }
                color: root.searchText !== "" && root.matchCount === 0
                       ? Theme.alertWarning
                       : Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                horizontalAlignment: Text.AlignHCenter
            }

            StandardButton {
                objectName: "configViewerPreviousButton"
                type: "Icon"
                tooltip: "Previous match (Shift+Enter)"
                icon.source: AppAssets.resource("resources/general/chevron-up.svg")
                enabled: root.matchCount > 0
                onClicked: root.findPrevious()
            }

            StandardButton {
                objectName: "configViewerNextButton"
                type: "Icon"
                tooltip: "Next match (Enter)"
                icon.source: AppAssets.resource("resources/general/chevron-down.svg")
                enabled: root.matchCount > 0
                onClicked: root.findNext()
            }

            Item { Layout.fillWidth: true }

            Text {
                visible: root.highlightingInProgress || root.highlightingSkippedForLargeText
                text: root.highlightingInProgress
                      ? "Highlighting…"
                      : "Plain text · large file"
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeCaption
            }

            Text {
                text: "Zoom"
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
            }

            StandardButton {
                objectName: "configViewerZoomOutButton"
                Layout.preferredWidth: 34
                type: "Secondary"
                text: "−"
                tooltip: "Zoom out"
                enabled: root.fontPixelSize > root.minimumFontPixelSize
                onClicked: root.zoomOut()
            }

            Text {
                Layout.preferredWidth: 44
                text: root.fontPixelSize + " px"
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                horizontalAlignment: Text.AlignHCenter
            }

            StandardButton {
                objectName: "configViewerZoomInButton"
                Layout.preferredWidth: 34
                type: "Secondary"
                text: "+"
                tooltip: "Zoom in"
                enabled: root.fontPixelSize < root.maximumFontPixelSize
                onClicked: root.zoomIn()
            }

            StandardButton {
                objectName: "configViewerResetZoomButton"
                type: "Secondary"
                text: "Reset"
                tooltip: "Reset zoom"
                enabled: root.fontPixelSize !== root.defaultFontPixelSize
                onClicked: root.resetZoom()
            }
        }
    }
}
