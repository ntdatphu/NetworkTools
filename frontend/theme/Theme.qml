pragma ComponentBehavior: Bound
pragma Singleton

import QtQuick
import NetworkTools

QtObject {

    // ── 1. WINDOW SIZE ──────────────────────────────────────────────────────
    readonly property int windowDefaultWidth:  1440
    readonly property int windowDefaultHeight: 1024
    readonly property int windowMinWidth:      900
    readonly property int windowMinHeight:     600

    // ── 2. COMPONENT SIZE ───────────────────────────────────────────────────
    readonly property int activityBarWidth:    48
    readonly property int sideBarWidth:        300
    readonly property int windowTitleHeight:   35
    readonly property int featureBarHeight:    35
    readonly property int statusBarHeight:     22
    readonly property int tabBarHeight:        35
    readonly property int subBarHeight:        36

    // ── 3. SIDEBAR DETAILS ──────────────────────────────────────────────────
    readonly property int listItemHeight:      28
    readonly property int statusIconSize:      28
    readonly property int sideBarFeatureIcon:  28
    readonly property int searchBarHeight:     28

    // ── 3b. SIDEBAR BEHAVIOR ─────────────────────────────────────────────────
    readonly property int sideBarMinWidth:         180  // Ngưỡng tối thiểu khi kéo
    readonly property int sideBarCollapseWidth:    60   // Dưới ngưỡng này → collapse hoàn toàn
    readonly property int openEditorsMaxCount:     5    // Số lượng Open Editors tối đa hiển thị

    // ── 4. COMMON UI METRICS ────────────────────────────────────────────────
    readonly property int itemHeight:          32
    readonly property int contextMenuWidth:    160
    readonly property int checkboxSize:        16
    readonly property int footerHeight:        56

    // ── 4b. ICON SIZES ───────────────────────────────────────────────────────
    readonly property int iconSizeSmall:       14
    readonly property int iconSizeNormal:      16
    readonly property int iconSizeLarge:       20
    readonly property int iconSizeXLarge:      24

    // ── 4c. BORDER ──────────────────────────────────────────────────────────
    readonly property int borderWidth:         1

    // ── 4d. BORDER RADIUS ───────────────────────────────────────────────────
    readonly property int radiusSmall:         4
    readonly property int radiusMedium:        6
    readonly property int radiusLarge:         8
    readonly property int radiusRound:         999

    readonly property int borderRadius:        4
    readonly property int cardRadius:          6

    // ── 4e. SPACING ──────────────────────────────────────────────────────────
    readonly property int spacing2:            2
    readonly property int spacing4:            4
    readonly property int spacing8:            8
    readonly property int spacing12:           12
    readonly property int spacing16:           16
    readonly property int spacing24:           24
    readonly property int spacing32:           32

    // ── 4f. SPLIT VIEW HANDLE ────────────────────────────────────────────────
    readonly property int   splitHandleWidth:      1    // Độ rộng line khi không hover
    readonly property int   splitHandleHitWidth:   5    // Vùng nhạy chuột (rộng hơn để dễ bắt)
    readonly property int   splitCollapseButtonSize: 16 // Nút > / < khi collapse

    // ── 5. TYPOGRAPHY ───────────────────────────────────────────────────────
    readonly property string fontFamily:       "Segoe UI"
    readonly property int fontSizeCaption:     10
    readonly property int fontSizeSmall:       11
    readonly property int fontSizeNormal:      13
    readonly property int fontSizeLarge:       15
    readonly property int fontSizeTitle:       18
    readonly property int fontSizeDisplay:     24

    // ── 6. ANIMATION ────────────────────────────────────────────────────────
    readonly property int animationDurationFast:   120
    readonly property int animationDurationMedium: 150
    readonly property int animationDurationSlow:   250

    // ── 7. THEME MODE ───────────────────────────────────────────────────────
    property int themeMode: 0

    property bool isDarkMode: {
        if (themeMode === 1) return false
        if (themeMode === 2) return true
        return Qt.application.styleHints.colorScheme === Qt.ColorScheme.Dark
    }

    // ── 8. BACKGROUND COLORS ────────────────────────────────────────────────
    property color windowTitleBackground: isDarkMode ? "#18181B" : "#E8E8E8"
    property color activityBarBackground: isDarkMode ? "#18181B" : "#FFFFFF"
    property color sideBarBackground:     isDarkMode ? "#27272A" : "#F6F8FA"
    property color featureBarBackground:  isDarkMode ? "#27272A" : "#F6F8FA"
    property color contentBackground:     isDarkMode ? "#18181B" : "#FFFFFF"
    property color statusBarBackground:   isDarkMode ? "#005A9E" : "#0969DA"
    property color tabBarBackground:      isDarkMode ? "#27272A" : "#F6F8FA"

    // ── 9. INTERACTIVE COLORS ───────────────────────────────────────────────
    property color activityBarItemHover:  isDarkMode ? "#3F3F46" : "#E8E8E8"
    property color activityBarItemActive: isDarkMode ? "#52525B" : "#E0E0E0"

    property color sideBarItemHover:      isDarkMode ? "#3F3F46" : "#E8E8E8"
    property color sideBarItemSelected:   isDarkMode ? "#094771" : "#DDEEFF"

    property color tabActive:             isDarkMode ? "#18181B" : "#FFFFFF"
    property color tabInactive:           isDarkMode ? "#27272A" : "#F3F3F3"
    property color tabHover:              isDarkMode ? "#3F3F46" : "#E8E8E8"

    property color featureMainActive:     isDarkMode ? "#3F3F46" : "#E0E0E0"
    property color featureMainHover:      isDarkMode ? "#52525B" : "#EBEBEB"

    property color titleButtonHover:      isDarkMode ? "#3F3F46" : "#E8E8E8"

    // ── 10. TEXT COLORS ─────────────────────────────────────────────────────
    property color textPrimary:           isDarkMode ? "#F4F4F5" : "#1A1A1A"
    property color textSecondary:         isDarkMode ? "#A1A1AA" : "#6B6B6B"
    property color textDisabled:          isDarkMode ? "#D9D9D9" : "#ABABAB"
    property color placeholderTextColor:  isDarkMode ? "#949AA1" : "#9CA3AF"

    // ── 11. BORDER & ACCENT ─────────────────────────────────────────────────
    property color borderColor:           isDarkMode ? "#3F3F46" : "#E8EAED"
    property color borderColor2:          isDarkMode ? "#3B82F6" : "#2196F3"
    property color accentColor:           isDarkMode ? "#3B82F6" : "#0078D4"
    readonly property color brandOrange:  "#FF7F2A"
    property color subBarAccentColor:     brandOrange

    // ── 11b. INPUT FIELD ─────────────────────────────────────────────────────
    // Tách biệt với searchBackground2 để input field rõ hơn
    property color inputBackground:       isDarkMode ? "#1E1E1E" : "#FFFFFF"
    property color inputBorderColor:      isDarkMode ? "#3C3C3C" : "#CECECE"
    property color inputBorderFocusColor: accentColor

    // ── 11c. SPLIT HANDLE ────────────────────────────────────────────────────
    property color splitHandleColor:      isDarkMode ? "#3F3F46" : "#E0E0E0"
    property color splitHandleHoverColor: accentColor  // Xanh giống StatusBar khi hover

    // ── 12. SEMANTIC COLORS ─────────────────────────────────────────────────
    readonly property color statusConnected:    "#2D9CDB"
    readonly property color statusWaiting:      "#9E9E9E"
    readonly property color statusDisconnected: "#EB5757"

    property color alertError:            statusDisconnected
    property color alertSuccess:          statusConnected
    property color alertWarning:          "#FFC107"
    property color alertInfo:             accentColor

    readonly property color alertErrorSubtle:   Qt.rgba(0.922, 0.341, 0.341, 0.12)
    readonly property color alertWarningSubtle: Qt.rgba(1.0,   0.753, 0.027, 0.12)
    readonly property color alertSuccessSubtle: Qt.rgba(0.176, 0.612, 0.859, 0.12)
    readonly property color alertInfoSubtle:    Qt.rgba(0.231, 0.510, 0.965, 0.12)

    readonly property color badgeWarningBg:    "#FFEFD5"
    readonly property color badgeWarningText:  "#9A5A00"
    readonly property color badgeErrorBg:      isDarkMode ? "#3D1515" : "#FFE5E5"
    readonly property color badgeErrorText:    "#C0392B"
    readonly property color badgeSuccessBg:    isDarkMode ? "#0D2D3D" : "#E5F4FB"
    readonly property color badgeSuccessText:  "#1A6E9A"

    // ── 13. BUTTON COLORS ───────────────────────────────────────────────────
    property color buttonTextSolid:       "#FFFFFF"
    property color buttonDisabled:        isDarkMode ? "#3F3F46" : "#CCCCCC"

    // ── 14. SEARCH / INPUT ──────────────────────────────────────────────────
    property color searchBackground:      isDarkMode ? "#18181B" : "#FFFFFF"
    property color searchBackground2:     isDarkMode ? "#27272A" : "#F5F5F5"

    // ── 15. STATUS BAR ──────────────────────────────────────────────────────
    readonly property color statusBarDimText:  Qt.rgba(1, 1, 1, 0.70)
    readonly property color statusBarSepColor: Qt.rgba(1, 1, 1, 0.25)

    // ── 15b. SHADOW & OVERLAY ───────────────────────────────────────────────
    readonly property color shadowColor:       Qt.rgba(0, 0, 0, 0.25)
    readonly property color shadowColorLight:  Qt.rgba(0, 0, 0, 0.15)
    readonly property color dialogOverlay:     "#80000000"

    // ── 16. APP STATE ───────────────────────────────────────────────────────
    property bool windowLock: false

    property int _lockTimestamp: 0

    onWindowLockChanged: {
        if (windowLock) {
            _lockTimestamp = Date.now()
            _watchdogTimer.restart()
        } else {
            _watchdogTimer.stop()
        }
    }

    property Timer _watchdogTimer: Timer {
        interval: 30000
        repeat: false
        onTriggered: {
            if (Theme.windowLock) {
                Theme.windowLock = false
            }
        }
    }
}
