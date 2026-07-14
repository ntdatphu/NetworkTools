pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

Popup {
    id: root
    objectName: "notificationCenter"

    width: 360
    property int panelMaximumHeight: 400
    property int headerHeight: 44
    property var model: null
    readonly property int notificationCount: root.model && root.model.count !== undefined
                                             ? root.model.count
                                             : 0
    readonly property real minimumListContentHeight: notificationCount > 0
                                                       ? notificationCount * 56
                                                         + Math.max(0, notificationCount - 1) * listView.spacing
                                                       : 0
    readonly property real desiredBodyHeight: notificationCount === 0
                                               ? 0
                                               : Math.max(minimumListContentHeight, listView.contentHeight)
    readonly property bool hasScrollableOverflow: desiredBodyHeight > panelMaximumHeight - headerHeight
    height: Math.min(panelMaximumHeight, headerHeight + Math.ceil(desiredBodyHeight))
    padding: 0

    // Xóa nền mặc định của Popup để tự vẽ bằng chuẩn Theme
    background: Rectangle {
        color: Theme.searchBackground2
        border.color: Theme.borderColor
        border.width: 1
        radius: Theme.borderRadius !== undefined ? Theme.borderRadius : 6
    }

    property bool doNotDisturb: false

    // Tín hiệu yêu cầu xóa toàn bộ thông báo
    signal clearAllRequested()
    signal toggleDndRequested()

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── 1. HEADER ──
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: root.headerHeight
            color: "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: Theme.spacing8

                Text {
                    objectName: "notificationHeaderText"
                    text: root.notificationCount === 0
                          ? "No New Notifications"
                          : "Notifications"
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSizeNormal
                    font.weight: Font.DemiBold
                    Layout.fillWidth: true
                }

                StandardButton {
                    objectName: "notificationDndButton"
                    text: ""
                    type: "Icon"
                    icon.source: AppAssets.resource(root.doNotDisturb
                                                     ? "resources/statusbar/bell.svg"
                                                     : "resources/statusbar/dnd.svg")
                    tooltip: root.doNotDisturb
                             ? "Do Not Disturb - ON (click to turn OFF)"
                             : "Do Not Disturb - OFF (click to turn ON)"
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    Layout.alignment: Qt.AlignVCenter
                    onClicked: root.toggleDndRequested()
                }

                StandardButton {
                    objectName: "notificationClearAllButton"
                    visible: root.notificationCount > 0
                    text: ""
                    type: "Icon"
                    icon.source: AppAssets.resource("resources/statusbar/clear.svg")
                    tooltip: "Clear All Notifications"
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    Layout.alignment: Qt.AlignVCenter
                    onClicked: root.clearAllRequested()
                }

                StandardButton {
                    objectName: "notificationHideButton"
                    text: ""
                    type: "Icon"
                    icon.source: AppAssets.resource("resources/general/chevron-down.svg")
                    tooltip: "Hide Notification Center"
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    Layout.alignment: Qt.AlignVCenter
                    onClicked: root.close()
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width; height: 1
                color: Theme.borderColor
            }
        }

        // ── 2. DANH SÁCH LỊCH SỬ THÔNG BÁO ──
        ListView {
            id: listView
            model: root.model
            visible: root.notificationCount > 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: root.desiredBodyHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            spacing: 1

            delegate: Rectangle {
                id: notificationItem
                width: listView.width
                height: Math.max(56, contentLayout.implicitHeight + 24)
                color: notificationIcon.contentBackgroundColor
                border.color: notificationIcon.accentColor
                border.width: 1

                // Lấy dữ liệu từ ListModel an toàn với chế độ Bound
                required property string msgText
                required property string msgType
                required property string timestamp

                HoverHandler { id: hoverHandler }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 1
                    color: hoverHandler.hovered
                           ? Qt.rgba(notificationIcon.accentColor.r,
                                     notificationIcon.accentColor.g,
                                     notificationIcon.accentColor.b,
                                     0.08)
                           : "transparent"
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 4
                    color: notificationIcon.accentColor
                }

                RowLayout {
                    id: contentLayout
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12

                    StatusIcon {
                        id: notificationIcon
                        Layout.alignment: Qt.AlignTop | Qt.AlignLeft
                        statusType: notificationItem.msgType
                        iconSize: 16
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            Layout.fillWidth: true
                            text: msgText
                            color: Theme.textPrimary
                            font.pixelSize: Theme.fontSizeNormal
                            font.family: Theme.fontFamily
                            wrapMode: Text.Wrap
                        }

                        Text {
                            text: timestamp
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall - 1
                            font.family: Theme.fontFamily
                        }
                    }

                    CopyButton {
                        objectName: "historyCopyButton"
                        Layout.alignment: Qt.AlignTop | Qt.AlignRight
                        textToCopy: notificationItem.msgText
                        copyTooltip: "Copy notification"
                    }
                }

            }
        }
    }
}
