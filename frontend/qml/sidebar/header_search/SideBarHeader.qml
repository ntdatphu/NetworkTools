pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import NetworkTools

Item {
    id: root
    width: parent.width
    height: 36

    signal filterClicked()
    signal refreshClicked()
    signal addClicked()

    property bool isFilterActive: false

    Text {
        anchors.left: parent.left; anchors.leftMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        text: "DEVICES"
        color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSmall
        font.family: Theme.fontFamily; font.capitalization: Font.AllUppercase; font.weight: Font.Medium
    }

    Row {
        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: 8; spacing: 2

        // Nút Filter
        Rectangle {
            width: Theme.sideBarFeatureIcon; height: Theme.sideBarFeatureIcon; radius: 4
            color: filterHover.hovered || root.isFilterActive ? Theme.sideBarItemHover : "transparent"
            Button {
                anchors.centerIn: parent; width: 16; height: 16; padding: 0
                icon.source: "qrc:/qt/qml/NetworkTools/resources/sidebar/filter.svg"
                icon.width: 16; icon.height: 16; icon.color: Theme.textPrimary
                opacity: filterHover.hovered || root.isFilterActive ? 1.0 : 0.7
                // XUỐNG DÒNG Ở ĐÂY THAY VÌ DÙNG DẤU CHẤM PHẨY
                background: Item {}
                enabled: false
            }
            HoverHandler { id: filterHover }
            TapHandler { onTapped: root.filterClicked() }
            ToolTip { visible: filterHover.hovered; text: "Filter Devices"; delay: 500 }
        }

        // Nút Refresh
        Rectangle {
            width: Theme.sideBarFeatureIcon; height: Theme.sideBarFeatureIcon; radius: 4
            color: refreshHover.hovered ? Theme.sideBarItemHover : "transparent"
            Button {
                anchors.centerIn: parent; width: 16; height: 16; padding: 0
                icon.source: "qrc:/qt/qml/NetworkTools/resources/sidebar/refresh.svg"
                icon.width: 16; icon.height: 16; icon.color: Theme.textPrimary
                opacity: refreshHover.hovered ? 1.0 : 0.7
                // XUỐNG DÒNG
                background: Item {}
                enabled: false
            }
            HoverHandler { id: refreshHover }
            TapHandler { onTapped: root.refreshClicked() }
            ToolTip { visible: refreshHover.hovered; text: "Refresh List"; delay: 500 }
        }

        // Nút Add
        Rectangle {
            width: Theme.sideBarFeatureIcon; height: Theme.sideBarFeatureIcon; radius: 4
            color: newHover.hovered ? Theme.sideBarItemHover : "transparent"
            Button {
                anchors.centerIn: parent; width: 16; height: 16; padding: 0
                icon.source: "qrc:/qt/qml/NetworkTools/resources/sidebar/add.svg"
                icon.width: 16; icon.height: 16; icon.color: Theme.textPrimary
                opacity: newHover.hovered ? 1.0 : 0.7
                // XUỐNG DÒNG
                background: Item {}
                enabled: false
            }
            HoverHandler { id: newHover }
            TapHandler { onTapped: root.addClicked() }
            ToolTip { visible: newHover.hovered; text: "Add New Device (Ctrl+N) | Add Multiple (Ctrl+Shift+N)"; delay: 500 }
        }
    }
}