import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

Rectangle {
    id: root
    property string selectedHost: ""
    signal filtersChanged(var filters)
    signal resetHostRequested()

    implicitHeight: 46
    color: Theme.contentBackground

    function emitFilters() {
        const severity = severityBox.currentIndex > 0 ? [severityBox.currentIndex - 1] : []
        filtersChanged({"host": selectedHost, "search": search.text, "severities": severity})
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
        StandardComboBox {
            id: severityBox
            Layout.preferredWidth: 165
            model: ["All severities", "0 Emergency", "1 Alert", "2 Critical", "3 Error",
                    "4 Warning", "5 Notice", "6 Informational", "7 Debug"]
            onActivated: root.emitFilters()
        }
        Text {
            text: root.selectedHost === "" ? "All hosts" : "Host: " + root.selectedHost
            color: Theme.textSecondary
            font.family: Theme.fontFamily
        }
        Item { Layout.fillWidth: true }
        StandardButton {
            text: "Reset"
            onClicked: {
                search.text = ""
                severityBox.currentIndex = 0
                root.resetHostRequested()
                root.emitFilters()
            }
        }
    }
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: Theme.borderWidth
        color: Theme.borderColor
    }
}
