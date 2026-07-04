pragma ComponentBehavior: Bound
pragma Singleton

import QtQuick
import NetworkTools

QtObject {
    readonly property int mode: ThemeState.effectiveThemeMode

    function pick(lightColor, darkColor, lightHighContrastColor, darkHighContrastColor) {
        if (mode === ThemeState.lightHighContrast)
            return lightHighContrastColor
        if (mode === ThemeState.darkHighContrast)
            return darkHighContrastColor
        if (mode === ThemeState.dark)
            return darkColor
        return lightColor
    }

    property color windowTitleBackground: pick("#F6F8FA", "#010409", "#FFFFFF", "#000000")
    property color activityBarBackground: pick("#FFFFFF", "#0D1117", "#FFFFFF", "#000000")
    property color sideBarBackground: pick("#F6F8FA", "#010409", "#F6F8FA", "#000000")
    property color featureBarBackground: pick("#FFFFFF", "#0D1117", "#FFFFFF", "#000000")
    property color contentBackground: pick("#FFFFFF", "#0D1117", "#FFFFFF", "#000000")
    property color contentSurface: pick("#FFFFFF", "#161B22", "#FFFFFF", "#0D1117")
    property color contentPanelSurface: pick("#FFFFFF", "#161B22", "#FFFFFF", "#0D1117")
    property color contentPanelBorder: pick("#D1D9E0", "#30363D", "#57606A", "#8B949E")
    property color statusBarBackground: pick("#24292F", "#0D1117", "#000000", "#000000")
    property color tabBarBackground: pick("#F6F8FA", "#010409", "#FFFFFF", "#000000")

    property color activityBarItemHover: pick("#EAEEF2", "#21262D", "#E7F0FF", "#161B22")
    property color activityBarItemActive: pick("#DDEBFF", "#0C2D6B", "#C8E1FF", "#082563")

    property color sideBarItemHover: pick("#EAEEF2", "#21262D", "#E7F0FF", "#161B22")
    property color sideBarItemSelected: pick("#DDEBFF", "#0C2D6B", "#C8E1FF", "#082563")

    property color tabActive: pick("#FFFFFF", "#0D1117", "#FFFFFF", "#000000")
    property color tabInactive: pick("#F6F8FA", "#010409", "#F6F8FA", "#000000")
    property color tabHover: pick("#EAEEF2", "#21262D", "#E7F0FF", "#161B22")

    property color featureMainActive: pick("#DDEBFF", "#0C2D6B", "#C8E1FF", "#082563")
    property color featureMainHover: sideBarItemHover

    property color titleButtonHover: pick("#EAEEF2", "#21262D", "#E7F0FF", "#161B22")

    property color textPrimary: pick("#1F2328", "#E6EDF3", "#0E1116", "#FFFFFF")
    property color textSecondary: pick("#59636E", "#B1BAC4", "#24292F", "#D0D7DE")
    property color textDisabled: pick("#818B98", "#6E7681", "#57606A", "#8B949E")
    property color placeholderTextColor: pick("#6E7781", "#8B949E", "#57606A", "#B1BAC4")

    property color borderColor: pick("#D1D9E0", "#30363D", "#57606A", "#8B949E")
    property color borderColor2: pick("#0969DA", "#1F6FEB", "#0349B4", "#1F6FEB")
    property color accentColor: pick("#0969DA", "#1F6FEB", "#0349B4", "#1F6FEB")
    readonly property color brandOrange: pick("#BC4C00", "#DB6D28", "#953800", "#F0883E")
    property color subBarAccentColor: brandOrange

    property color inputBackground: pick("#FFFFFF", "#0D1117", "#FFFFFF", "#000000")
    property color inputBorderColor: pick("#D1D9E0", "#484F58", "#57606A", "#8B949E")
    property color inputBorderFocusColor: accentColor

    property color splitHandleColor: pick("#D1D9E0", "#30363D", "#57606A", "#8B949E")
    property color splitHandleHoverColor: accentColor

    readonly property color statusConnected: pick("#0969DA", "#58A6FF", "#0349B4", "#79C0FF")
    readonly property color statusWaiting: pick("#6E7781", "#8B949E", "#57606A", "#B1BAC4")
    readonly property color statusDisconnected: pick("#CF222E", "#DA3633", "#A40E26", "#DA3633")

    property color alertError: statusDisconnected
    property color alertSuccess: pick("#1A7F37", "#56D364", "#116329", "#7EE787")
    property color alertWarning: pick("#9A6700", "#F2CC60", "#7D4E00", "#F8E3A1")
    property color alertInfo: accentColor

    readonly property color alertErrorSubtle: {
        if (ThemeState.isDarkHighContrast) return Qt.rgba(1.0, 0.635, 0.596, 0.22)
        if (ThemeState.isDarkMode) return Qt.rgba(1.0, 0.482, 0.447, 0.16)
        if (ThemeState.isLightHighContrast) return "#FFD8D3"
        return "#FFEBE9"
    }
    readonly property color alertWarningSubtle: {
        if (ThemeState.isDarkHighContrast) return Qt.rgba(0.973, 0.890, 0.631, 0.22)
        if (ThemeState.isDarkMode) return Qt.rgba(0.949, 0.800, 0.376, 0.16)
        if (ThemeState.isLightHighContrast) return "#FAE17D"
        return "#FFF8C5"
    }
    readonly property color alertSuccessSubtle: {
        if (ThemeState.isDarkHighContrast) return Qt.rgba(0.494, 0.906, 0.529, 0.22)
        if (ThemeState.isDarkMode) return Qt.rgba(0.337, 0.827, 0.392, 0.16)
        if (ThemeState.isLightHighContrast) return "#B4F1B4"
        return "#DAFBE1"
    }
    readonly property color alertInfoSubtle: {
        if (ThemeState.isDarkHighContrast) return Qt.rgba(0.475, 0.753, 1.0, 0.22)
        if (ThemeState.isDarkMode) return Qt.rgba(0.345, 0.651, 1.0, 0.16)
        if (ThemeState.isLightHighContrast) return "#C8E1FF"
        return "#DDF4FF"
    }

    readonly property color badgeWarningBg: pick("#FFF8C5", "#3D2E00", "#FAE17D", "#4D3800")
    readonly property color badgeWarningText: pick("#7D4E00", "#F2CC60", "#3F2200", "#F8E3A1")
    readonly property color badgeErrorBg: pick("#FFEBE9", "#3D1515", "#FFD8D3", "#4B1113")
    readonly property color badgeErrorText: pick("#A40E26", "#FF7B72", "#6E0711", "#FFA198")
    readonly property color badgeSuccessBg: pick("#DAFBE1", "#0F3A1D", "#B4F1B4", "#0B4F1D")
    readonly property color badgeSuccessText: pick("#116329", "#7EE787", "#0A4A1F", "#AFF5B4")

    property color buttonTextSolid: "#FFFFFF"
    property color buttonDisabled: pick("#EFF2F5", "#30363D", "#D1D9E0", "#484F58")

    property color searchBackground: pick("#FFFFFF", "#0D1117", "#FFFFFF", "#000000")
    property color searchBackground2: pick("#F6F8FA", "#161B22", "#F6F8FA", "#0D1117")

    readonly property color statusBarDimText: Qt.rgba(1, 1, 1, ThemeState.isHighContrast ? 0.88 : 0.72)
    readonly property color statusBarSepColor: Qt.rgba(1, 1, 1, ThemeState.isHighContrast ? 0.42 : 0.24)

    readonly property color shadowColor: ThemeState.isDarkMode ? Qt.rgba(0, 0, 0, 0.45) : Qt.rgba(31 / 255, 35 / 255, 40 / 255, 0.20)
    readonly property color shadowColorLight: ThemeState.isDarkMode ? Qt.rgba(0, 0, 0, 0.30) : Qt.rgba(31 / 255, 35 / 255, 40 / 255, 0.12)
    readonly property color dialogOverlay: ThemeState.isHighContrast ? "#B0000000" : "#80000000"
}
