import QtQuick
import QtQuick.Layouts
import UI

Item {
    id: root
    property string selectedHost: ""
    property bool uiPaused: false
    property var activeFilters: ({})
    property bool hasMore: false
    property string requestId: ""

    function reload() {
        logModel.clear()
        requestId = String(Date.now())
        syslogManager.queryMessages(requestId, activeFilters, 0, 200)
    }

    function loadOlder() {
        const lastId = logModel.count > 0 ? Number(logModel.get(logModel.count - 1).id) : 0
        requestId = String(Date.now())
        syslogManager.queryMessages(requestId, activeFilters, lastId, 200)
    }

    ListModel { id: logModel }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        SyslogControlBar {
            Layout.fillWidth: true
            state: syslogManager.listenerState
            statusText: syslogManager.statusMessage
            receivedCount: syslogManager.receivedCount
            droppedCount: syslogManager.droppedCount
            onStartRequested: syslogManager.startServer()
            onStopRequested: syslogManager.stopServer()
            onPauseChanged: paused => root.uiPaused = paused
            onClearRequested: logModel.clear()
        }
        SyslogFilterBar {
            Layout.fillWidth: true
            selectedHost: root.selectedHost
            onFiltersChanged: filters => { root.activeFilters = filters; root.reload() }
        }
        SyslogLogTable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: logModel
            hasMore: root.hasMore
            onLoadOlderRequested: root.loadOlder()
            onMessageActivated: data => { details.rowData = data; details.open() }
        }
    }

    SyslogMessageDetails { id: details }

    Connections {
        target: syslogManager
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
    }

    Component.onCompleted: reload()
}

