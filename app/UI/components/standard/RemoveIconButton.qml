pragma ComponentBehavior: Bound

import QtQuick.Layouts
import UI

StandardButton {
    id: root

    type: "Icon"
    tooltip: "Remove"
    icon.source: AppAssets.resource("resources/devicetabs/close.svg")
    Layout.preferredWidth: 34
}
