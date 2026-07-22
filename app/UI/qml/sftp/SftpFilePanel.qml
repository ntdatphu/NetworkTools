
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

Rectangle {
    id: root
    required property var backend
    required property var fileModel
    required property string currentPath
    readonly property bool backendAvailable: backend !== null && backend !== undefined
    readonly property bool remoteDisconnected: remoteSide
                                               && (!backendAvailable || !backend.connected)
    property bool remoteSide: false
    property bool activePane: false
    property int selectedIndex: -1
    property string editMode: ""
    readonly property bool pathInputFocused: pathField.inputActiveFocus
    readonly property bool canGoBack: backendAvailable
        && (remoteSide ? backend.remoteCanGoBack : backend.localCanGoBack)
    readonly property bool canGoForward: backendAvailable
        && (remoteSide ? backend.remoteCanGoForward : backend.localCanGoForward)

    signal activated()

    color: Theme.contentPanelSurface
    border.color: activePane ? Theme.accentColor : Theme.contentPanelBorder
    border.width: activePane ? 2 : Theme.borderWidth
    radius: Theme.radiusSmall
    enabled: backendAvailable && (!remoteSide || backend.connected)
    opacity: enabled ? 1.0 : 0.55

    function selectedItem() {
        return fileModel && selectedIndex >= 0 ? fileModel.get(selectedIndex) : null
    }
    function fileTypeIcon(name) {
        return AppAssets.fileTypeIcon(name)
    }
    function refresh() {
        if (!backendAvailable)
            return
        selectedIndex = -1
        if (remoteSide)
            backend.refreshRemote()
        else
            backend.refreshLocal()
    }
    function goUp() {
        if (!backendAvailable)
            return
        selectedIndex = -1
        if (remoteSide)
            backend.remoteGoUp()
        else
            backend.localGoUp()
    }
    function goBack() {
        if (!backendAvailable || !canGoBack)
            return
        selectedIndex = -1
        if (remoteSide)
            backend.remoteGoBack()
        else
            backend.localGoBack()
    }
    function goForward() {
        if (!backendAvailable || !canGoForward)
            return
        selectedIndex = -1
        if (remoteSide)
            backend.remoteGoForward()
        else
            backend.localGoForward()
    }
    function openPath(path) {
        if (!backendAvailable)
            return
        selectedIndex = -1
        if (remoteSide)
            backend.openRemoteDirectory(path)
        else
            backend.openLocalDirectory(path)
    }
    function openSelected() {
        if (!backendAvailable)
            return
        const item = selectedItem()
        if (!item)
            return
        if (item.isDirectory) {
            openPath(item.path)
        } else if (remoteSide) {
            backend.downloadFile(selectedIndex)
        } else {
            backend.uploadFile(selectedIndex)
        }
    }
    function beginEdit(mode) {
        if (!backendAvailable)
            return
        editMode = mode
        const item = selectedItem()
        entryDialog.value = mode === "rename" && item ? item.name : ""
        entryDialog.titleText = mode === "rename" ? "Rename entry" : "Create folder"
        entryDialog.acceptText = mode === "rename" ? "Rename" : "Create"
        entryDialog.open()
    }
    function requestDelete() {
        const item = selectedItem()
        if (!item)
            return
        deleteDialog.messageText = "Delete \"" + item.name + "\"?\n\n"
            + "Directories must be empty; recursive deletion is disabled."
        deleteDialog.open()
    }

    onCurrentPathChanged: pathField.text = currentPath
    Component.onCompleted: pathField.text = currentPath

    SftpEntryDialog {
        id: entryDialog
        onAccepted: {
            if (!root.backendAvailable)
                return
            if (root.editMode === "rename")
                root.backend.renameEntry(root.remoteSide, root.selectedIndex, value)
            else
                root.backend.createDirectory(root.remoteSide, value)
        }
    }

    SftpMessageDialog {
        id: deleteDialog
        titleText: "Delete entry"
        confirmation: true
        acceptText: "Delete"
        onAccepted: {
            if (!root.backendAvailable)
                return
            root.backend.deleteEntry(root.remoteSide, root.selectedIndex)
            root.selectedIndex = -1
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacing8
        spacing: Theme.spacing8

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: root.remoteSide ? "REMOTE" : "LOCAL"
                color: Theme.textPrimary
                font.bold: true
                font.family: Theme.fontFamily
            }
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
                text: root.remoteSide
                      ? (root.backendAvailable
                         ? root.backend.statusMessage
                         : "SFTP backend unavailable")
                      : "Local filesystem"
                elide: Text.ElideRight
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
            }
        }

        RowLayout {
            Layout.fillWidth: true
            StandardTextField {
                id: pathField
                Layout.fillWidth: true
                placeholderText: root.remoteSide ? "/" : "Local path"
                onAccepted: {
                    root.activated()
                    root.openPath(text)
                }
            }
            IconButton {
                objectName: root.remoteSide ? "sftpRemoteBack" : "sftpLocalBack"
                iconSource: AppAssets.navigationChevronLeft
                tooltip: "Back (Alt+Left / Mouse Back)"
                enabled: root.canGoBack
                onClicked: { root.activated(); root.goBack() }
            }
            IconButton {
                objectName: root.remoteSide ? "sftpRemoteForward" : "sftpLocalForward"
                iconSource: AppAssets.navigationChevronRight
                tooltip: "Forward (Alt+Right / Mouse Forward)"
                enabled: root.canGoForward
                onClicked: { root.activated(); root.goForward() }
            }
            IconButton {
                objectName: root.remoteSide ? "sftpRemoteUp" : "sftpLocalUp"
                iconSource: AppAssets.navigationUp
                tooltip: "Up (Alt+Up)"
                onClicked: { root.activated(); root.goUp() }
            }
            IconButton {
                objectName: root.remoteSide ? "sftpRemoteRefresh" : "sftpLocalRefresh"
                iconSource: AppAssets.actionRefresh
                tooltip: "Refresh (F5 / Ctrl+R)"
                onClicked: { root.activated(); root.refresh() }
            }
        }

        Flow {
            Layout.fillWidth: true
            spacing: Theme.spacing8
            StandardButton {
                text: "New folder"
                onClicked: root.beginEdit("create")
            }
            StandardButton {
                text: "Rename"
                icon.source: AppAssets.actionEdit
                enabled: root.selectedIndex >= 0
                onClicked: root.beginEdit("rename")
            }
            StandardButton {
                text: "Delete"
                type: "Danger"
                icon.source: AppAssets.actionDelete
                enabled: root.selectedIndex >= 0
                onClicked: {
                    root.requestDelete()
                }
            }
            StandardButton {
                text: root.remoteSide ? "Download" : "Upload"
                type: "Primary"
                icon.source: root.remoteSide
                             ? AppAssets.actionDownload
                             : AppAssets.actionUpload
                enabled: root.selectedIndex >= 0
                         && root.backendAvailable
                         && root.backend.connected
                onClicked: {
                    if (!root.backendAvailable)
                        return
                    if (root.remoteSide)
                        root.backend.downloadFile(root.selectedIndex)
                    else
                        root.backend.uploadFile(root.selectedIndex)
                }
            }
        }

        DataTableHeader {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.tableHeaderHeight

            RowLayout {
                anchors.fill: parent
                spacing: Theme.spacing8
                DataTableCell { Layout.preferredWidth: 22; header: true; text: "" }
                DataTableCell { Layout.fillWidth: true; header: true; text: "Name" }
                DataTableCell { Layout.preferredWidth: 90; header: true; text: "Size" }
                DataTableCell { Layout.preferredWidth: 140; header: true; text: "Modified" }
            }
        }

        ListView {
            id: fileList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 0
            model: root.fileModel
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
            delegate: DataTableRow {
                id: row
                required property int index
                required property string name
                required property string path
                required property bool isDirectory
                required property string sizeText
                required property string modified
                readonly property string typeIconSource: row.isDirectory
                    ? "" : root.fileTypeIcon(row.name)
                width: fileList.width
                height: Theme.tableRowHeight
                rowIndex: index
                selected: root.selectedIndex === index

                RowLayout {
                    anchors.fill: parent
                    spacing: Theme.spacing8
                    Image {
                        Layout.preferredWidth: 22
                        Layout.preferredHeight: Theme.iconSizeNormal
                        source: row.isDirectory
                                ? AppAssets.fileFolder
                                : row.typeIconSource !== ""
                                  ? row.typeIconSource
                                  : AppAssets.fileGeneric
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                    }
                    Text {
                        Layout.fillWidth: true
                        text: row.name
                        elide: Text.ElideRight
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                    }
                    Text {
                        Layout.preferredWidth: 90
                        text: row.sizeText
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                    }
                    Text {
                        Layout.preferredWidth: 140
                        text: row.modified
                        elide: Text.ElideRight
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }
                TapHandler {
                    acceptedButtons: Qt.LeftButton
                    onTapped: {
                        root.activated()
                        root.selectedIndex = row.index
                    }
                    onDoubleTapped: {
                        root.activated()
                        root.selectedIndex = row.index
                        root.openSelected()
                    }
                }
            }

            EmptyState {
                anchors.fill: parent
                visible: fileList.count === 0
                title: root.remoteDisconnected
                    ? "Connect to an SFTP server"
                    : "This directory is empty"
                description: root.remoteDisconnected
                    ? "Enter a connection above to browse the remote file system."
                    : "No files or folders are available at this path."
            }
        }
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton
        gesturePolicy: TapHandler.WithinBounds
        onTapped: root.activated()
    }
}
