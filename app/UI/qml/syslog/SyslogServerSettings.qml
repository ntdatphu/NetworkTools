import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

ScrollView {
    id: root
    readonly property var backend: typeof syslogSettings !== "undefined" && syslogSettings !== null
                                   ? syslogSettings : null
    clip: true
    contentWidth: availableWidth
    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

    ColumnLayout {
        width: root.availableWidth
        spacing: 12

        Item { Layout.fillWidth: true; Layout.preferredHeight: 8 }
        Text {
            Layout.leftMargin: 24
            Layout.rightMargin: 24
            text: "Syslog Server"
            color: Theme.textPrimary
            font.pixelSize: Theme.fontSizeLarge
            font.family: Theme.fontFamily
            font.bold: true
        }
        Text {
            Layout.fillWidth: true
            Layout.leftMargin: 24
            Layout.rightMargin: 24
            text: "Configure the local listener and the address advertised to network devices. Restart the listener after changing connection settings."
            color: Theme.textSecondary
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.leftMargin: 24
            Layout.rightMargin: 24
            Layout.preferredHeight: settingsForm.implicitHeight + 24
            color: Theme.searchBackground2
            radius: Theme.borderRadius
            border.width: Theme.borderWidth
            border.color: Theme.borderColor

            GridLayout {
                id: settingsForm
                anchors.fill: parent
                anchors.margins: 12
                columns: 2
                columnSpacing: 12
                rowSpacing: 10

                StandardCheckBox {
                    Layout.columnSpan: 2
                    text: "Start listener when NetworkTools starts"
                    enabled: root.backend !== null
                    checked: root.backend !== null ? root.backend.enabledOnStartup : false
                    onToggled: if (root.backend !== null) root.backend.enabledOnStartup = checked
                }
                StandardComboBox {
                    Layout.fillWidth: true
                    labelText: "Protocol"
                    model: ["udp", "tcp"]
                    enabled: root.backend !== null
                    currentIndex: root.backend !== null && root.backend.protocol === "tcp" ? 1 : 0
                    onActivated: if (root.backend !== null) root.backend.protocol = currentText
                }
                StandardSpinBox {
                    Layout.fillWidth: true
                    labelText: "Port"
                    from: 1
                    to: 65535
                    enabled: root.backend !== null
                    value: root.backend !== null ? root.backend.port : 5514
                    onValueChanged: {
                        if (root.backend !== null && root.backend.port !== value)
                            root.backend.port = value
                    }
                }
                StandardTextField {
                    Layout.fillWidth: true
                    labelText: "Bind IP"
                    enabled: root.backend !== null
                    text: root.backend !== null ? root.backend.bindIp : "0.0.0.0"
                    placeholderText: "0.0.0.0"
                    onEditingFinished: if (root.backend !== null) root.backend.bindIp = text
                }
                StandardComboBox {
                    Layout.fillWidth: true
                    labelText: "Advertised/server IP"
                    enabled: root.backend !== null
                    model: root.backend !== null ? root.backend.availableAdvertisedIps : []
                    currentIndex: root.backend !== null
                                  ? root.backend.availableAdvertisedIps.indexOf(root.backend.advertisedIp)
                                  : -1
                    emptyText: "No active local IPv4 address"
                    emptyWarningText: "No active local IPv4 address was detected. Connect a network adapter and reopen this setting."
                    onActivated: if (root.backend !== null) root.backend.advertisedIp = currentText
                }
                StandardSpinBox {
                    Layout.fillWidth: true
                    labelText: "Retention days"
                    from: 1
                    to: 3650
                    enabled: root.backend !== null
                    value: root.backend !== null ? root.backend.retentionDays : 30
                    onValueChanged: {
                        if (root.backend !== null && root.backend.retentionDays !== value)
                            root.backend.retentionDays = value
                    }
                }
                Item { Layout.fillWidth: true }
                StandardButton {
                    text: "Validate settings"
                    enabled: root.backend !== null
                    onClicked: {
                        const result = root.backend.validate()
                        validation.text = result.message
                        validation.color = result.ok ? Theme.alertSuccess : Theme.alertError
                    }
                }
                Text {
                    id: validation
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                }
            }
        }
        Item { Layout.fillHeight: true }
    }

    onVisibleChanged: if (visible && root.backend !== null) root.backend.refreshLocalIps()
}
