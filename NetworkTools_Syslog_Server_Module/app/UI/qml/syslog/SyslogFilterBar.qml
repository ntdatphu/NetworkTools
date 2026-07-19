import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

Rectangle {
    id: root
    property string selectedHost: ""
    property var severities: []
    signal filtersChanged(var filters)

    height: 42
    color: Theme.contentBackground

    function emitFilters() {
        filtersChanged({"host": selectedHost, "search": search.text, "severities": severities})
    }

    Timer { id: debounce; interval: 280; onTriggered: root.emitFilters() }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 6
        spacing: 8
        StandardTextField {
            id: search
            Layout.preferredWidth: 280
            placeholderText: "Search message or mnemonic..."
            onTextChanged: debounce.restart()
        }
        Text {
            text: root.selectedHost === "" ? "All connected hosts" : "Host: " + root.selectedHost
            color: Theme.textSecondary
            font.family: Theme.fontFamily
        }
        Item { Layout.fillWidth: true }
        StandardButton {
            text: "Reset"
            onClicked: {
                search.text = ""
                root.selectedHost = ""
                root.severities = []
                root.emitFilters()
            }
        }
    }
    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: Theme.borderWidth; color: Theme.borderColor }
}

