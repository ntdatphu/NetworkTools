import QtQuick
import QtQuick.Layouts
import UI

Rectangle {
    id: root
    required property var rowData
    signal activated(var rowData)
    height: 34
    color: hover.hovered ? Theme.sideBarItemHover : "transparent"

    readonly property color severityColor: rowData.severity <= 2 ? Theme.alertError
                                           : rowData.severity <= 4 ? Theme.alertWarning
                                           : Theme.textSecondary

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 8
        Text { Layout.preferredWidth: 145; text: root.rowData.device_time || root.rowData.received_at || ""; color: Theme.textSecondary; elide: Text.ElideRight }
        Text { Layout.preferredWidth: 105; text: root.rowData.device_host || root.rowData.source_ip || ""; color: Theme.textPrimary; elide: Text.ElideRight }
        Text { Layout.preferredWidth: 105; text: root.rowData.source_ip || ""; color: Theme.textSecondary; elide: Text.ElideRight }
        Text { Layout.preferredWidth: 100; text: (root.rowData.facility || "-") + "/" + root.rowData.severity; color: root.severityColor; elide: Text.ElideRight }
        Text { Layout.preferredWidth: 110; text: root.rowData.mnemonic || "-"; color: Theme.textSecondary; elide: Text.ElideRight }
        Text { Layout.fillWidth: true; text: root.rowData.message || ""; color: Theme.textPrimary; elide: Text.ElideRight }
    }
    HoverHandler { id: hover }
    TapHandler { onDoubleTapped: root.activated(root.rowData) }
}
