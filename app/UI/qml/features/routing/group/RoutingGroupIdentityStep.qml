pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import UI

FormSection {
    id: root
    required property var targetModel
    required property string protocol
    title: "Per-host Process ID and Router ID"

    Repeater {
        model: root.targetModel
        delegate: RowLayout {
            required property int index
            required property string host
            required property bool selected
            required property string processId
            required property string routerId
            visible: selected
            Layout.fillWidth: true
            Text {
                Layout.preferredWidth: 160
                text: host
                color: Theme.textPrimary
                font.family: Theme.fontFamily
            }
            StandardTextField {
                Layout.fillWidth: true
                labelText: root.protocol === "ospf" ? "Process ID" : "AS Number"
                text: processId
                inputMethodHints: Qt.ImhDigitsOnly
                onTextEdited: value => root.targetModel.setProperty(
                                  index, "processId", value)
            }
            StandardNetworkField {
                Layout.fillWidth: true
                inputKind: "ipv4"
                labelText: "Router ID (optional)"
                text: routerId
                onTextEdited: value => root.targetModel.setProperty(
                                  index, "routerId", value)
            }
        }
    }
}
