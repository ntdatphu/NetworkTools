pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import UI

Rectangle {
    id: root

    required property var backend
    property string selectedDeviceHost: ""

    readonly property var interfaceRows: backend ? backend.interfaces : []
    readonly property var deviceRows: backend ? backend.devices : []
    readonly property var interfaceLabels: interfaceRows.map(function(row) {
        return String(row.label || row.name || row.id || "")
    })
    readonly property var interfaceIds: interfaceRows.map(function(row) {
        return String(row.id || "")
    })
    readonly property var deviceLabels: ["All devices"].concat(
        deviceRows.map(function(row) { return String(row.label || row.host || "") })
    )
    readonly property var deviceHosts: [""].concat(
        deviceRows.map(function(row) { return String(row.host || "") })
    )

    color: Theme.contentPanelSurface
    border.color: Theme.contentPanelBorder
    border.width: Theme.borderWidth
    radius: Theme.radiusSmall
    implicitHeight: controls.implicitHeight + Theme.spacing16

    RowLayout {
        id: controls
        anchors.fill: parent
        anchors.margins: Theme.spacing8
        spacing: Theme.spacing8

        StandardComboBox {
            id: interfaceBox
            objectName: "logInterfaceSelector"
            Layout.preferredWidth: 260
            labelText: "Capture interface"
            model: root.interfaceLabels
            valueModel: root.interfaceIds
            emptyText: root.backend && root.backend.initializing
                       ? "Detecting interfaces…"
                       : "No capture interface"
            enabled: root.backend && !root.backend.isCapturing
            onActivated: function(index) {
                if (index >= 0 && index < root.interfaceIds.length)
                    root.backend.selectInterface(root.interfaceIds[index])
            }
        }

        StandardComboBox {
            id: deviceBox
            objectName: "logDeviceSelector"
            Layout.preferredWidth: 240
            labelText: "Device scope"
            model: root.deviceLabels
            valueModel: root.deviceHosts
            enabled: root.backend && !root.backend.isCapturing
            onActivated: function(index) {
                root.selectedDeviceHost = index >= 0 && index < root.deviceHosts.length
                                        ? root.deviceHosts[index]
                                        : ""
            }
        }

        StandardTextField {
            id: captureFilter
            objectName: "logCaptureFilter"
            Layout.fillWidth: true
            Layout.minimumWidth: 180
            labelText: "Capture filter"
            placeholderText: "e.g., tcp port 22"
            enabled: root.backend && !root.backend.isCapturing
        }

        StandardButton {
            objectName: "logRescanButton"
            Layout.alignment: Qt.AlignBottom
            text: root.backend && root.backend.initializing ? "Scanning…" : "Scan"
            type: "Secondary"
            enabled: root.backend && !root.backend.initializing && !root.backend.isCapturing
            tooltip: "Detect TShark and available capture interfaces"
            onClicked: root.backend.refreshDependencies()
        }

        StandardButton {
            objectName: "logCaptureButton"
            Layout.alignment: Qt.AlignBottom
            text: root.backend && root.backend.isCapturing ? "Stop Capture" : "Start Capture"
            type: root.backend && root.backend.isCapturing ? "Danger" : "Primary"
            enabled: root.backend
                     && !root.backend.initializing
                     && (root.backend.isCapturing || root.backend.captureAvailable)
            onClicked: {
                if (root.backend.isCapturing)
                    root.backend.stopCapture()
                else
                    root.backend.startCapture(captureFilter.text, root.selectedDeviceHost)
            }
        }
    }
}
