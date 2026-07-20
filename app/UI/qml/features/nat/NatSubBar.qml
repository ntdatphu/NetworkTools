pragma ComponentBehavior: Bound

import QtQuick
import UI

SubBar {
    id: root
    activeTab: "Static"
    tabs: ["Info", "Static", "Dynamic", "PAT", "Interfaces", "ACL", "Route Map"]
    disabledTabs: ["Info"]
}
