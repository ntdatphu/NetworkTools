pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

Rectangle {
    id: root

    required property var backend

    color: Theme.contentPanelSurface
    border.color: Theme.contentPanelBorder
    border.width: Theme.borderWidth
    radius: Theme.radiusSmall
    clip: true

    SplitView {
        anchors.fill: parent
        orientation: Qt.Horizontal

        handle: StandardSplitHandle {}

        ColumnLayout {
            SplitView.fillWidth: true
            SplitView.minimumWidth: 260
            spacing: 0

            Text {
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.itemHeight
                Layout.leftMargin: Theme.spacing8
                text: "Packet details"
                color: Theme.textPrimary
                font.bold: true
                font.pixelSize: Theme.fontSizeSmall
                font.family: Theme.fontFamily
                verticalAlignment: Text.AlignVCenter
            }

            ListView {
                id: detailList
                objectName: "logPacketDetails"
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.backend ? root.backend.packetDetailModel : null

                delegate: RowLayout {
                    required property int depth
                    required property string name
                    required property string value

                    width: detailList.width
                    height: Math.max(26, detailValue.implicitHeight + Theme.spacing4)
                    spacing: Theme.spacing8

                    Text {
                        Layout.leftMargin: Theme.spacing8 + depth * Theme.spacing12
                        Layout.preferredWidth: Math.max(100, detailList.width * 0.38 - depth * Theme.spacing12)
                        text: name
                        color: Theme.textPrimary
                        font.bold: value === ""
                        font.pixelSize: Theme.fontSizeSmall
                        font.family: Theme.fontFamily
                        elide: Text.ElideRight
                    }
                    Text {
                        id: detailValue
                        Layout.fillWidth: true
                        Layout.rightMargin: Theme.spacing8
                        text: value
                        color: Theme.textSecondary
                        font.pixelSize: Theme.fontSizeSmall
                        font.family: Theme.monoFontFamily
                        wrapMode: Text.WrapAnywhere
                    }
                }
                ScrollBar.vertical: ScrollBar {}
            }
        }

        ColumnLayout {
            SplitView.fillWidth: true
            SplitView.minimumWidth: 260
            spacing: 0

            Text {
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.itemHeight
                Layout.leftMargin: Theme.spacing8
                text: "Packet bytes"
                color: Theme.textPrimary
                font.bold: true
                font.pixelSize: Theme.fontSizeSmall
                font.family: Theme.fontFamily
                verticalAlignment: Text.AlignVCenter
            }

            ListView {
                id: byteList
                objectName: "logPacketBytes"
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.backend ? root.backend.packetBytesModel : null

                delegate: RowLayout {
                    required property string offset
                    required property string hexBytes
                    required property string asciiText

                    width: byteList.width
                    height: 25
                    spacing: Theme.spacing8

                    Text { Layout.leftMargin: Theme.spacing8; Layout.preferredWidth: 62; text: offset; color: Theme.textDisabled; font.pixelSize: Theme.fontSizeSmall; font.family: Theme.monoFontFamily }
                    Text { Layout.preferredWidth: 300; text: hexBytes; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSmall; font.family: Theme.monoFontFamily; elide: Text.ElideRight }
                    Text { Layout.fillWidth: true; Layout.rightMargin: Theme.spacing8; text: asciiText; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSmall; font.family: Theme.monoFontFamily; elide: Text.ElideRight }
                }
                ScrollBar.vertical: ScrollBar {}
            }
        }
    }
}
