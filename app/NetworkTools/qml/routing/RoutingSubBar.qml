pragma ComponentBehavior: Bound

import QtQuick
import NetworkTools

// ─────────────────────────────────────────────────────────────────────────────
// RoutingSubBar
// Kế thừa generic SubBar.
// API giữ nguyên:
//   - property string activeTab
//   - signal tabClicked(string tabName)
// Do đó RoutingView.qml gọi file này sẽ không bị break (vỡ) layout.
// ─────────────────────────────────────────────────────────────────────────────
SubBar {
    id: root
    activeTab: "Info"
    tabs: ["Info", "Static", "OSPF", "EIGRP", "BGP"]
}
