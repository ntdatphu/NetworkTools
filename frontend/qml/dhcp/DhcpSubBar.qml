pragma ComponentBehavior: Bound

import QtQuick
import NetworkUI

// ─────────────────────────────────────────────────────────────────────────────
// DhcpSubBar
// Kế thừa generic SubBar.
// ─────────────────────────────────────────────────────────────────────────────
SubBar {
    id: root
    activeTab: "Info"
    tabs: ["Info", "Pool", "Excluded"]
}