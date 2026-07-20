pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import UI

RowLayout {
    id: root

    property string title: ""
    property int totalCount: 0
    property int visibleCount: totalCount
    property string searchText: ""
    property string searchPlaceholder: "Filter rows..."
    property bool searchEnabled: true

    signal searchEdited(string value)

    spacing: Theme.spacing8

    Text {
        text: root.title
        color: Theme.textPrimary
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeNormal
        font.weight: Font.DemiBold
    }

    Text {
        text: root.visibleCount === root.totalCount
              ? String(root.totalCount)
              : "%1 of %2".arg(root.visibleCount).arg(root.totalCount)
        color: Theme.textSecondary
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
    }

    Item { Layout.fillWidth: true }

    StandardTextField {
        visible: root.searchEnabled
        Layout.preferredWidth: Math.min(260, Math.max(170, root.width * 0.36))
        text: root.searchText
        placeholderText: root.searchPlaceholder
        onTextEdited: value => root.searchEdited(value)
    }
}
