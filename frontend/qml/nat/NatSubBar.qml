pragma ComponentBehavior: Bound

import QtQuick
import NetworkTools

SubBar {
    id: root
    activeTab: "Info"
    tabs: ["Info", "Static", "Dynamic", "PAT", "Interfaces", "ACL"]
}