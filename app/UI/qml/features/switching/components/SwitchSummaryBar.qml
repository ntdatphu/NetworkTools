pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import UI

Rectangle {
    id: root

    property var metrics: []

    function toneColor(tone) {
        switch (String(tone || "neutral")) {
        case "accent": return Theme.accentColor
        case "success": return Theme.alertSuccess
        case "warning": return Theme.alertWarning
        case "danger": return Theme.alertError
        default: return Theme.textPrimary
        }
    }

    implicitHeight: 62
    color: Theme.contentPanelSurface
    border.color: Theme.contentPanelBorder
    border.width: Theme.borderWidth
    radius: Theme.radiusSmall

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.spacing12
        anchors.rightMargin: Theme.spacing12
        spacing: 0

        Repeater {
            model: root.metrics

            delegate: RowLayout {
                required property int index
                required property var modelData

                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: Theme.spacing2

                    Text {
                        Layout.fillWidth: true
                        text: String(modelData.label || "")
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: String(modelData.value === undefined ? "—" : modelData.value)
                        color: root.toneColor(modelData.tone)
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeTitle
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                }

                Rectangle {
                    visible: index < root.metrics.length - 1
                    Layout.fillHeight: true
                    Layout.topMargin: Theme.spacing12
                    Layout.bottomMargin: Theme.spacing12
                    Layout.leftMargin: Theme.spacing12
                    Layout.rightMargin: Theme.spacing12
                    Layout.preferredWidth: Theme.borderWidth
                    color: Theme.contentPanelBorder
                }
            }
        }
    }
}
