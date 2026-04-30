import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import NetworkUI

Rectangle {
    id: rowRoot

    required property int rowIndex
    required property string rowNetwork
    required property string rowMask
    required property string rowNexthop
    required property var rowAd
    required property int rowRouteId
    required property string rowOriginalNetwork
    required property string rowOriginalMask
    required property string rowOriginalNexthop
    required property var rowOriginalAd
    required property int rowSuccess
    required property bool rowEdited
    required property bool rowCanEdit
    required property bool rowNetworkError
    required property bool rowMaskError
    required property bool rowNexthopError

    signal networkTextChanged(string value)
    signal maskTextChanged(string value)
    signal nextHopTextChanged(string value)
    signal adTextChanged(string value)
    signal changeClicked()
    signal cancelClicked()
    signal deleteClicked()
    signal submitRequested()

    function prefixToMask(prefix) {
        const n = parseInt(prefix, 10)
        if (n === 32) return "255.255.255.255"
        const mask = (~(0xFFFFFFFF >>> n)) >>> 0
        return [(mask >>> 24) & 0xFF,
                (mask >>> 16) & 0xFF,
                (mask >>> 8)  & 0xFF,
                 mask         & 0xFF].join(".")
    }

    Layout.fillWidth: true
    radius: 6
    color: Theme.contentBackground
    border.color: Theme.borderColor
    border.width: 1
    implicitHeight: rowLayout.implicitHeight + 12

    RowLayout {
        id: rowLayout
        anchors.fill: parent
        anchors.margins: 6
        spacing: 6

        TextField {
            id: networkInput
            Layout.fillWidth: true
            placeholderText: "Network"
            placeholderTextColor: Theme.placeholderTextColor
            text: rowRoot.rowNetwork !== undefined ? String(rowRoot.rowNetwork) : ""
            enabled: rowRoot.rowCanEdit
            color: Theme.textPrimary
            font.pixelSize: Theme.fontSizeSmall
            font.family: Theme.fontFamily
            onTextChanged: rowRoot.networkTextChanged(text)
            onAccepted: rowRoot.submitRequested()
            background: Rectangle {
                color: Theme.searchBackground2
                border.color: rowRoot.rowNetworkError
                            ? Theme.alertError
                            : (networkInput.activeFocus ? Theme.accentColor : Theme.borderColor)
                border.width: 1
                radius: 4
            }
        }

        TextField {
            id: maskInput
            Layout.fillWidth: true
            placeholderText: "Subnet Mask"
            placeholderTextColor: Theme.placeholderTextColor
            text: rowRoot.rowMask !== undefined ? String(rowRoot.rowMask) : ""
            enabled: rowRoot.rowCanEdit
            color: Theme.textPrimary
            font.pixelSize: Theme.fontSizeSmall
            font.family: Theme.fontFamily
            onTextChanged: rowRoot.maskTextChanged(text)
            onAccepted: rowRoot.submitRequested()
            Keys.onTabPressed: function(event) {
                const trimmed = maskInput.text.trim()
                const match = trimmed.match(/^\/([0-9]{1,2})$/)
                if (match) {
                    const prefix = parseInt(match[1], 10)
                    if (prefix >= 0 && prefix <= 32) {
                        const converted = rowRoot.prefixToMask(prefix)
                        maskInput.text = converted
                        rowRoot.maskTextChanged(converted)
                        nextHopInput.forceActiveFocus()
                        event.accepted = true
                        return
                    }
                }
                event.accepted = false
            }
            background: Rectangle {
                color: Theme.searchBackground2
                border.color: rowRoot.rowMaskError
                            ? Theme.alertError
                            : (maskInput.activeFocus ? Theme.accentColor : Theme.borderColor)
                border.width: 1
                radius: 4
            }
        }

        TextField {
            id: nextHopInput
            Layout.fillWidth: true
            placeholderText: "Next-hop"
            placeholderTextColor: Theme.placeholderTextColor
            text: rowRoot.rowNexthop !== undefined ? String(rowRoot.rowNexthop) : ""
            enabled: rowRoot.rowCanEdit
            color: Theme.textPrimary
            font.pixelSize: Theme.fontSizeSmall
            font.family: Theme.fontFamily
            onTextChanged: rowRoot.nextHopTextChanged(text)
            onAccepted: rowRoot.submitRequested()
            background: Rectangle {
                color: Theme.searchBackground2
                border.color: rowRoot.rowNexthopError
                            ? Theme.alertError
                            : (nextHopInput.activeFocus ? Theme.accentColor : Theme.borderColor)
                border.width: 1
                radius: 4
            }
        }

        TextField {
            Layout.preferredWidth: 70
            placeholderText: "AD"
            placeholderTextColor: Theme.placeholderTextColor
            text: rowRoot.rowAd !== undefined ? String(rowRoot.rowAd) : ""
            enabled: rowRoot.rowCanEdit
            validator: IntValidator { bottom: 1; top: 255 }
            color: Theme.textPrimary
            font.pixelSize: Theme.fontSizeSmall
            font.family: Theme.fontFamily
            onTextChanged: rowRoot.adTextChanged(text)
            onAccepted: rowRoot.submitRequested()
            background: Rectangle {
                color: Theme.searchBackground2
                border.color: Theme.borderColor
                border.width: 1
                radius: 4
            }
        }

        Rectangle {
            Layout.preferredWidth: 58
            Layout.preferredHeight: 30
            radius: 4
            visible: rowRoot.rowRouteId > 0 && !rowRoot.rowCanEdit
            color: changeHover.hovered ? Theme.sideBarItemHover : "transparent"
            border.color: Theme.borderColor
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: "Change"
                color: Theme.textPrimary
                font.pixelSize: Theme.fontSizeSmall
                font.family: Theme.fontFamily
            }

            HoverHandler { id: changeHover }
            TapHandler { onTapped: rowRoot.changeClicked() }
        }

        Rectangle {
            Layout.preferredWidth: 58
            Layout.preferredHeight: 30
            radius: 4
            visible: rowRoot.rowRouteId > 0 && rowRoot.rowCanEdit
            color: cancelHover.hovered ? Theme.sideBarItemHover : "transparent"
            border.color: Theme.borderColor
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: "Cancel"
                color: Theme.textPrimary
                font.pixelSize: Theme.fontSizeSmall
                font.family: Theme.fontFamily
            }

            HoverHandler { id: cancelHover }
            TapHandler { onTapped: rowRoot.cancelClicked() }
        }

        Rectangle {
            Layout.preferredWidth: 58
            Layout.preferredHeight: 30
            radius: 4
            color: deleteHover.hovered ? Qt.lighter(Theme.alertError, 1.2) : "transparent"
            border.color: deleteHover.hovered ? Theme.alertError : Theme.borderColor
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: "Delete"
                color: deleteHover.hovered ? Theme.alertError : Theme.textSecondary
                font.pixelSize: Theme.fontSizeSmall
                font.family: Theme.fontFamily
            }

            HoverHandler { id: deleteHover }
            TapHandler { onTapped: rowRoot.deleteClicked() }
        }
    }
}
