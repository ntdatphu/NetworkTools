pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import NetworkTools

Rectangle {
    id: root
    width: parent.width
    height: Theme.statusBarHeight
    color: Theme.statusBarBackground

    // ── Trạng thái Thông báo (Sẽ được Main.qml truyền vào) ────────────────
    property int unreadCount: 0
    property bool isDND: false
    property bool isNotificationOpen: false
    property string pythonStatusText: "PYTHON: IDLE"
    property string pythonStatusType: "idle"
    property string pythonStatusDetail: ""
    property bool pythonStatusBusy: false
    property bool backendBusy: false
    property string backendStatusType: "idle"
    property string backendStatusText: "BACKEND: IDLE"
    property string backendStatusDetail: ""

    readonly property color pythonStatusColor: {
        if (root.pythonStatusBusy || root.pythonStatusType === "checking")
            return Theme.alertWarning
        if (root.pythonStatusType === "success")
            return Theme.buttonTextSolid
        if (root.pythonStatusType === "error")
            return Theme.alertError
        return Theme.statusBarDimText
    }

    readonly property color backendStatusColor: {
        if (root.backendBusy || root.backendStatusType === "checking")
            return Theme.alertWarning
        if (root.backendStatusType === "success")
            return Theme.buttonTextSolid
        if (root.backendStatusType === "error")
            return Theme.alertError
        return Theme.statusBarDimText
    }

    readonly property int backendProgressPct: {
        if (root.backendBusy || root.backendStatusType === "checking")
            return 60
        if (root.backendStatusType === "success" || root.backendStatusType === "error")
            return 100
        return 0
    }

    signal bellClicked()
    signal pythonStatusClicked()

    // ── Helpers: đọc networkMonitor an toàn ────────────────────────────
    readonly property bool   netConnected: networkMonitor ? networkMonitor.isConnected    : false
    readonly property string netType:      networkMonitor ? networkMonitor.connectionType : "none"
    readonly property string netName:      networkMonitor ? networkMonitor.networkName    : ""
    readonly property int    ramUsagePct:  networkMonitor ? networkMonitor.ramUsagePercent : 0

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 16

        // ── 1. PHÂN VÙNG TRÁI (Trạng thái hệ thống) ──────────────────
        RowLayout {
            Layout.alignment: Qt.AlignVCenter
            spacing: 6

            HoverHandler {
                id: pythonStatusHover
                cursorShape: root.pythonStatusBusy ? Qt.ArrowCursor : Qt.PointingHandCursor
            }

            TapHandler {
                enabled: !root.pythonStatusBusy
                onTapped: root.pythonStatusClicked()
            }

            Button {
                id: pythonStatusIcon
                Layout.alignment: Qt.AlignVCenter
                width: 14; height: 14; padding: 0
                icon.source: AppPaths.resource("resources/activitybar/python.svg")
                icon.width: 14; icon.height: 14
                icon.color: root.pythonStatusColor
                background: Item {}
                enabled: false

                SequentialAnimation on opacity {
                    running: root.pythonStatusBusy
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.35; duration: 700; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutQuad }
                }

                Binding {
                    target: pythonStatusIcon
                    property: "opacity"
                    value: 1.0
                    when: !root.pythonStatusBusy
                }
            }

            Text {
                Layout.alignment: Qt.AlignVCenter
                text: root.pythonStatusText
                color: root.pythonStatusColor
                font.pixelSize: Theme.fontSizeSmall
                font.family: Theme.fontFamily
                font.weight: Font.DemiBold
            }

            ToolTip {
                visible: pythonStatusHover.hovered
                text: root.pythonStatusDetail === ""
                          ? "Click to check Python runtime and login packages."
                          : root.pythonStatusDetail
                delay: 400
            }
        }

        // ── 2. PHÂN VÙNG GIỮA (Khoảng trống đẩy nội dung sang 2 bên) ─
        Item {
            Layout.fillWidth: true
        }

        // ── 3. PHÂN VÙNG PHẢI (Network Indicator + Clock + Bell) ─────
        RowLayout {
            Layout.alignment: Qt.AlignVCenter
            spacing: 10

            // ── Network Indicator ──────────────────────────────────────
            RowLayout {
                spacing: 4
                Layout.alignment: Qt.AlignVCenter

                Button {
                    id: netIcon
                    Layout.alignment: Qt.AlignVCenter
                    width: 14; height: 14; padding: 0
                    enabled: false
                    background: Item {}

                    icon.width: 14; icon.height: 14

                    icon.source: {
                        if (!root.netConnected)
                            return AppPaths.resource("resources/statusbar/net-disconnected.svg")
                        if (root.netType === "wifi")
                            return AppPaths.resource("resources/statusbar/net-wifi.svg")
                        return AppPaths.resource("resources/statusbar/net-ethernet.svg")
                    }

                    icon.color: root.netConnected ? Theme.buttonTextSolid : Theme.statusBarDimText

                    SequentialAnimation on opacity {
                        running: !root.netConnected
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.4; duration: 800; easing.type: Easing.InOutQuad }
                        NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InOutQuad }
                    }

                    onEnabledChanged: { if (root.netConnected) opacity = 1.0 }

                    Binding {
                        target: netIcon
                        property: "opacity"
                        value: 1.0
                        when: root.netConnected
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignVCenter

                    text: {
                        if (!root.netConnected) return "No Network"
                        var label = (root.netType === "wifi") ? "Wi-Fi" : "Ethernet"
                        if (root.netName !== "")
                            return label + "  ·  " + root.netName
                        return label
                    }

                    color: root.netConnected ? Theme.buttonTextSolid : Theme.statusBarDimText
                    font.pixelSize: Theme.fontSizeSmall
                    font.family: Theme.fontFamily
                    font.weight: Font.Medium
                }
            }

            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                width: 1; height: 12
                color: Theme.statusBarSepColor
            }

            // ── RAM Usage ─────────────────────────────────────────────
            Text {
                Layout.alignment: Qt.AlignVCenter
                text: "RAM: " + root.ramUsagePct + "%"
                color: Theme.buttonTextSolid
                font.pixelSize: Theme.fontSizeSmall
                font.family: Theme.fontFamily
                font.weight: Font.Medium
            }

            RowLayout {
                spacing: 4
                Layout.alignment: Qt.AlignVCenter

                HoverHandler {
                    id: backendProgressHover
                    cursorShape: Qt.ArrowCursor
                }

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: "Backend"
                    color: root.backendStatusColor
                    font.pixelSize: Theme.fontSizeSmall
                    font.family: Theme.fontFamily
                    font.weight: Font.Medium
                }

                ProgressBar {
                    id: backendProgressBar
                    Layout.alignment: Qt.AlignVCenter
                    from: 0
                    to: 100
                    value: root.backendProgressPct
                    indeterminate: root.backendBusy || root.backendStatusType === "checking"
                    implicitWidth: 64
                    implicitHeight: 8
                    padding: 0

                    background: Rectangle {
                        implicitWidth: 64
                        implicitHeight: 8
                        radius: height / 2
                        color: Theme.statusBarSepColor
                    }

                    contentItem: Item {
                        implicitWidth: 64
                        implicitHeight: 8
                        clip: true

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !backendProgressBar.indeterminate
                            width: backendProgressBar.visualPosition * parent.width
                            height: parent.height
                            radius: height / 2
                            color: root.backendStatusColor
                        }

                        Rectangle {
                            id: backendProgressBusyFill
                            anchors.verticalCenter: parent.verticalCenter
                            visible: backendProgressBar.indeterminate
                            width: parent.width * 0.35
                            height: parent.height
                            radius: height / 2
                            color: root.backendStatusColor
                            x: -width

                            NumberAnimation on x {
                                running: backendProgressBar.indeterminate
                                loops: Animation.Infinite
                                from: -backendProgressBusyFill.width
                                to: backendProgressBar.width
                                duration: 900
                                easing.type: Easing.InOutQuad
                            }
                        }
                    }
                }

                ToolTip {
                    visible: backendProgressHover.hovered
                    text: root.backendStatusDetail === "" ? root.backendStatusText : root.backendStatusDetail
                    delay: 400
                }
            }

            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                width: 1; height: 12
                color: Theme.statusBarSepColor
            }

            // ── Ngày tháng năm ───────────────────────────────────────
            Text {
                id: dateText
                Layout.alignment: Qt.AlignVCenter
                text: "01/01/2000"
                color: Theme.buttonTextSolid
                font.pixelSize: Theme.fontSizeSmall
                font.family: Theme.fontFamily
                font.weight: Font.Medium

                Component.onCompleted: {
                    dateText.text = new Date().toLocaleDateString(Qt.locale(), "dd/MM/yyyy")
                }
            }

            // ── Đồng hồ ───────────────────────────────────────────────
            Text {
                id: clockText
                Layout.alignment: Qt.AlignVCenter
                text: "00:00"
                color: Theme.buttonTextSolid
                font.pixelSize: Theme.fontSizeSmall
                font.family: Theme.fontFamily
                font.weight: Font.Medium

                Timer {
                    interval: 1000
                    running: true
                    repeat: true
                    onTriggered: {
                        const now = new Date()
                        clockText.text = now.toLocaleTimeString(Qt.locale(), "HH:mm")
                        dateText.text = now.toLocaleDateString(Qt.locale(), "dd/MM/yyyy")
                    }
                }

                Component.onCompleted: {
                    clockText.text = new Date().toLocaleTimeString(Qt.locale(), "HH:mm")
                }
            }

            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                width: 1; height: 12
                color: Theme.statusBarSepColor
            }

            // ── Nút Chuông Thông Báo (Bell) ───────────────────────────
            IconButton {
                Layout.alignment: Qt.AlignVCenter
                buttonSize: 20
                iconSize: 14
                idleColor: Theme.buttonTextSolid
                activeColor: Theme.buttonTextSolid
                hoverBackground: Theme.statusBarSepColor
                iconSource: {
                    if (root.isDND) return AppPaths.resource("resources/statusbar/bell-slash.svg")
                    if (root.unreadCount > 0) return AppPaths.resource("resources/statusbar/bell-dot.svg")
                    return AppPaths.resource("resources/statusbar/bell.svg")
                }
                tooltip: root.isNotificationOpen ? "" :
                         (root.isDND ? "Notifications (Do Not Disturb)" :
                          (root.unreadCount > 0 ? root.unreadCount + " Unread Notifications" : "No New Notifications"))
                onClicked: root.bellClicked()
            }
        }
    }
}
