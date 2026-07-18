pragma ComponentBehavior: Bound
pragma Singleton

import QtQuick

QtObject {
    // This singleton is the only QML file allowed to contain SVG paths.
    // Consumers use the semantic properties below so resource moves stay local.
    function resource(relativePath) {
        if (typeof AppPaths === "undefined" || AppPaths === null)
            return ""
        try {
            return AppPaths.resource(relativePath)
        } catch (error) {
            return ""
        }
    }

    readonly property url actionAdd: resource("resources/actions/add.svg")
    readonly property url actionBackup: resource("resources/actions/backup.svg")
    readonly property url actionClear: resource("resources/actions/clear.svg")
    readonly property url actionClose: resource("resources/actions/close.svg")
    readonly property url actionConnect: resource("resources/actions/connect.svg")
    readonly property url actionCopy: resource("resources/actions/copy.svg")
    readonly property url actionDatabaseReload: resource("resources/actions/database-reload.svg")
    readonly property url actionDelete: resource("resources/actions/delete.svg")
    readonly property url actionDisconnect: resource("resources/actions/disconnect.svg")
    readonly property url actionDownload: resource("resources/actions/download.svg")
    readonly property url actionEdit: resource("resources/actions/edit.svg")
    readonly property url actionFilter: resource("resources/actions/filter.svg")
    readonly property url actionListAdd: resource("resources/actions/list-add.svg")
    readonly property url actionMonitorStart: resource("resources/actions/monitor-start.svg")
    readonly property url actionMonitorStop: resource("resources/actions/monitor-stop.svg")
    readonly property url actionPush: resource("resources/actions/push.svg")
    readonly property url actionRefresh: resource("resources/actions/refresh.svg")
    readonly property url actionSave: resource("resources/actions/save.svg")
    readonly property url actionSearch: resource("resources/actions/search.svg")
    readonly property url actionUpload: resource("resources/actions/upload.svg")
    readonly property url actionVisibilityOff: resource("resources/actions/visibility-off.svg")
    readonly property url actionVisibilityOn: resource("resources/actions/visibility-on.svg")

    readonly property url brandLogo: resource("resources/brand/logo.svg")

    readonly property url deviceNetworkDisconnected: resource("resources/devices/network-disconnected.svg")
    readonly property url deviceNetworkEthernet: resource("resources/devices/network-ethernet.svg")
    readonly property url deviceNetworkWifi: resource("resources/devices/network-wifi.svg")
    readonly property url deviceRouter: resource("resources/devices/router.svg")
    readonly property url deviceStatusDot: resource("resources/devices/status-dot.svg")
    readonly property url deviceSwitch: resource("resources/devices/switch.svg")

    readonly property url fileGeneric: resource("resources/files/file.svg")
    readonly property url fileFolder: resource("resources/files/folder.svg")
    readonly property url fileTransferDownload: resource("resources/files/transfer-download.svg")
    readonly property url fileTransferUpload: resource("resources/files/transfer-upload.svg")
    readonly property url fileTypeCpp: resource("resources/files/types/cpp.svg")
    readonly property url fileTypeMarkdown: resource("resources/files/types/markdown.svg")
    readonly property url fileTypePython: resource("resources/files/types/python.svg")
    readonly property url fileTypeText: resource("resources/files/types/text.svg")

    readonly property url navigationBack: resource("resources/navigation/arrow-left.svg")
    readonly property url navigationChevronDown: resource("resources/navigation/chevron-down.svg")
    readonly property url navigationChevronRight: resource("resources/navigation/chevron-right.svg")
    readonly property url navigationChevronUp: resource("resources/navigation/chevron-up.svg")
    readonly property url navigationConsoleSerial: resource("resources/navigation/console-serial.svg")
    readonly property url navigationDashboard: resource("resources/navigation/dashboard.svg")
    readonly property url navigationDatabase: resource("resources/navigation/database.svg")
    readonly property url navigationDatabaseSearch: resource("resources/navigation/database-search.svg")
    readonly property url navigationInterface: resource("resources/navigation/interface.svg")
    readonly property url navigationLogs: resource("resources/navigation/logs.svg")
    readonly property url navigationSettings: resource("resources/navigation/settings.svg")
    readonly property url navigationSftp: resource("resources/navigation/sftp.svg")
    readonly property url navigationTerminal: resource("resources/navigation/terminal.svg")
    readonly property url navigationTopology: resource("resources/navigation/topology.svg")

    readonly property url statusDoNotDisturb: resource("resources/status/do-not-disturb.svg")
    readonly property url statusError: resource("resources/status/error.svg")
    readonly property url statusInfo: resource("resources/status/info.svg")
    readonly property url statusNotification: resource("resources/status/notification.svg")
    readonly property url statusNotificationUnread: resource("resources/status/notification-unread.svg")
    readonly property url statusPython: resource("resources/status/python.svg")
    readonly property url statusSuccess: resource("resources/status/success.svg")
    readonly property url statusWarning: resource("resources/status/warning.svg")

    // The information destination and informational status share one SVG.
    readonly property url navigationInformation: statusInfo

    function fileTypeIcon(fileName) {
        const dot = fileName.lastIndexOf(".")
        const extension = dot >= 0 ? fileName.slice(dot + 1).toLowerCase() : ""
        if (extension === "py")
            return fileTypePython
        if (["c", "cc", "cpp", "cxx", "h", "hh", "hpp", "hxx"].indexOf(extension) >= 0)
            return fileTypeCpp
        if (["md", "markdown"].indexOf(extension) >= 0)
            return fileTypeMarkdown
        if (["txt", "log", "ini", "cfg", "conf"].indexOf(extension) >= 0)
            return fileTypeText
        return ""
    }
}
