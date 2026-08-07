pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Dialogs

FileDialog {
    id: root

    signal projectSelected(url projectUrl)

    title: "Open NetworkTools Project"
    fileMode: FileDialog.OpenFile
    nameFilters: ["NetworkTools Projects (*.ntp)", "All Files (*)"]
    onAccepted: root.projectSelected(selectedFile)
}
