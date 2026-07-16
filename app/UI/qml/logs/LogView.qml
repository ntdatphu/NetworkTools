pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

Rectangle {
    id: root
    objectName: "deviceLogsWorkspace"
    color: Theme.contentBackground

    readonly property var backend: typeof logController !== "undefined"
                                   ? logController
                                   : null

    Component.onCompleted: {
        if (root.backend)
            root.backend.initialize()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacing12
        spacing: Theme.spacing8

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing8

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.spacing2

                Text {
                    text: "Device Logs"
                    color: Theme.textPrimary
                    font.bold: true
                    font.pixelSize: Theme.fontSizeLarge
                    font.family: Theme.fontFamily
                }
                Text {
                    text: "Bounded packet capture and saved session inspection"
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontSizeSmall
                    font.family: Theme.fontFamily
                }
            }

            StandardBadge {
                text: root.backend ? String(root.backend.packetCount) : "0"
                badgeColor: Theme.accentEmphasis
            }
        }

        LogToolbar {
            Layout.fillWidth: true
            backend: root.backend
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            color: root.backend && root.backend.captureState === "error"
                   ? Theme.alertErrorSubtle
                   : Theme.alertInfoSubtle
            border.color: root.backend && root.backend.captureState === "error"
                          ? Theme.alertError
                          : Theme.contentPanelBorder
            border.width: Theme.borderWidth
            radius: Theme.radiusSmall

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.spacing8
                anchors.rightMargin: Theme.spacing8
                spacing: Theme.spacing8

                LoadingSpinner {
                    Layout.preferredWidth: Theme.iconSizeSmall
                    Layout.preferredHeight: Theme.iconSizeSmall
                    running: root.backend && root.backend.initializing
                }
                Text {
                    Layout.fillWidth: true
                    text: root.backend ? root.backend.statusMessage : "Device Logs backend is unavailable."
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSizeSmall
                    font.family: Theme.fontFamily
                    elide: Text.ElideRight
                }
                StandardButton {
                    text: root.backend && root.backend.viewPaused ? "Resume View" : "Pause View"
                    type: "Text"
                    enabled: root.backend && root.backend.packetCount > 0
                    onClicked: root.backend.togglePauseView()
                }
                StandardButton {
                    text: "Clear View"
                    type: "Text"
                    enabled: root.backend && root.backend.packetModel.count > 0
                    onClicked: root.backend.clearView()
                }
            }
        }

        SplitView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            orientation: Qt.Horizontal

            handle: StandardSplitHandle {}

            ColumnLayout {
                SplitView.fillWidth: true
                SplitView.minimumWidth: 620
                spacing: Theme.spacing8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacing8

                    StandardTextField {
                        id: displayFilter
                        objectName: "logDisplayFilter"
                        Layout.fillWidth: true
                        placeholderText: "Display filter: tcp, dns, ip.addr == 192.0.2.1"
                        onAccepted: root.backend.applyDisplayFilter(text)
                    }
                    StandardButton {
                        text: "Apply Filter"
                        type: "Secondary"
                        enabled: root.backend !== null
                        onClicked: root.backend.applyDisplayFilter(displayFilter.text)
                    }
                }

                LogPacketTable {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 220
                    backend: root.backend
                }

                PacketInspector {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.max(190, root.height * 0.32)
                    backend: root.backend
                }
            }

            Rectangle {
                id: sessionPanel
                objectName: "logSessionPanel"
                SplitView.preferredWidth: 280
                SplitView.minimumWidth: 220
                SplitView.maximumWidth: 380
                color: Theme.contentPanelSurface
                border.color: Theme.contentPanelBorder
                border.width: Theme.borderWidth
                radius: Theme.radiusSmall
                clip: true

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    Text {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        Layout.leftMargin: Theme.spacing12
                        text: "Saved capture sessions"
                        color: Theme.textPrimary
                        font.bold: true
                        font.pixelSize: Theme.fontSizeNormal
                        font.family: Theme.fontFamily
                        verticalAlignment: Text.AlignVCenter
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Theme.borderWidth
                        color: Theme.contentPanelBorder
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        ListView {
                            id: sessionList
                            anchors.fill: parent
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            model: root.backend ? root.backend.sessions : []

                            delegate: Rectangle {
                                id: sessionRow
                                required property var modelData

                                width: sessionList.width
                                height: 58
                                color: sessionHover.hovered ? Theme.sideBarItemHover : "transparent"

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.spacing12
                                    anchors.rightMargin: Theme.spacing8
                                    spacing: Theme.spacing2

                                    Text {
                                        Layout.fillWidth: true
                                        text: String(sessionRow.modelData.label || "")
                                        color: Theme.textPrimary
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.family: Theme.fontFamily
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: String(sessionRow.modelData.packet_count || 0)
                                              + " packets · "
                                              + String(sessionRow.modelData.status || "")
                                        color: Theme.textSecondary
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.family: Theme.fontFamily
                                        elide: Text.ElideRight
                                    }
                                }

                                HoverHandler { id: sessionHover; cursorShape: Qt.PointingHandCursor }
                                TapHandler {
                                    onTapped: root.backend.openSession(
                                        Number(sessionRow.modelData.session_id || 0)
                                    )
                                }
                            }
                            ScrollBar.vertical: ScrollBar {}
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: root.backend && root.backend.sessions.length === 0
                            text: "No saved sessions"
                            color: Theme.textDisabled
                            font.pixelSize: Theme.fontSizeNormal
                            font.family: Theme.fontFamily
                        }
                    }
                }
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: root.backend === null
        text: "Device Logs backend is unavailable"
        color: Theme.alertError
        font.family: Theme.fontFamily
    }
}
