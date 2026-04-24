pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import NetworkUI

ComboBox {
    id: root
    Layout.fillWidth: true

    // Biến để chặn tự động đổi Port khi đang nạp dữ liệu cũ (Edit Mode)
    property bool isEditMode: false

    // Tín hiệu bắn ra ngoài khi Protocol thay đổi
    signal portAutoChanged(string newPort)

    model: ["SSH", "TELNET", "NETCONF", "RESTCONF"]
    font.pixelSize: Theme.fontSizeNormal
    font.family: Theme.fontFamily

    background: Rectangle {
        color: Theme.searchBackground
        border.color: root.activeFocus || root.popup.visible ? Theme.accentColor : Theme.borderColor
        border.width: 1
        radius: 4
    }

    contentItem: Text {
        text: root.currentText
        color: Theme.textPrimary
        font.pixelSize: Theme.fontSizeNormal
        font.family: Theme.fontFamily
        verticalAlignment: Text.AlignVCenter
        leftPadding: 10
    }

    delegate: ItemDelegate {
        required property int index
        required property string modelData

        width: root.width

        contentItem: Text {
            text: modelData
            color: highlighted ? Theme.textPrimary : Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeNormal
            verticalAlignment: Text.AlignVCenter
        }

        background: Rectangle {
            color: highlighted ? Theme.sideBarItemHover : Theme.searchBackground
            radius: 2
        }

        highlighted: root.highlightedIndex === index
    }

    popup: Popup {
        y: root.height + 4
        width: root.width
        implicitHeight: contentItem.implicitHeight
        padding: 4
        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: root.popup.visible ? root.delegateModel : null
            currentIndex: root.highlightedIndex
            ScrollIndicator.vertical: ScrollIndicator { }
        }
        background: Rectangle {
            color: Theme.searchBackground
            border.color: Theme.borderColor
            border.width: 1
            radius: 4
        }
    }

    onCurrentTextChanged: {
        if (!isEditMode || activeFocus) {
            if (currentText === "SSH") portAutoChanged("22")
            else if (currentText === "TELNET") portAutoChanged("23")
            else if (currentText === "NETCONF") portAutoChanged("830")
            else if (currentText === "RESTCONF") portAutoChanged("443")
        }
    }
}