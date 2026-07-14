import QtQuick
import QtQuick.Controls.Basic
import UI

ApplicationWindow {
    id: root
    width: 800
    height: 600
    visible: true

    property bool doNotDisturb: false
    readonly property int toastCount: toastManager.toastCount
    readonly property real notificationPanelHeight: notificationPanel.height

    function clearHistory() {
        historyModel.clear()
    }

    function addHistory(message, type) {
        historyModel.insert(0, {
            "msgText": message,
            "msgType": type,
            "timestamp": "10:31:00"
        })
    }

    ListModel {
        id: historyModel
        ListElement {
            msgText: "History notification"
            msgType: "info"
            timestamp: "10:30:00"
        }
    }

    ToastManager {
        id: toastManager
        objectName: "testToastManager"
        Component.onCompleted: showToast("Toast notification", "info")
    }

    NotificationPanel {
        id: notificationPanel
        objectName: "testNotificationCenter"
        model: historyModel
        doNotDisturb: root.doNotDisturb
        onToggleDndRequested: root.doNotDisturb = !root.doNotDisturb
        onClearAllRequested: historyModel.clear()
        Component.onCompleted: open()
    }
}
