pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

Rectangle {
    id: root
    objectName: "externalToolCatalogSettings"
    color: Theme.contentBackground

    property var catalog: []
    property string query: ""
    readonly property var backend: typeof externalTools !== "undefined"
                                   ? externalTools
                                   : null
    readonly property var visibleRows: catalog.filter(function(row) {
        const needle = root.query.toLowerCase().trim()
        if (needle === "")
            return true
        return String(row.app || "").toLowerCase().indexOf(needle) !== -1
            || String(row.category || "").toLowerCase().indexOf(needle) !== -1
            || String(row.summary || "").toLowerCase().indexOf(needle) !== -1
    })
    readonly property int installedCount: catalog.filter(function(row) {
        return row.installed === true
    }).length
    readonly property int configuredCount: catalog.filter(function(row) {
        return row.configured === true
    }).length

    function reloadCatalog() {
        catalog = root.backend ? root.backend.getExternalToolCatalog() : []
    }

    function categoryIcon(category) {
        if (category === "DB Browser")
            return AppAssets.resource("resources/activitybar/database_search.svg")
        if (category === "Packet Capture")
            return AppAssets.resource("resources/activitybar/logs.svg")
        if (category === "SFTP Client")
            return AppAssets.resource("resources/activitybar/sftp.svg")
        return AppAssets.resource("resources/featurebar/terminal.svg")
    }

    Connections {
        target: root.backend
        function onToolsChanged() { root.reloadCatalog() }
    }

    Component.onCompleted: reloadCatalog()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacing24
        spacing: Theme.spacing12

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing12

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.spacing4

                Text {
                    text: "External Tools Catalog"
                    color: Theme.textPrimary
                    font.bold: true
                    font.pixelSize: Theme.fontSizeLarge
                    font.family: Theme.fontFamily
                }
                Text {
                    Layout.fillWidth: true
                    text: "Review supported applications detected on Windows. Downloads always open the vendor's official page and require your confirmation."
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontSizeSmall
                    font.family: Theme.fontFamily
                    wrapMode: Text.WordWrap
                }
            }

            StandardBadge {
                text: root.configuredCount + " configured"
                badgeColor: Theme.alertSuccess
            }
            StandardBadge {
                text: root.installedCount + " installed"
                badgeColor: Theme.accentEmphasis
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            color: Theme.alertInfoSubtle
            border.color: Theme.contentPanelBorder
            border.width: Theme.borderWidth
            radius: Theme.radiusSmall

            Text {
                anchors.fill: parent
                anchors.leftMargin: Theme.spacing12
                anchors.rightMargin: Theme.spacing12
                text: "NetworkTools does not install packages, run package managers, or change Windows defaults."
                color: Theme.textPrimary
                font.pixelSize: Theme.fontSizeSmall
                font.family: Theme.fontFamily
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing8

            StandardTextField {
                Layout.fillWidth: true
                placeholderText: "Search catalog…"
                onTextEdited: function(text) { root.query = text }
            }
            StandardButton {
                text: "Refresh Detection"
                type: "Secondary"
                onClicked: root.reloadCatalog()
            }
        }

        ScrollView {
            id: catalogScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: availableWidth
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.policy: ScrollBar.AsNeeded

            GridLayout {
                width: catalogScroll.availableWidth
                columns: width >= 880 ? 2 : 1
                columnSpacing: Theme.spacing12
                rowSpacing: Theme.spacing12

                Repeater {
                    model: root.visibleRows

                    delegate: Rectangle {
                        id: toolCard
                        required property var modelData

                        Layout.fillWidth: true
                        Layout.preferredHeight: 152
                        color: Theme.contentPanelSurface
                        border.color: toolCard.modelData.configured === true
                                      ? Theme.alertSuccess
                                      : Theme.contentPanelBorder
                        border.width: Theme.borderWidth
                        radius: Theme.cardRadius
                        opacity: toolCard.modelData.installed === true ? 1.0 : 0.58

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: Theme.spacing12
                            spacing: Theme.spacing8

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Theme.spacing8

                                ThemedIcon {
                                    Layout.preferredWidth: Theme.iconSizeLarge
                                    Layout.preferredHeight: Theme.iconSizeLarge
                                    iconSource: root.categoryIcon(toolCard.modelData.category)
                                    iconSize: Theme.iconSizeLarge
                                    iconColor: toolCard.modelData.installed === true
                                               ? Theme.textPrimary
                                               : Theme.textDisabled
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: Theme.spacing2
                                    Text {
                                        Layout.fillWidth: true
                                        text: String(toolCard.modelData.app || "")
                                        color: toolCard.modelData.installed === true
                                               ? Theme.textPrimary
                                               : Theme.textDisabled
                                        font.bold: true
                                        font.pixelSize: Theme.fontSizeNormal
                                        font.family: Theme.fontFamily
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        text: String(toolCard.modelData.category || "")
                                        color: Theme.textSecondary
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.family: Theme.fontFamily
                                    }
                                }
                                Text {
                                    text: String(toolCard.modelData.status || "")
                                    color: toolCard.modelData.configured === true
                                           ? Theme.alertSuccess
                                           : (toolCard.modelData.installed === true
                                              ? Theme.accentColor
                                              : Theme.textDisabled)
                                    font.bold: true
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.family: Theme.fontFamily
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: String(toolCard.modelData.summary || "")
                                color: toolCard.modelData.installed === true
                                       ? Theme.textSecondary
                                       : Theme.textDisabled
                                font.pixelSize: Theme.fontSizeSmall
                                font.family: Theme.fontFamily
                                wrapMode: Text.WordWrap
                            }

                            Item { Layout.fillHeight: true }

                            RowLayout {
                                Layout.fillWidth: true

                                Text {
                                    Layout.fillWidth: true
                                    text: String(toolCard.modelData.detectionSource || "")
                                    color: Theme.textDisabled
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.family: Theme.fontFamily
                                    elide: Text.ElideMiddle
                                }
                                StandardButton {
                                    text: "Official Page"
                                    type: "Text"
                                    onClicked: Qt.openUrlExternally(
                                        String(toolCard.modelData.officialUrl || "")
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
