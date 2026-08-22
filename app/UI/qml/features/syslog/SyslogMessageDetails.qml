pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

StandardDialog {
    id: root

    property var rowData: ({})

    preferredWidth: 780
    height: Math.min(560, parent.height - Theme.spacing24 * 2)
    title: "System Log Message"
    subtitle: String(root.rowData.device_host || root.rowData.source_ip || "Unknown host")
    closeTooltip: "Close system log message"

    contentItem: ColumnLayout {
        spacing: Theme.spacing12

        GridLayout {
            Layout.fillWidth: true
            columns: 4
            columnSpacing: Theme.spacing12
            rowSpacing: Theme.spacing8

            Text { text: "Source"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall }
            Text { Layout.fillWidth: true; text: String(root.rowData.source_ip || "—"); color: Theme.textPrimary; font.family: Theme.monoFontFamily; elide: Text.ElideRight }
            Text { text: "Protocol"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall }
            Text { Layout.fillWidth: true; text: String(root.rowData.protocol || "—").toUpperCase(); color: Theme.textPrimary; font.family: Theme.fontFamily }

            Text { text: "Received"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall }
            Text { Layout.fillWidth: true; text: String(root.rowData.received_at || "—"); color: Theme.textPrimary; font.family: Theme.monoFontFamily; elide: Text.ElideRight }
            Text { text: "Device time"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall }
            Text { Layout.fillWidth: true; text: String(root.rowData.device_time || "—"); color: Theme.textPrimary; font.family: Theme.monoFontFamily; elide: Text.ElideRight }

            Text { text: "PRI / Syslog facility"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall }
            Text { Layout.fillWidth: true; text: "%1 / %2".arg(root.rowData.syslog_pri === undefined || root.rowData.syslog_pri === null ? "—" : root.rowData.syslog_pri).arg(root.rowData.syslog_facility === undefined || root.rowData.syslog_facility === null ? "—" : root.rowData.syslog_facility); color: Theme.textPrimary; font.family: Theme.monoFontFamily }
            Text { text: "Parse status"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall }
            Text { Layout.fillWidth: true; text: String(root.rowData.parse_status || "—"); color: Theme.textPrimary; font.family: Theme.fontFamily }

            Text { text: "Cisco facility"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall }
            Text { Layout.fillWidth: true; text: String(root.rowData.cisco_facility || root.rowData.facility || "—"); color: Theme.textPrimary; font.family: Theme.monoFontFamily; elide: Text.ElideRight }
            Text { text: "Subfacility"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall }
            Text { Layout.fillWidth: true; text: String(root.rowData.cisco_subfacility || "—"); color: Theme.textPrimary; font.family: Theme.monoFontFamily; elide: Text.ElideRight }

            Text { text: "Severity / Mnemonic"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall }
            Text { Layout.fillWidth: true; text: "%1 / %2".arg(root.rowData.severity === undefined ? "—" : root.rowData.severity).arg(root.rowData.mnemonic || "—"); color: Theme.textPrimary; font.family: Theme.monoFontFamily; elide: Text.ElideRight }
            Text { text: "Sequence / Clock"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall }
            Text { Layout.fillWidth: true; text: "%1 / %2".arg(root.rowData.sequence_number === undefined || root.rowData.sequence_number === null ? "—" : root.rowData.sequence_number).arg(root.rowData.clock_unsynchronized ? "unsynchronized" : "synchronized"); color: root.rowData.clock_unsynchronized ? Theme.alertWarning : Theme.textPrimary; font.family: Theme.monoFontFamily; elide: Text.ElideRight }
        }

        Text {
            text: "Raw message"
            color: Theme.textPrimary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeNormal
            font.bold: true
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Theme.contentBackground
            border.color: Theme.contentPanelBorder
            border.width: Theme.borderWidth
            radius: Theme.radiusSmall

            TextArea {
                anchors.fill: parent
                anchors.margins: Theme.spacing8
                readOnly: true
                selectByMouse: true
                wrapMode: TextEdit.Wrap
                text: String(root.rowData.raw_message || root.rowData.message || "")
                color: Theme.textPrimary
                selectionColor: Theme.selectionBackground
                selectedTextColor: Theme.selectionForeground
                font.family: Theme.monoFontFamily
                font.pixelSize: Theme.fontSizeSmall
                background: Rectangle { color: "transparent" }
            }
        }
    }

    footer: Rectangle {
        implicitHeight: 58
        color: "transparent"

        StandardButton {
            anchors.right: parent.right
            anchors.rightMargin: Theme.spacing16
            anchors.verticalCenter: parent.verticalCenter
            text: "Close"
            type: "Primary"
            onClicked: root.close()
        }
    }
}
