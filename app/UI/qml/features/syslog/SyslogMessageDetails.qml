pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

Dialog {
    id: root

    property var rowData: ({})

    parent: Overlay.overlay
    x: Math.round((parent.width - width) / 2)
    y: Math.round((parent.height - height) / 2)
    width: Math.min(780, parent.width - Theme.spacing24 * 2)
    height: Math.min(560, parent.height - Theme.spacing24 * 2)
    modal: true
    dim: true
    padding: Theme.spacing16
    closePolicy: Popup.CloseOnEscape

    background: Rectangle {
        color: Theme.contentPanelSurface
        border.color: Theme.contentPanelBorder
        border.width: Theme.borderWidth
        radius: Theme.radiusMedium
    }

    header: Rectangle {
        implicitHeight: 56
        color: Theme.sideBarBackground
        radius: Theme.radiusMedium

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.spacing16
            anchors.rightMargin: Theme.spacing16
            spacing: Theme.spacing2

            Text {
                Layout.fillWidth: true
                text: "System Log Message"
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLarge
                font.bold: true
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                text: String(root.rowData.device_host || root.rowData.source_ip || "Unknown host")
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideRight
            }
        }
    }

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

            Text { text: "Facility / Severity"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall }
            Text { Layout.fillWidth: true; text: "%1 / %2".arg(root.rowData.facility || "—").arg(root.rowData.severity === undefined ? "—" : root.rowData.severity); color: Theme.textPrimary; font.family: Theme.fontFamily }
            Text { text: "Parse status"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall }
            Text { Layout.fillWidth: true; text: String(root.rowData.parse_status || "—"); color: Theme.textPrimary; font.family: Theme.fontFamily }

            Text { text: "Mnemonic"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall }
            Text { Layout.columnSpan: 3; Layout.fillWidth: true; text: String(root.rowData.mnemonic || "—"); color: Theme.textPrimary; font.family: Theme.monoFontFamily; elide: Text.ElideRight }
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
