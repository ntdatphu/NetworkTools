pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import UI

FormSection {
    id: root
    required property var targetModel
    required property var controller
    title: "Select participating hosts (2–5 devices)"

    Repeater {
        model: root.targetModel
        delegate: RowLayout {
            required property int index
            required property string host
            required property string deviceName
            required property bool selected
            Layout.fillWidth: true
            StandardCheckBox {
                text: host
                checked: selected
                enabled: selected
                         || root.controller.selectedCount < root.controller.maxHosts
                onToggled: root.controller.updateSelected(index, checked)
            }
            Text {
                Layout.fillWidth: true
                text: deviceName
                color: Theme.textSecondary
                font.family: Theme.fontFamily
            }
        }
    }
}
