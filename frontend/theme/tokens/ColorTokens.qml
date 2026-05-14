pragma ComponentBehavior: Bound
pragma Singleton

import QtQuick
import NetworkTools

QtObject {
    property color windowTitleBackground: ThemeState.isDarkMode ? "#18181B" : "#E8E8E8"
    property color activityBarBackground: ThemeState.isDarkMode ? "#18181B" : "#FFFFFF"
    property color sideBarBackground: ThemeState.isDarkMode ? "#27272A" : "#F6F8FA"
    property color featureBarBackground: ThemeState.isDarkMode ? "#27272A" : "#F6F8FA"
    property color contentBackground: ThemeState.isDarkMode ? "#18181B" : "#FFFFFF"
    property color statusBarBackground: ThemeState.isDarkMode ? "#005A9E" : "#0969DA"
    property color tabBarBackground: ThemeState.isDarkMode ? "#27272A" : "#F6F8FA"

    property color activityBarItemHover: ThemeState.isDarkMode ? "#3F3F46" : "#E8E8E8"
    property color activityBarItemActive: ThemeState.isDarkMode ? "#52525B" : "#E0E0E0"

    property color sideBarItemHover: ThemeState.isDarkMode ? "#3F3F46" : "#E8E8E8"
    property color sideBarItemSelected: ThemeState.isDarkMode ? "#094771" : "#DDEEFF"

    property color tabActive: ThemeState.isDarkMode ? "#18181B" : "#FFFFFF"
    property color tabInactive: ThemeState.isDarkMode ? "#27272A" : "#F3F3F3"
    property color tabHover: ThemeState.isDarkMode ? "#3F3F46" : "#E8E8E8"

    property color featureMainActive: ThemeState.isDarkMode ? "#3F3F46" : "#E0E0E0"
    property color featureMainHover: ThemeState.isDarkMode ? "#52525B" : "#EBEBEB"

    property color titleButtonHover: ThemeState.isDarkMode ? "#3F3F46" : "#E8E8E8"

    property color textPrimary: ThemeState.isDarkMode ? "#F4F4F5" : "#1A1A1A"
    property color textSecondary: ThemeState.isDarkMode ? "#A1A1AA" : "#6B6B6B"
    property color textDisabled: ThemeState.isDarkMode ? "#D9D9D9" : "#ABABAB"
    property color placeholderTextColor: ThemeState.isDarkMode ? "#949AA1" : "#9CA3AF"

    property color borderColor: ThemeState.isDarkMode ? "#3F3F46" : "#E8EAED"
    property color borderColor2: ThemeState.isDarkMode ? "#3B82F6" : "#2196F3"
    property color accentColor: ThemeState.isDarkMode ? "#3B82F6" : "#0078D4"
    readonly property color brandOrange: "#FF7F2A"
    property color subBarAccentColor: brandOrange

    property color inputBackground: ThemeState.isDarkMode ? "#1E1E1E" : "#FFFFFF"
    property color inputBorderColor: ThemeState.isDarkMode ? "#3C3C3C" : "#CECECE"
    property color inputBorderFocusColor: accentColor

    property color splitHandleColor: ThemeState.isDarkMode ? "#3F3F46" : "#E0E0E0"
    property color splitHandleHoverColor: accentColor

    readonly property color statusConnected: "#2D9CDB"
    readonly property color statusWaiting: "#9E9E9E"
    readonly property color statusDisconnected: "#EB5757"

    property color alertError: statusDisconnected
    property color alertSuccess: statusConnected
    property color alertWarning: "#FFC107"
    property color alertInfo: accentColor

    readonly property color alertErrorSubtle: Qt.rgba(0.922, 0.341, 0.341, 0.12)
    readonly property color alertWarningSubtle: Qt.rgba(1.0, 0.753, 0.027, 0.12)
    readonly property color alertSuccessSubtle: Qt.rgba(0.176, 0.612, 0.859, 0.12)
    readonly property color alertInfoSubtle: Qt.rgba(0.231, 0.510, 0.965, 0.12)

    readonly property color badgeWarningBg: "#FFEFD5"
    readonly property color badgeWarningText: "#9A5A00"
    readonly property color badgeErrorBg: ThemeState.isDarkMode ? "#3D1515" : "#FFE5E5"
    readonly property color badgeErrorText: "#C0392B"
    readonly property color badgeSuccessBg: ThemeState.isDarkMode ? "#0D2D3D" : "#E5F4FB"
    readonly property color badgeSuccessText: "#1A6E9A"

    property color buttonTextSolid: "#FFFFFF"
    property color buttonDisabled: ThemeState.isDarkMode ? "#3F3F46" : "#CCCCCC"

    property color searchBackground: ThemeState.isDarkMode ? "#18181B" : "#FFFFFF"
    property color searchBackground2: ThemeState.isDarkMode ? "#27272A" : "#F5F5F5"

    readonly property color statusBarDimText: Qt.rgba(1, 1, 1, 0.70)
    readonly property color statusBarSepColor: Qt.rgba(1, 1, 1, 0.25)

    readonly property color shadowColor: Qt.rgba(0, 0, 0, 0.25)
    readonly property color shadowColorLight: Qt.rgba(0, 0, 0, 0.15)
    readonly property color dialogOverlay: "#80000000"
}
