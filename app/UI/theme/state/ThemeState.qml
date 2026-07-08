pragma ComponentBehavior: Bound
pragma Singleton

import QtQuick

QtObject {
    id: root

    readonly property int system: 0
    readonly property int light: 1
    readonly property int dark: 2
    readonly property int lightHighContrast: 3
    readonly property int darkHighContrast: 4

    property bool _loadingSettings: true
    property var backend: null
    property int themeMode: system
    property int accentColorIndex: 4
    property bool lightDarkSideBar: false
    property bool useCustomAccentColor: false
    property string customAccentColor: "#356FD6"

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
    readonly property bool isDarkSideBar: isDarkMode || lightDarkSideBar

    readonly property string themeName: {
        if (effectiveThemeMode === lightHighContrast) return qsTr("Light High Contrast")
        if (effectiveThemeMode === darkHighContrast) return qsTr("Dark High Contrast")
        if (effectiveThemeMode === dark) return qsTr("Dark")
        return qsTr("Light")
    }

    readonly property var currentAccent: useCustomAccentColor
                                         ? customAccentOption(customAccentColor)
                                         : accentOption(accentColorIndex)

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

    function accentGroupLabel(groupName) {
        switch (groupName) {
        case "Red": return qsTr("Red")
        case "Orange": return qsTr("Orange")
        case "Blue": return qsTr("Blue")
        case "Green": return qsTr("Green")
        case "Purple": return qsTr("Purple")
        case "Black": return qsTr("Black")
        case "Custom": return qsTr("Custom")
        }
        return groupName
    }

    function accentNameLabel(name) {
        switch (name) {
        case "Ruby": return qsTr("Ruby")
        case "Crimson": return qsTr("Crimson")
        case "Orange": return qsTr("Orange")
        case "Amber": return qsTr("Amber")
        case "Azure": return qsTr("Azure")
        case "Sky": return qsTr("Sky")
        case "Emerald": return qsTr("Emerald")
        case "Teal": return qsTr("Teal")
        case "Violet": return qsTr("Violet")
        case "Indigo": return qsTr("Indigo")
        case "Graphite": return qsTr("Graphite")
        case "Slate": return qsTr("Slate")
        case "Custom": return qsTr("Custom")
        case "Custom*": return qsTr("Custom*")
        }
        return name
    }

    function normalizeThemeMode(value) {
        if (value === light || value === dark || value === lightHighContrast || value === darkHighContrast)
            return value
        return system
    }

    function normalizeAccentColorIndex(value) {
        for (let i = 0; i < accentPalette.length; i++) {
            if (accentPalette[i].index === value)
                return value
        }
        return 4
    }

    function isValidAccentColor(value) {
        const text = String(value || "").trim()
        return /^#?[0-9a-fA-F]{3}$/.test(text) || /^#?[0-9a-fA-F]{6}$/.test(text)
    }

    function normalizeHexColor(value) {
        let text = String(value || "").trim()
        if (text.length === 0)
            return "#356FD6"
        if (text.charAt(0) !== "#")
            text = "#" + text
        if (/^#[0-9a-fA-F]{3}$/.test(text)) {
            return ("#" + text.charAt(1) + text.charAt(1)
                        + text.charAt(2) + text.charAt(2)
                        + text.charAt(3) + text.charAt(3)).toUpperCase()
        }
        if (/^#[0-9a-fA-F]{6}$/.test(text))
            return text.toUpperCase()
        return "#356FD6"
    }

    function channelToHex(value) {
        const text = Math.max(0, Math.min(255, Math.round(value))).toString(16).toUpperCase()
        return text.length === 1 ? "0" + text : text
    }

    function hexChannel(hexColor, offset) {
        return parseInt(hexColor.substr(offset, 2), 16)
    }

    function mixHexColor(sourceColor, targetColor, amount) {
        const source = normalizeHexColor(sourceColor)
        const target = normalizeHexColor(targetColor)
        const ratio = Math.max(0, Math.min(1, amount))
        const red = hexChannel(source, 1) + (hexChannel(target, 1) - hexChannel(source, 1)) * ratio
        const green = hexChannel(source, 3) + (hexChannel(target, 3) - hexChannel(source, 3)) * ratio
        const blue = hexChannel(source, 5) + (hexChannel(target, 5) - hexChannel(source, 5)) * ratio
        return "#" + channelToHex(red) + channelToHex(green) + channelToHex(blue)
    }

    function colorLuminance(hexColor) {
        const color = normalizeHexColor(hexColor)
        const red = hexChannel(color, 1) / 255
        const green = hexChannel(color, 3) / 255
        const blue = hexChannel(color, 5) / 255
        return 0.2126 * red + 0.7152 * green + 0.0722 * blue
    }

    function customAccentOption(value) {
        const base = normalizeHexColor(value)
        const lightBase = colorLuminance(base) > 0.55
        const emphasis = mixHexColor(base, "#000000", lightBase ? 0.36 : 0.18)
        return {
            "index": -1,
            "group": "Custom",
            "name": isValidAccentColor(value) ? "Custom" : "Custom*",
            "color": base,
            "emphasis": emphasis,
            "hover": mixHexColor(base, "#FFFFFF", lightBase ? 0.08 : 0.18),
            "statusBar": mixHexColor(base, "#000000", lightBase ? 0.52 : 0.22),
            "activeLight": mixHexColor(base, "#FFFFFF", 0.84),
            "activeDark": mixHexColor(base, "#000000", 0.68)
        }
    }

    function hasPersistentSettings() {
        return backend !== null
    }

    function loadPersistentSettings() {
        _loadingSettings = true
        if (hasPersistentSettings()) {
            themeMode = normalizeThemeMode(backend.themeMode)
            accentColorIndex = normalizeAccentColorIndex(backend.accentColorIndex)
            lightDarkSideBar = backend.lightDarkSideBar
            useCustomAccentColor = backend.useCustomAccentColor
            customAccentColor = backend.customAccentColor
        }
        _loadingSettings = false
        savePersistentSettings()
    }

    function savePersistentSettings() {
        if (!hasPersistentSettings())
            return

        backend.themeMode = normalizeThemeMode(themeMode)
        backend.accentColorIndex = normalizeAccentColorIndex(accentColorIndex)
        backend.lightDarkSideBar = lightDarkSideBar
        backend.useCustomAccentColor = useCustomAccentColor
        backend.customAccentColor = customAccentColor
    }

    onBackendChanged: loadPersistentSettings()
    onThemeModeChanged: if (!_loadingSettings) savePersistentSettings()
    onAccentColorIndexChanged: if (!_loadingSettings) savePersistentSettings()
    onLightDarkSideBarChanged: if (!_loadingSettings) savePersistentSettings()
    onUseCustomAccentColorChanged: if (!_loadingSettings) savePersistentSettings()
    onCustomAccentColorChanged: if (!_loadingSettings) savePersistentSettings()

    Component.onCompleted: loadPersistentSettings()
}
