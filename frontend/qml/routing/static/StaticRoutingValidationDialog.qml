import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import NetworkUI

Rectangle {
    id: root

    property var form

    anchors.fill: parent
    visible: root.form.showValidationDialog
    color: "#80000000"
    z: 1000

    TapHandler {
        onTapped: {
            // Block taps to content behind dialog.
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width - 32, 520)
        radius: 8
        color: Theme.contentBackground
        border.color: Theme.alertError
        border.width: 1
        implicitHeight: dialogContent.implicitHeight + 24

        ColumnLayout {
            id: dialogContent
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            Text {
                text: "Thieu thong tin"
                color: Theme.alertError
                font.pixelSize: Theme.fontSizeNormal
                font.family: Theme.fontFamily
                font.bold: true
            }

            Text {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: root.form.validationMessage
                color: Theme.textPrimary
                font.pixelSize: Theme.fontSizeSmall
                font.family: Theme.fontFamily
            }

            Item { Layout.fillWidth: true; implicitHeight: 2 }

            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }

                Rectangle {
                    Layout.preferredWidth: 88
                    Layout.preferredHeight: 30
                    radius: 4
                    color: okDialogHover.hovered ? Qt.lighter(Theme.accentColor, 1.2) : Theme.accentColor

                    Text {
                        anchors.centerIn: parent
                        text: "OK"
                        color: Theme.buttonTextSolid
                        font.pixelSize: Theme.fontSizeSmall
                        font.family: Theme.fontFamily
                        font.bold: true
                    }

                    HoverHandler { id: okDialogHover }
                    TapHandler {
                        onTapped: {
                            root.form.showValidationDialog = false
                        }
                    }
                }
            }
        }
    }
}
