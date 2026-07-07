pragma ComponentBehavior: Bound

import QtQuick
import UI

Rectangle {
    width: parent ? parent.width - 16 : 0
    height: Theme.borderWidth
    x: parent ? (parent.width - width) / 2 : 0
    color: Theme.panelSideBarBorderColor
}
