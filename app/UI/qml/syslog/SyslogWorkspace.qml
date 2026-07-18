import QtQuick
import QtQuick.Layouts
import UI

Rectangle {
    id: root
    color: Theme.contentBackground
    property string selectedHost: ""
    property bool uiPaused: false
    property var activeFilters: ({"host": "", "search": "", "severities": []})
    property bool hasMore: false
    property string requestId: ""
    readonly property var backend: typeof syslogManager !== "undefined" && syslogManager !== null
                                   ? syslogManager : null

    function reload() {
        logModel.clear()
        requestId = String(Date.now())
        if (backend !== null)
            backend.queryMessages(requestId, activeFilters, 0, 200)
    }

    function loadOlder() {
        const lastId = logModel.count > 0 ? Number(logModel.get(logModel.count - 1).id) : 0
        requestId = String(Date.now())
        if (backend !== null)
            backend.queryMessages(requestId, activeFilters, lastId, 200)
    }

    ListModel { id: logModel }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        SyslogControlBar {
            Layout.fillWidth: true
            listenerState: root.backend !== null ? root.backend.listenerState : "stopped"
            statusText: root.backend !== null ? root.backend.statusMessage : "Syslog backend is unavailable."
            receivedCount: root.backend !== null ? root.backend.receivedCount : 0
            droppedCount: root.backend !== null ? root.backend.droppedCount : 0
            onStartRequested: {
                if (root.backend === null) return
                const result = root.backend.startServer()
                root.operationMessage(result.ok, result.message)
            }
            onStopRequested: {
                if (root.backend === null) return
                const result = root.backend.stopServer()
                root.operationMessage(result.ok, result.message)
            }
            onPauseChanged: paused => root.uiPaused = paused
            onClearRequested: logModel.clear()
        }
        SyslogFilterBar {
            Layout.fillWidth: true
            selectedHost: root.selectedHost
            onFiltersChanged: function(filters) {
                root.activeFilters = filters
                root.reload()
            }
            onResetHostRequested: root.selectedHost = ""
        }
        SyslogLogTable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: logModel
            hasMore: root.hasMore
            onLoadOlderRequested: root.loadOlder()
            onMessageActivated: function(data) {
                details.rowData = data
                details.open()
            }
        }
    }

    signal operationMessage(bool ok, string message)
    SyslogMessageDetails { id: details }

    onSelectedHostChanged: {
        activeFilters = {
            "host": selectedHost,
            "search": activeFilters.search || "",
            "severities": activeFilters.severities || []
        }
        reload()
    }

    Connections {
        target: root.backend
        function onMessagesInserted(rows) {
            if (root.uiPaused) return
            for (let i = rows.length - 1; i >= 0; --i)
                logModel.insert(0, rows[i])
            while (logModel.count > 2000)
                logModel.remove(logModel.count - 1)
        }
        function onQueryFinished(id, rows, more) {
            if (id !== root.requestId) return
            for (let i = 0; i < rows.length; ++i)
                logModel.append(rows[i])
            root.hasMore = more
        }
        function onErrorOccurred(message) { root.operationMessage(false, message) }
    }

    // Hidden workspaces do not query the database during normal app startup.
    onVisibleChanged: if (visible && root.backend !== null) reload()
}
