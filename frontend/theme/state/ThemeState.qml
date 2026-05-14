pragma ComponentBehavior: Bound
pragma Singleton

import QtQuick

QtObject {
    property int themeMode: 0

    readonly property bool isDarkMode: {
        if (themeMode === 1) return false
        if (themeMode === 2) return true
        return Qt.application.styleHints.colorScheme === Qt.ColorScheme.Dark
    }
}
