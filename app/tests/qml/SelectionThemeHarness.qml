import QtQuick
import UI

Item {
    readonly property color selectionBackground: Theme.selectionBackground
    readonly property color selectionForeground: Theme.selectionForeground

    function setSelectionContext(themeMode, customAccent) {
        ThemeState.themeMode = themeMode
        ThemeState.useCustomAccentColor = true
        ThemeState.customAccentColor = customAccent
    }
}
