pragma ComponentBehavior: Bound

import QtQuick
import NetworkUI

BaseButton {
    id: root

    // Các loại nút: "Primary", "Secondary", "Danger", "Ghost"
    property string type: "Primary"

    // ── Tự động map màu sắc theo type ──
    backgroundColor: {
        if (type === "Primary")   return Theme.accentColor
        if (type === "Secondary") return "transparent"
        if (type === "Danger")    return Theme.alertError
        if (type === "Ghost")     return "transparent"
        return Theme.accentColor
    }

    backgroundHoveredColor: {
        if (type === "Primary")   return Qt.lighter(Theme.accentColor, 1.15)
        if (type === "Secondary") return Theme.sideBarItemHover
        if (type === "Danger")    return Qt.lighter(Theme.alertError, 1.15)
        if (type === "Ghost")     return Theme.sideBarItemHover
        return Qt.lighter(Theme.accentColor, 1.15)
    }

    backgroundPressedColor: {
        if (type === "Primary")   return Qt.darker(Theme.accentColor, 1.15)
        if (type === "Secondary") return Qt.darker(Theme.sideBarItemHover, 1.1)
        if (type === "Danger")    return Qt.darker(Theme.alertError, 1.15)
        if (type === "Ghost")     return Qt.darker(Theme.sideBarItemHover, 1.1)
        return Qt.darker(Theme.accentColor, 1.15)
    }

    contentColor: {
        if (type === "Primary")   return Theme.buttonTextSolid
        if (type === "Secondary") return Theme.textPrimary
        if (type === "Danger")    return Theme.buttonTextSolid
        if (type === "Ghost")     return Theme.textSecondary
        return Theme.buttonTextSolid
    }

    borderColor: {
        if (type === "Secondary") return Theme.borderColor
        return "transparent"
    }

    borderWidth: type === "Secondary" ? 1 : 0
}