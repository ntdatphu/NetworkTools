import QtQuick
import UI

Item {
    readonly property color selectionBackground: Theme.selectionBackground
    readonly property color selectionForeground: Theme.selectionForeground
    readonly property int effectiveThemeMode: ThemeState.effectiveThemeMode
    readonly property bool highContrastEnabled: ThemeState.isHighContrast

    function setSelectionContext(themeMode, customAccent) {
        ThemeState.themeMode = themeMode
        ThemeState.useCustomAccentColor = true
        ThemeState.customAccentColor = customAccent
    }

    function setThemeContext(themeMode, highContrast) {
        ThemeState.themeMode = themeMode
        ThemeState.highContrast = highContrast
    }
}
