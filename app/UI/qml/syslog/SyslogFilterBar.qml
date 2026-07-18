pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import UI

Rectangle {
    id: root
    objectName: "syslogFilterBar"

    property string selectedHost: ""
    signal filtersChanged(var filters)
    signal resetHostRequested()

    implicitHeight: 58
    color: Theme.contentPanelSurface
    border.color: Theme.contentPanelBorder
    border.width: Theme.borderWidth
    radius: Theme.radiusSmall

    function currentFilters(hostOverride) {
        const severity = severityBox.currentIndex > 0
                       ? [severityBox.currentIndex - 1]
                       : []
        return {
            "host": hostOverride === undefined ? selectedHost : hostOverride,
            "search": search.text,
            "severities": severity
        }
    }

    function emitFilters() {
        filtersChanged(currentFilters())
    }

    function resetFilters() {
        debounce.stop()
        search.clear()
        severityBox.currentIndex = 0
        if (selectedHost !== "")
            resetHostRequested()
        Qt.callLater(function() { root.filtersChanged(root.currentFilters("")) })
    }

    Timer {
        id: debounce
        interval: 280
        repeat: false
        onTriggered: root.emitFilters()
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacing12
        spacing: Theme.spacing8

        StandardTextField {
            id: search
            Layout.fillWidth: true
            Layout.maximumWidth: 360
            placeholderText: "Search message or mnemonic..."
            onTextEdited: debounce.restart()
        }

        StandardComboBox {
            id: severityBox
            Layout.preferredWidth: 190
            model: [
                "All severities",
                "0 · Emergency",
                "1 · Alert",
                "2 · Critical",
                "3 · Error",
                "4 · Warning",
                "5 · Notice",
                "6 · Informational",
                "7 · Debug"
            ]
            onActivated: root.emitFilters()
        }

        Rectangle {
            Layout.preferredHeight: 28
            Layout.preferredWidth: hostLabel.implicitWidth + Theme.spacing16
            radius: Theme.radiusRound
            color: Theme.alertInfoSubtle

            Text {
                id: hostLabel
                anchors.centerIn: parent
                text: root.selectedHost === "" ? "All connected hosts" : root.selectedHost
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
            }
        }

        Item { Layout.fillWidth: true }

        StandardButton {
            text: "Reset Filters"
            type: "Secondary"
            enabled: search.text !== "" || severityBox.currentIndex > 0
                     || root.selectedHost !== ""
            onClicked: root.resetFilters()
        }
    }
}
