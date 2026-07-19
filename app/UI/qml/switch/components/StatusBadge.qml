pragma ComponentBehavior: Bound

import QtQuick
import UI

Rectangle {
    id: root
    property string value: "unknown"
    implicitWidth: label.implicitWidth + Theme.spacing16
    implicitHeight: 24
    radius: Theme.radiusRound
    color: value === "up" || value === "active" ? Theme.alertSuccessSubtle
         : value === "down" || value === "err-disabled" || value === "suspend"
           ? Theme.alertErrorSubtle
         : Theme.alertInfoSubtle

    Text {
        id: label
        anchors.centerIn: parent
        text: root.value
        color: root.value === "up" || root.value === "active" ? Theme.alertSuccess
             : root.value === "down" || root.value === "err-disabled"
               || root.value === "suspend" ? Theme.alertError
             : Theme.textSecondary
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
    }
}
