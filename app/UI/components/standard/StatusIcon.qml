pragma ComponentBehavior: Bound

import QtQuick
import UI

ThemedIcon {
    id: root

    property string statusType: "info"
    readonly property string normalizedStatusType: String(root.statusType || "info").toLowerCase()

    readonly property color accentColor: {
        if (root.normalizedStatusType === "success") return Theme.notificationSuccessAccent
        if (root.normalizedStatusType === "error") return Theme.notificationErrorAccent
        if (root.normalizedStatusType === "warning") return Theme.notificationWarningAccent
        return Theme.notificationInfoAccent
    }

    readonly property color contentBackgroundColor: {
        if (root.normalizedStatusType === "success") return Theme.notificationSuccessBackground
        if (root.normalizedStatusType === "error") return Theme.notificationErrorBackground
        if (root.normalizedStatusType === "warning") return Theme.notificationWarningBackground
        return Theme.notificationInfoBackground
    }

    iconSource: {
        if (root.normalizedStatusType === "success") return AppAssets.resource("resources/statusbar/check.svg")
        if (root.normalizedStatusType === "error") return AppAssets.resource("resources/statusbar/error.svg")
        if (root.normalizedStatusType === "warning") return AppAssets.resource("resources/statusbar/warning.svg")
        return AppAssets.resource("resources/statusbar/info.svg")
    }
    iconColor: root.accentColor
}
