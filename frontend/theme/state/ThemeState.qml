pragma ComponentBehavior: Bound
pragma Singleton

import QtQuick

QtObject {
    readonly property int system: 0
    readonly property int light: 1
    readonly property int dark: 2
    readonly property int lightHighContrast: 3
    readonly property int darkHighContrast: 4

    property int themeMode: system

    readonly property bool systemPrefersDark: Qt.application.styleHints.colorScheme === Qt.ColorScheme.Dark

    readonly property int effectiveThemeMode: {
        if (themeMode === light || themeMode === dark || themeMode === lightHighContrast || themeMode === darkHighContrast)
            return themeMode
        return systemPrefersDark ? dark : light
    }

    readonly property bool isDarkMode: {
        return effectiveThemeMode === dark || effectiveThemeMode === darkHighContrast
    }

    readonly property bool isHighContrast: {
        return effectiveThemeMode === lightHighContrast || effectiveThemeMode === darkHighContrast
    }

    readonly property bool isLightHighContrast: effectiveThemeMode === lightHighContrast
    readonly property bool isDarkHighContrast: effectiveThemeMode === darkHighContrast

    readonly property string themeName: {
        if (effectiveThemeMode === lightHighContrast) return "Light High Contrast"
        if (effectiveThemeMode === darkHighContrast) return "Dark High Contrast"
        if (effectiveThemeMode === dark) return "Dark"
        return "Light"
    }
}
