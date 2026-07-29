pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import UI

Rectangle {
    id: root
    property string state: "idle"
    property string message: ""

    visible: state !== "" && state !== "idle"
    implicitWidth: 10
    implicitHeight: 10
    radius: width / 2
    color: {
        if (state === "success") return Theme.statusConnected
        if (state === "error" || state === "cancelled") return Theme.statusDisconnected
        if (state === "warning") return Theme.statusWaiting
        return Theme.panelSideBarAccentColor
    }

    ToolTip.visible: badgeHover.hovered && root.message !== ""
    ToolTip.text: root.message
    ToolTip.delay: 300
    HoverHandler { id: badgeHover }

    SequentialAnimation on opacity {
        running: root.state === "running" || root.state === "queued"
        loops: Animation.Infinite
        NumberAnimation { from: 0.35; to: 1.0; duration: 500 }
        NumberAnimation { from: 1.0; to: 0.35; duration: 500 }
    }
}
