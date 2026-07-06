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
    property int accentColorIndex: 4
    property bool lightDarkSideBar: false

    readonly property var accentGroups: [
        "Red",
        "Orange",
        "Blue",
        "Green",
        "Purple",
        "Black"
    ]

    readonly property var accentPalette: [
        { "index": 0, "group": "Red", "name": "Ruby", "color": "#C2413D", "emphasis": "#A9322F", "hover": "#D0524E", "statusBar": "#A9322F", "activeLight": "#FFE8E6", "activeDark": "#3A1717" },
        { "index": 1, "group": "Red", "name": "Crimson", "color": "#BE123C", "emphasis": "#9F1239", "hover": "#D11C4D", "statusBar": "#9F1239", "activeLight": "#FFE4EC", "activeDark": "#3B1020" },
        { "index": 2, "group": "Orange", "name": "Orange", "color": "#D97706", "emphasis": "#B45309", "hover": "#EA8A13", "statusBar": "#B45309", "activeLight": "#FFF0D9", "activeDark": "#3B2408" },
        { "index": 3, "group": "Orange", "name": "Amber", "color": "#B7791F", "emphasis": "#975A16", "hover": "#C98A2A", "statusBar": "#975A16", "activeLight": "#FFF3D6", "activeDark": "#372509" },
        { "index": 4, "group": "Blue", "name": "Azure", "color": "#356FD6", "emphasis": "#2F5DAA", "hover": "#4F86E5", "statusBar": "#2F5DAA", "activeLight": "#DDEBFF", "activeDark": "#0C2D6B" },
        { "index": 5, "group": "Blue", "name": "Sky", "color": "#0E7490", "emphasis": "#155E75", "hover": "#1592B3", "statusBar": "#155E75", "activeLight": "#D8F4FF", "activeDark": "#083545" },
        { "index": 6, "group": "Green", "name": "Emerald", "color": "#15803D", "emphasis": "#166534", "hover": "#1F9D50", "statusBar": "#166534", "activeLight": "#DCFCE7", "activeDark": "#0D321C" },
        { "index": 7, "group": "Green", "name": "Teal", "color": "#0F766E", "emphasis": "#115E59", "hover": "#14958C", "statusBar": "#115E59", "activeLight": "#CCFBF1", "activeDark": "#0A3834" },
        { "index": 8, "group": "Purple", "name": "Violet", "color": "#7C3AED", "emphasis": "#6D28D9", "hover": "#8B5CF6", "statusBar": "#5B21B6", "activeLight": "#EDE9FE", "activeDark": "#24105E" },
        { "index": 9, "group": "Purple", "name": "Indigo", "color": "#4F46E5", "emphasis": "#4338CA", "hover": "#6366F1", "statusBar": "#3730A3", "activeLight": "#E0E7FF", "activeDark": "#1E1B4B" },
        { "index": 10, "group": "Black", "name": "Graphite", "color": "#24292F", "emphasis": "#1F2328", "hover": "#3A414A", "statusBar": "#24292F", "activeLight": "#EAECEF", "activeDark": "#161B22" },
        { "index": 11, "group": "Black", "name": "Slate", "color": "#334155", "emphasis": "#1E293B", "hover": "#475569", "statusBar": "#1E293B", "activeLight": "#E2E8F0", "activeDark": "#182334" }
    ]

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
    readonly property bool isDarkSideBar: isDarkMode || (effectiveThemeMode === light && lightDarkSideBar)

    readonly property string themeName: {
        if (effectiveThemeMode === lightHighContrast) return "Light High Contrast"
        if (effectiveThemeMode === darkHighContrast) return "Dark High Contrast"
        if (effectiveThemeMode === dark) return "Dark"
        return "Light"
    }

    readonly property var currentAccent: accentOption(accentColorIndex)

    function accentOption(index) {
        for (let i = 0; i < accentPalette.length; i++) {
            if (accentPalette[i].index === index)
                return accentPalette[i]
        }
        return accentPalette[4]
    }

    function accentOptionsForGroup(groupName) {
        let options = []
        for (let i = 0; i < accentPalette.length; i++) {
            if (accentPalette[i].group === groupName)
                options.push(accentPalette[i])
        }
        return options
    }
}
