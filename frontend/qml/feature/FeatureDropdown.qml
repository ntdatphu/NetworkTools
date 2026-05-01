pragma ComponentBehavior: Bound

import QtQuick
import NetworkUI

Rectangle {
    id: featureDropdown

    property var hiddenFeatures: []
    property int activeIndex: -1

    signal featureSelected(int globalIndex)

    visible: false
    width: 160
    height: Math.min(hiddenFeatures.length * 36, 300)
    color: Theme.contentBackground
    border.color: Theme.borderColor
    border.width: Theme.borderWidth
    radius: 4

    // Đóng khi click ra ngoài
    function show(x, y) {
        parent.x = x
        parent.y = y
        visible = true
    }

    function hide() {
        visible = false
    }

    ListView {
        anchors.fill: parent
        anchors.margins: 4
        clip: true
        model: featureDropdown.hiddenFeatures

        delegate: Rectangle {
            width: parent.width
            height: 36
            color: dropItemHover.hovered ? Theme.sideBarItemHover : "transparent"
            radius: 4

            Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 12
                text: modelData.label
                font.pixelSize: Theme.fontSizeNormal
                font.family: Theme.fontFamily
                color: Theme.textPrimary
            }

            HoverHandler { id: dropItemHover }
            TapHandler {
                onTapped: {
                    featureDropdown.featureSelected(index)
                    featureDropdown.hide()
                }
            }
        }
    }
}
