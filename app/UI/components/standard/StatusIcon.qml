pragma ComponentBehavior: Bound

import QtQuick
import UI

ThemedIcon {
    id: root

    property string statusType: "info"
    readonly property string normalizedStatusType: String(root.statusType || "info").toLowerCase()

    readonly property color accentColor: {
        if (root.normalizedStatusType === "success") return Theme.alertSuccess
        if (root.normalizedStatusType === "error") return Theme.alertError
        if (root.normalizedStatusType === "warning") return Theme.alertWarning
        return Theme.alertInfo
    }

    readonly property color contentBackgroundColor: {
        if (root.normalizedStatusType === "success") return Theme.alertSuccessSubtle
        if (root.normalizedStatusType === "error") return Theme.alertErrorSubtle
        if (root.normalizedStatusType === "warning") return Theme.alertWarningSubtle
        return Theme.alertInfoSubtle
    }

    iconSource: {
        if (root.normalizedStatusType === "success") return AppAssets.resource("resources/statusbar/check.svg")
        if (root.normalizedStatusType === "error") return AppAssets.resource("resources/statusbar/error.svg")
        if (root.normalizedStatusType === "warning") return AppAssets.resource("resources/statusbar/warning.svg")
        return AppAssets.resource("resources/statusbar/info.svg")
    }
    iconColor: root.accentColor
}
