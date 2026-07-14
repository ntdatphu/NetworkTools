import QtQuick
import QtQuick.Controls.Basic
import UI

ApplicationWindow {
    width: 800
    height: 600
    visible: true

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
        Component.onCompleted: showToast("Toast notification", "info")
    }

    NotificationPanel {
        model: historyModel
        Component.onCompleted: open()
    }
}
