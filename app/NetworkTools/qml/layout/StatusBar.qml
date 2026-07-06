pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import NetworkTools

Rectangle {
    id: root
    width: parent ? parent.width : 800
    height: StatusBarState.isVisible ? Theme.statusBarHeight : 0
    visible: StatusBarState.isVisible
    clip: true
    color: Theme.statusBarBackground

    property int unreadCount: 0
    property bool isDND: false
    property bool isNotificationOpen: false
    property string pythonStatusText: "PYTHON: IDLE"
    property string pythonStatusType: "idle"
    property string pythonStatusDetail: ""
    property bool pythonStatusBusy: false
    property date currentDateTime: new Date()

    readonly property bool netConnected: networkMonitor ? networkMonitor.isConnected : false
    readonly property string netType: networkMonitor ? networkMonitor.connectionType : "none"
    readonly property string netName: networkMonitor ? networkMonitor.networkName : ""
    readonly property int ramUsagePct: networkMonitor
                                       ? Math.max(0, Math.min(100, networkMonitor.ramUsagePercent))
                                       : 0

    readonly property string normalizedNetType: (root.netType || "").toLowerCase()
    readonly property bool ramSectionVisible: StatusBarState.showRam
                                              && (StatusBarState.showRamBar || StatusBarState.showRamText)
    readonly property bool dateTimeSectionVisible: StatusBarState.showDate || StatusBarState.showTime
    readonly property int ramWarningThreshold: Math.max(1, Math.min(100, StatusBarState.ramWarningThreshold))
    readonly property bool ramHigh: StatusBarState.ramWarningEnabled
                                    && root.ramUsagePct >= root.ramWarningThreshold

    readonly property color pythonStatusColor: {
        if (root.pythonStatusBusy || root.pythonStatusType === "checking")
            return Theme.alertWarning
        if (root.pythonStatusType === "success")
            return Theme.buttonTextSolid
        if (root.pythonStatusType === "error")
            return Theme.alertError
        return Theme.statusBarDimText
    }

    readonly property color networkColor: root.netConnected ? Theme.buttonTextSolid : Theme.statusBarDimText
    readonly property color ramBarColor: root.ramHigh ? Theme.alertError : Theme.accentColor
    readonly property color ramTextColor: root.ramHigh ? Theme.alertError : Theme.buttonTextSolid

    signal bellClicked()
    signal pythonStatusClicked()

    function isWifiConnection() {
        return root.normalizedNetType === "wifi" || root.normalizedNetType === "wireless"
    }

    function isEthernetConnection() {
        return root.normalizedNetType === "ethernet" || root.normalizedNetType === "wired"
    }

    function isVpnConnection() {
        return root.normalizedNetType === "vpn"
    }

    function connectionLabel() {
        if (!root.netConnected || root.normalizedNetType === "none")
            return "No Connection"
        if (root.isWifiConnection())
            return "Wi-Fi"
        if (root.isEthernetConnection())
            return "Ethernet"
        if (root.isVpnConnection())
            return "VPN"
        return "Network"
    }

    function networkText() {
        const label = root.connectionLabel()
        const name = (root.netName || "").trim()
        if (!root.netConnected || !StatusBarState.showNetworkName || name === "" || name === label)
            return label
        return label + " - " + name
    }

    function formatDateText(value) {
        const customFormat = (StatusBarState.customDateFormat || "").trim()
        if (StatusBarState.dateTimeFormatMode === 1 && customFormat !== "")
            return Qt.formatDate(value, customFormat)
        return value.toLocaleDateString(Qt.locale())
    }

    function formatTimeText(value) {
        const customFormat = (StatusBarState.customTimeFormat || "").trim()
        if (StatusBarState.dateTimeFormatMode === 1 && customFormat !== "")
            return Qt.formatTime(value, customFormat)
        return value.toLocaleTimeString(Qt.locale())
    }

    Timer {
        interval: 1000
        running: StatusBarState.isVisible
        repeat: true
        onTriggered: root.currentDateTime = new Date()
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 16

        RowLayout {
            Layout.alignment: Qt.AlignVCenter
            spacing: 6
            visible: StatusBarState.showPythonStatus

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
                width: 14
                height: 14
                padding: 0
                icon.source: AppPaths.resource("resources/activitybar/python.svg")
                icon.width: 14
                icon.height: 14
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

        Item {
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.alignment: Qt.AlignVCenter
            spacing: 10

            RowLayout {
                spacing: 4
                Layout.alignment: Qt.AlignVCenter
                visible: StatusBarState.showNetwork

                HoverHandler {
                    id: networkHover
                    cursorShape: Qt.ArrowCursor
                }

                Button {
                    id: netIcon
                    Layout.alignment: Qt.AlignVCenter
                    width: 14
                    height: 14
                    padding: 0
                    enabled: false
                    background: Item {}
                    icon.width: 14
                    icon.height: 14

                    icon.source: {
                        if (!root.netConnected || root.normalizedNetType === "none")
                            return AppPaths.resource("resources/statusbar/net-disconnected.svg")
                        if (root.isWifiConnection())
                            return AppPaths.resource("resources/statusbar/net-wifi.svg")
                        return AppPaths.resource("resources/statusbar/net-ethernet.svg")
                    }

                    icon.color: root.networkColor

                    SequentialAnimation on opacity {
                        running: !root.netConnected
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.4; duration: 800; easing.type: Easing.InOutQuad }
                        NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InOutQuad }
                    }

                    Binding {
                        target: netIcon
                        property: "opacity"
                        value: 1.0
                        when: root.netConnected
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: root.networkText()
                    color: root.networkColor
                    font.pixelSize: Theme.fontSizeSmall
                    font.family: Theme.fontFamily
                    font.weight: Font.Medium
                }

                ToolTip {
                    visible: networkHover.hovered
                    text: root.netConnected
                          ? root.networkText()
                          : "No active network adapter was detected."
                    delay: 400
                }
            }

            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                width: 1
                height: 12
                color: Theme.statusBarSepColor
                visible: StatusBarState.showNetwork
                         && (root.ramSectionVisible || root.dateTimeSectionVisible || StatusBarState.showNotifications)
            }

            RowLayout {
                spacing: 5
                Layout.alignment: Qt.AlignVCenter
                visible: root.ramSectionVisible

                HoverHandler {
                    id: ramHover
                    cursorShape: Qt.ArrowCursor
                }

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    visible: StatusBarState.showRamText
                    text: "RAM"
                    color: root.ramTextColor
                    font.pixelSize: Theme.fontSizeSmall
                    font.family: Theme.fontFamily
                    font.weight: Font.Medium
                }

                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: 72
                    Layout.preferredHeight: 8
                    visible: StatusBarState.showRamBar
                    radius: height / 2
                    color: Theme.statusBarSepColor
                    clip: true

                    Rectangle {
                        id: ramFill
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: Math.max(root.ramUsagePct > 0 ? 2 : 0,
                                        parent.width * root.ramUsagePct / 100)
                        radius: height / 2
                        color: root.ramBarColor

                        SequentialAnimation on opacity {
                            running: root.ramHigh && StatusBarState.ramBlinkOnHigh
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.35; duration: 450; easing.type: Easing.InOutQuad }
                            NumberAnimation { to: 1.0; duration: 450; easing.type: Easing.InOutQuad }
                        }

                        Binding {
                            target: ramFill
                            property: "opacity"
                            value: 1.0
                            when: !(root.ramHigh && StatusBarState.ramBlinkOnHigh)
                        }
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    visible: StatusBarState.showRamText
                    text: root.ramUsagePct + "%"
                    color: root.ramTextColor
                    font.pixelSize: Theme.fontSizeSmall
                    font.family: Theme.fontFamily
                    font.weight: Font.Medium
                }

                ToolTip {
                    visible: ramHover.hovered
                    text: "RAM usage: " + root.ramUsagePct + "%, warning at "
                          + root.ramWarningThreshold + "%"
                    delay: 400
                }
            }

            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                width: 1
                height: 12
                color: Theme.statusBarSepColor
                visible: root.ramSectionVisible
                         && (root.dateTimeSectionVisible || StatusBarState.showNotifications)
            }

            RowLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 8
                visible: root.dateTimeSectionVisible

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    visible: StatusBarState.showDate
                    text: root.formatDateText(root.currentDateTime)
                    color: Theme.buttonTextSolid
                    font.pixelSize: Theme.fontSizeSmall
                    font.family: Theme.fontFamily
                    font.weight: Font.Medium
                }

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    visible: StatusBarState.showTime
                    text: root.formatTimeText(root.currentDateTime)
                    color: Theme.buttonTextSolid
                    font.pixelSize: Theme.fontSizeSmall
                    font.family: Theme.fontFamily
                    font.weight: Font.Medium
                }
            }

            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                width: 1
                height: 12
                color: Theme.statusBarSepColor
                visible: root.dateTimeSectionVisible && StatusBarState.showNotifications
            }

            IconButton {
                Layout.alignment: Qt.AlignVCenter
                visible: StatusBarState.showNotifications
                buttonSize: 20
                iconSize: 14
                idleColor: Theme.buttonTextSolid
                activeColor: Theme.buttonTextSolid
                hoverBackground: Theme.statusBarSepColor
                iconSource: {
                    if (root.isDND)
                        return AppPaths.resource("resources/statusbar/bell-slash.svg")
                    if (root.unreadCount > 0)
                        return AppPaths.resource("resources/statusbar/bell-dot.svg")
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
