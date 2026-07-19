import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

Dialog {
    id: root
    property var rowData: ({})
    title: "Syslog message details"
    modal: true
    width: Math.min(760, parent ? parent.width - 40 : 760)
    height: Math.min(520, parent ? parent.height - 40 : 520)
    standardButtons: Dialog.Close

    ColumnLayout {
        anchors.fill: parent
        spacing: 8
        Text { text: "Host: " + (root.rowData.device_host || "-"); color: Theme.textPrimary }
        Text { text: "Source: " + (root.rowData.source_ip || "-"); color: Theme.textSecondary }
        Text { text: "Facility/Severity: %1/%2".arg(root.rowData.facility || "-").arg(root.rowData.severity); color: Theme.textSecondary }
        TextArea {
            Layout.fillWidth: true; Layout.fillHeight: true
            readOnly: true; wrapMode: TextArea.Wrap
            text: root.rowData.raw_message || root.rowData.message || ""
        }
    }
}

