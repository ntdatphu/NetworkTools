import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

ScrollView {
    id: root
    clip: true
    contentWidth: availableWidth

    ColumnLayout {
        width: root.availableWidth
        anchors.margins: 20
        spacing: 12
        Text { text: "Syslog Server"; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeLarge }
        Text { text: "Restart the listener after changing protocol, bind IP, or port."; color: Theme.textSecondary }
        StandardCheckBox {
            text: "Start listener when NetworkTools starts"
            checked: syslogSettings.enabledOnStartup
            onToggled: syslogSettings.enabledOnStartup = checked
        }
        Text { text: "Protocol"; color: Theme.textSecondary }
        StandardComboBox {
            model: ["udp", "tcp"]
            currentIndex: syslogSettings.protocol === "tcp" ? 1 : 0
            onActivated: syslogSettings.protocol = currentText
        }
        Text { text: "Bind IP"; color: Theme.textSecondary }
        StandardTextField { text: syslogSettings.bindIp; onEditingFinished: syslogSettings.bindIp = text }
        Text { text: "Advertised/server IP"; color: Theme.textSecondary }
        StandardTextField { text: syslogSettings.advertisedIp; onEditingFinished: syslogSettings.advertisedIp = text }
        Text { text: "Port"; color: Theme.textSecondary }
        StandardSpinBox { from: 1; to: 65535; value: syslogSettings.port; onValueModified: syslogSettings.port = value }
        Text { text: "Retention days"; color: Theme.textSecondary }
        StandardSpinBox { from: 1; to: 3650; value: syslogSettings.retentionDays; onValueModified: syslogSettings.retentionDays = value }
        StandardButton {
            text: "Validate settings"
            onClicked: {
                const result = syslogSettings.validate()
                validation.text = result.message
                validation.color = result.ok ? Theme.statusConnected : Theme.statusError
            }
        }
        Text { id: validation; Layout.fillWidth: true; wrapMode: Text.WordWrap; color: Theme.textSecondary }
        Item { Layout.fillHeight: true }
    }
}

