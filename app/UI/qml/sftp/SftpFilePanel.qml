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
    property bool remoteSide: false
    property int selectedIndex: -1
    property string editMode: ""

    color: Theme.contentPanelSurface
    border.color: Theme.contentPanelBorder
    border.width: Theme.borderWidth
    radius: Theme.radiusSmall
    enabled: !remoteSide || backend.connected
    opacity: enabled ? 1.0 : 0.55

    function selectedItem() {
        return selectedIndex >= 0 ? fileModel.get(selectedIndex) : null
    }
    function refresh() {
        selectedIndex = -1
        if (remoteSide)
            backend.refreshRemote()
        else
            backend.refreshLocal()
    }
    function goUp() {
        selectedIndex = -1
        if (remoteSide)
            backend.remoteGoUp()
        else
            backend.localGoUp()
    }
    function openPath(path) {
        selectedIndex = -1
        if (remoteSide)
            backend.openRemoteDirectory(path)
        else
            backend.openLocalDirectory(path)
    }
    function openSelected() {
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
        editMode = mode
        const item = selectedItem()
        nameField.text = mode === "rename" && item ? item.name : ""
        entryDialog.open()
        nameField.forceActiveFocus()
    }

    onCurrentPathChanged: pathField.text = currentPath
    Component.onCompleted: pathField.text = currentPath

    Dialog {
        id: entryDialog
        parent: Overlay.overlay
        anchors.centerIn: parent
        modal: true
        title: root.editMode === "rename" ? "Rename entry" : "Create folder"
        standardButtons: Dialog.NoButton
        closePolicy: Popup.CloseOnEscape

        contentItem: ColumnLayout {
            spacing: Theme.spacing12
            StandardTextField {
                id: nameField
                Layout.preferredWidth: 360
                labelText: "Name"
                onAccepted: applyButton.clicked()
            }
            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                StandardButton {
                    text: "Cancel"
                    type: "Text"
                    onClicked: entryDialog.reject()
                }
                StandardButton {
                    id: applyButton
                    text: root.editMode === "rename" ? "Rename" : "Create"
                    type: "Primary"
                    enabled: nameField.text.trim() !== ""
                    onClicked: {
                        if (root.editMode === "rename")
                            root.backend.renameEntry(root.remoteSide, root.selectedIndex, nameField.text)
                        else
                            root.backend.createDirectory(root.remoteSide, nameField.text)
                        entryDialog.accept()
                    }
                }
            }
        }
    }

    SftpMessageDialog {
        id: deleteDialog
        titleText: "Delete entry"
        confirmation: true
        onAccepted: {
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
                    ? root.backend.statusMessage
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
                onAccepted: root.openPath(text)
            }
            StandardButton {
                text: "Up"
                type: "Ghost"
                onClicked: root.goUp()
            }
            StandardButton {
                text: "Refresh"
                icon.source: AppAssets.resource("resources/sidebar/refresh.svg")
                type: "Ghost"
                onClicked: root.refresh()
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
                enabled: root.selectedIndex >= 0
                onClicked: root.beginEdit("rename")
            }
            StandardButton {
                text: "Delete"
                type: "Danger"
                enabled: root.selectedIndex >= 0
                onClicked: {
                    const item = root.selectedItem()
                    if (!item)
                        return
                    deleteDialog.messageText = "Delete \"" + item.name + "\"?\n\n"
                        + "Directories must be empty; recursive deletion is disabled."
                    deleteDialog.open()
                }
            }
            StandardButton {
                text: root.remoteSide ? "Download" : "Upload"
                type: "Primary"
                enabled: root.selectedIndex >= 0 && root.backend.connected
                onClicked: {
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
                width: fileList.width
                height: Theme.tableRowHeight
                rowIndex: index
                selected: root.selectedIndex === index

                RowLayout {
                    anchors.fill: parent
                    spacing: Theme.spacing8
                    Text {
                        Layout.preferredWidth: 22
                        text: row.isDirectory ? "▸" : "·"
                        color: root.selectedIndex === row.index
                             ? Theme.selectionForeground
                             : row.isDirectory ? Theme.alertWarning : Theme.alertInfo
                        font.pixelSize: Theme.fontSizeLarge
                    }
                    Text {
                        Layout.fillWidth: true
                        text: row.name
                        elide: Text.ElideRight
                        color: root.selectedIndex === row.index
                             ? Theme.selectionForeground : Theme.textPrimary
                        font.family: Theme.fontFamily
                    }
                    Text {
                        Layout.preferredWidth: 90
                        text: row.sizeText
                        color: root.selectedIndex === row.index
                             ? Theme.selectionForeground : Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                    }
                    Text {
                        Layout.preferredWidth: 140
                        text: row.modified
                        elide: Text.ElideRight
                        color: root.selectedIndex === row.index
                             ? Theme.selectionForeground : Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }
                TapHandler {
                    acceptedButtons: Qt.LeftButton
                    onTapped: root.selectedIndex = row.index
                    onDoubleTapped: {
                        root.selectedIndex = row.index
                        root.openSelected()
                    }
                }
            }

            EmptyState {
                anchors.fill: parent
                visible: fileList.count === 0
                title: root.remoteSide && !root.backend.connected
                    ? "Connect to an SFTP server"
                    : "This directory is empty"
                description: root.remoteSide && !root.backend.connected
                    ? "Enter a connection above to browse the remote file system."
                    : "No files or folders are available at this path."
            }
        }
    }
}
