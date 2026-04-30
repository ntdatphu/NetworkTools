pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import NetworkUI

Item {
    id: delegateRoot
    width: Math.max(140, tabLayout.implicitWidth + 40)
    height: Theme.tabBarHeight

    required property var model
    required property int index

    property string tabTitle: model.title
    property bool isActive: model.isActive
    property int tabIndex: index

    // ── 1. KHAI BÁO CÁC TÍN HIỆU (SIGNALS) ĐỂ BÁO CHO FILE CHA ──
    signal moveRequested(int fromIdx, int toIdx)
    signal selectRequested(int idx)
    signal closeRequested(int idx)

    DropArea {
        anchors.fill: parent
        keys: ["tabDrag"]
        onEntered: (drag) => {
            const fromIdx = drag.source && drag.source.tabIndex !== undefined ? drag.source.tabIndex : -1
            const toIdx = delegateRoot.tabIndex
            if (fromIdx !== -1 && fromIdx !== toIdx) {
                // PHÁT TÍN HIỆU YÊU CẦU ĐỔI CHỖ
                delegateRoot.moveRequested(fromIdx, toIdx)
            }
        }
    }

    Rectangle {
        id: visualItem
        width: delegateRoot.width
        height: delegateRoot.height

        color: delegateRoot.isActive ? Theme.tabActive : (tabHover.hovered ? Theme.tabHover : Theme.tabInactive)

        Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Theme.borderColor }
        Rectangle { anchors.top: parent.top; width: parent.width; height: 2; color: Theme.accentColor; visible: delegateRoot.isActive }

        RowLayout {
            id: tabLayout
            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 6; spacing: 6

            Text {
                text: delegateRoot.tabTitle
                color: delegateRoot.isActive ? Theme.textPrimary : Theme.textSecondary
                font.pixelSize: Theme.fontSizeNormal; font.family: Theme.fontFamily
                Layout.fillWidth: true;
                elide: Text.ElideRight
            }

            Rectangle {
                Layout.preferredWidth: 20; Layout.preferredHeight: 20; radius: 4
                color: closeHover.hovered ? Theme.sideBarItemHover : "transparent"
                opacity: (delegateRoot.isActive || tabHover.hovered) ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: Theme.animationDurationFast } }

                Button {
                    anchors.centerIn: parent
                    width: 12; height: 12; padding: 0

                    // ICON NÚT CLOSE BẰNG SVG (Bạn nhớ chuẩn bị file close.svg nhé)
                    icon.source: "qrc:/qt/qml/NetworkUI/resources/devicetabs/close.svg"
                    icon.width: 12; icon.height: 12

                    icon.color: closeHover.hovered ? Theme.textPrimary : Theme.textSecondary

                    background: Item {}
                    enabled: false
                }

                HoverHandler { id: closeHover }
                TapHandler {
                    // PHÁT TÍN HIỆU YÊU CẦU ĐÓNG TAB
                    onTapped: delegateRoot.closeRequested(delegateRoot.tabIndex)
                }
            }
        }

        HoverHandler { id: tabHover }
        TapHandler {
            // PHÁT TÍN HIỆU YÊU CẦU CHỌN TAB
            onTapped: delegateRoot.selectRequested(delegateRoot.tabIndex)
        }

        DragHandler {
            id: dragHandler
            xAxis.enabled: true; yAxis.enabled: false
            target: visualItem
        }

        Drag.active: dragHandler.active
        Drag.source: delegateRoot
        Drag.keys: ["tabDrag"]

        states: [
            State {
                when: dragHandler.active
                // Fix lỗi Parent: Gọi trực tiếp ListView thông qua thuộc tính đính kèm (attached property)
                ParentChange { target: visualItem; parent: delegateRoot.ListView.view }
                PropertyChanges { target: visualItem; opacity: 0.7; z: 100 }
            }
        ]
    }
}