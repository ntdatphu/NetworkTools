import QtQuick
import QtQuick.Layouts
import UI

Rectangle {
    id: root
    required property var rowData
    signal activated(var rowData)
    height: 34
    color: hover.hovered ? Theme.sideBarItemHover : "transparent"

    readonly property color severityColor: rowData.severity <= 2 ? Theme.statusError
                                           : rowData.severity <= 4 ? Theme.statusWarning
                                           : Theme.textSecondary

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 8
        Text { Layout.preferredWidth: 150; text: rowData.device_time || rowData.received_at || ""; color: Theme.textSecondary; elide: Text.ElideRight }
        Text { Layout.preferredWidth: 120; text: rowData.device_host || rowData.source_ip || ""; color: Theme.textPrimary; elide: Text.ElideRight }
        Text { Layout.preferredWidth: 105; text: (rowData.facility || "-") + "/" + rowData.severity; color: root.severityColor; elide: Text.ElideRight }
        Text { Layout.preferredWidth: 120; text: rowData.mnemonic || "-"; color: Theme.textSecondary; elide: Text.ElideRight }
        Text { Layout.fillWidth: true; text: rowData.message || ""; color: Theme.textPrimary; elide: Text.ElideRight }
    }
    HoverHandler { id: hover }
    TapHandler { onDoubleTapped: root.activated(root.rowData) }
}

