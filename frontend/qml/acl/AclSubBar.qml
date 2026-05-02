pragma ComponentBehavior: Bound

import QtQuick
import NetworkUI

// ─────────────────────────────────────────────────────────────────────────────
// AclSubBar
// Kế thừa generic SubBar.
// ─────────────────────────────────────────────────────────────────────────────
SubBar {
    id: root
    activeTab: "Info"
    tabs: ["Info", "Standard", "Extended"]
}