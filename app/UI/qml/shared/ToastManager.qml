pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Effects
import QtQuick.Layouts
import UI

Item {
    id: root

    width: 360
    height: toastList.contentHeight

    anchors.bottom: parent.bottom
    anchors.bottomMargin: Theme.statusBarHeight + 16
    anchors.right: parent.right
    anchors.rightMargin: 16
    z: 9999

    property int nextId: 0
    property int duplicateSuppressionWindowMs: 3000
    property string lastToastMessage: ""
    property double lastToastShownAt: 0
    readonly property int toastCount: toastModel.count

    ListModel {
        id: toastModel
    }

    function autoCloseForType(type) {
        const normalized = String(type || "info").toLowerCase()
        return normalized !== "loading" && normalized !== "error"
    }

    function hasVisibleToast(message) {
        const normalizedMessage = String(message || "")
        for (let i = 0; i < toastModel.count; i++) {
            if (toastModel.get(i).msgText === normalizedMessage)
                return true
        }
        return false
    }

    function isDuplicateToast(message, now) {
        const normalizedMessage = String(message || "")
        const currentTime = now !== undefined ? Number(now) : Date.now()
        const repeatedRecently = normalizedMessage === root.lastToastMessage
                                 && currentTime - root.lastToastShownAt <= root.duplicateSuppressionWindowMs
        return root.hasVisibleToast(normalizedMessage) || repeatedRecently
    }

    function showToast(message, type = "info", allowDuplicate = false) {
        const normalizedMessage = String(message || "")
        const now = Date.now()
        if (!allowDuplicate && root.isDuplicateToast(normalizedMessage, now))
            return -1

        const uid = nextId++
        toastModel.append({
            "uid": uid,
            "msgText": normalizedMessage,
            "msgType": type,
            "autoClose": autoCloseForType(type)
        })
        root.lastToastMessage = normalizedMessage
        root.lastToastShownAt = now
        return uid
    }

    function showTask(message) {
        // Task toasts own a uid that is updated in place, so they must not be
        // folded into a previous task by the standard notification deduper.
        return showToast(message, "loading", true)
    }

    function updateToast(uid, message, type = "info") {
        for (let i = 0; i < toastModel.count; i++) {
            if (toastModel.get(i).uid === uid) {
                toastModel.setProperty(i, "msgText", message)
                toastModel.setProperty(i, "msgType", type)
                toastModel.setProperty(i, "autoClose", autoCloseForType(type))
                return true
            }
        }
        return false
    }

    function finishTask(uid, message, ok) {
        if (uid >= 0 && updateToast(uid, message, ok ? "success" : "error"))
            return
        showToast(message, ok ? "success" : "error")
    }

    function removeToast(uid) {
        for (let i = 0; i < toastModel.count; i++) {
            if (toastModel.get(i).uid === uid) {
                toastModel.remove(i)
                break
            }
        }
    }

    function clearToasts() {
        toastModel.clear()
    }

    ListView {
        id: toastList
        anchors.bottom: parent.bottom
        width: parent.width
        
        height: contentHeight 
        
        interactive: false
        spacing: 12

        verticalLayoutDirection: ListView.BottomToTop

        model: toastModel

        add: Transition {
            NumberAnimation {
                property: "opacity"
                from: 0; to: 1
                duration: 300
                easing.type: Easing.OutCubic
            }
        }

        remove: Transition {
            NumberAnimation { property: "opacity"; to: 0; duration: 200 }
        }

        displaced: Transition {
            NumberAnimation { properties: "y"; duration: 300; easing.type: Easing.OutCubic }
        }

        delegate: Rectangle {
            id: toastCard

            // Khai báo tường minh từ model
            required property int uid
            required property string msgText
            required property string msgType
            required property bool autoClose

            readonly property string normalizedType: String(msgType || "info").toLowerCase()
            readonly property bool loading: normalizedType === "loading"
            readonly property string iconType: loading ? "info" : normalizedType

            width: toastList.width
            implicitHeight: contentLayout.implicitHeight + 22

            color: toastIcon.contentBackgroundColor
            radius: Theme.borderRadius !== undefined ? Theme.borderRadius : 6
            border.color: toastIcon.accentColor
            border.width: 1

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Theme.shadowColor
                shadowBlur: 0.7
                shadowVerticalOffset: 4
                shadowHorizontalOffset: 0
            }

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 4
                color: toastIcon.accentColor
                topLeftRadius: toastCard.radius
                bottomLeftRadius: toastCard.loading ? 0 : toastCard.radius
            }

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 4
                color: toastIcon.contentBackgroundColor
                radius: toastCard.radius
            }

            RowLayout {
                id: contentLayout
                anchors.fill: parent
                anchors.margins: 10
                anchors.leftMargin: 16
                spacing: 12

                StatusIcon {
                    id: toastIcon
                    Layout.alignment: Qt.AlignTop | Qt.AlignLeft
                    Layout.topMargin: 2
                    statusType: toastCard.iconType
                    iconSize: 16
                }

                Text {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
                    text: toastCard.msgText
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSizeNormal
                    font.family: Theme.fontFamily
                    wrapMode: Text.Wrap
                }

                CloseButton {
                    Layout.alignment: Qt.AlignTop | Qt.AlignRight
                    variant: "compact"
                    tooltip: "Dismiss notification"
                    onClicked: {
                        autoCloseTimer.stop()
                        root.removeToast(toastCard.uid)
                    }
                }
            }

            ProgressBar {
                id: progressBar
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 3
                visible: toastCard.loading
                indeterminate: true

                background: Rectangle {
                    color: Qt.rgba(0, 0, 0, 0)
                    radius: 0
                }

                contentItem: Item {
                    implicitHeight: 3
                    clip: true
                    Rectangle {
                        id: progressRunner
                        width: Math.max(48, parent.width * 0.35)
                        height: parent.height
                        radius: 0
                        color: toastIcon.accentColor

                        SequentialAnimation on x {
                            running: toastCard.loading
                            loops: Animation.Infinite
                            NumberAnimation {
                                from: -progressRunner.width
                                to: progressBar.width
                                duration: 1200
                                easing.type: Easing.InOutCubic
                            }
                        }
                    }
                }
            }

            Timer {
                id: autoCloseTimer
                interval: toastCard.normalizedType === "success" ? 4000 : 5000
                running: toastCard.autoClose
                repeat: false
                onTriggered: {
                    root.removeToast(uid)
                }
            }

            onAutoCloseChanged: {
                if (autoClose)
                    autoCloseTimer.restart()
                else
                    autoCloseTimer.stop()
            }
        }
    }
}
