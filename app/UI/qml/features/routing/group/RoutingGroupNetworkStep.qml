pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import UI

FormSection {
    id: root
    required property var targetModel
    required property var controller
    required property string protocol
    title: protocol === "ospf"
           ? "Connected networks and OSPF area"
           : "Connected networks"

    Repeater {
        model: root.targetModel
        delegate: ColumnLayout {
            id: hostNetworkBlock
            required property int index
            required property string host
            required property bool selected
            required property var networks
            property int hostIndex: index
            visible: selected
            Layout.fillWidth: true
            Text {
                text: host
                color: Theme.accentColor
                font.family: Theme.fontFamily
                font.bold: true
            }
            Repeater {
                model: networks
                delegate: RowLayout {
                    required property int index
                    required property var modelData
                    Layout.fillWidth: true
                    StandardCheckBox {
                        text: modelData.network + " /" + modelData.prefix_length
                        checked: modelData.selected === true
                        onToggled: root.controller.updateNetwork(
                                       hostNetworkBlock.hostIndex,
                                       index, "selected", checked)
                    }
                    Text {
                        Layout.fillWidth: true
                        text: (modelData.interfaces || []).map(
                                  item => item.interface_name).join(", ")
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                    }
                    StandardTextField {
                        visible: root.protocol === "ospf"
                        Layout.preferredWidth: 100
                        labelText: "Area"
                        text: modelData.area || "0"
                        onTextEdited: value => root.controller.updateNetwork(
                                          hostNetworkBlock.hostIndex,
                                          index, "area", value)
                    }
                }
            }
        }
    }
}
