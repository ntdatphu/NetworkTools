pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import UI

Rectangle {
    id: dhcpView
    color: Theme.contentBackground

    property string currentHostIp: ""
    property string currentTab:    "Pool"
    property int viewPushRevision: 0
    property bool poolLoaded: true
    property bool excludedLoaded: false
    property bool helperLoaded: false
    property bool infoLoaded: false

    function ensureCurrentTabLoaded() {
        switch (currentTab) {
        case "Pool": poolLoaded = true; break
        case "Excluded": excludedLoaded = true; break
        case "Helper": helperLoaded = true; break
        case "Info": infoLoaded = true; break
        }
    }

    onCurrentTabChanged: ensureCurrentTabLoaded()

    function notify(message, type) {
        if (typeof statusBar !== "undefined")
            statusBar.showMessage(message, type)
    }

    function refreshViewPush() {
        viewPushRevision++
    }

    function reloadDhcpData() {
        if (poolLoader.item)
            poolLoader.item.reloadPools()
        if (excludedLoader.item)
            excludedLoader.item.reloadExcluded()
        if (helperLoader.item)
            helperLoader.item.reloadAll()
        refreshViewPush()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing:      0

        // 1. Thanh tab con
        DhcpSubBar {
            Layout.fillWidth: true
            activeTab:        dhcpView.currentTab
            onTabClicked:     (tabName) => { dhcpView.currentTab = tabName }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 58
            color: Theme.contentSurface
            border.width: 0

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: Theme.borderWidth
                color: Theme.borderColor
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 24
                anchors.rightMargin: 24
                spacing: Theme.spacing12

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: "DHCP Information"
                        color: Theme.textPrimary
                        font.pixelSize: Theme.fontSizeLarge
                        font.family: Theme.fontFamily
                        font.bold: true
                    }

                    Text {
                        text: String(dhcpView.currentHostIp || "").trim() === ""
                            ? "No device selected"
                            : dhcpView.currentHostIp
                        color: Theme.textSecondary
                        font.pixelSize: Theme.fontSizeSmall
                        font.family: Theme.fontFamily
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                ViewPushButton {
                    type: "Primary"
                    controllerName: "dhcp"
                    moduleName: "all"
                    hostIp: dhcpView.currentHostIp
                    ownerForm: dhcpView
                    refreshKey: dhcpView.viewPushRevision
                    onPushCompleted: function(ok, message) {
                        if (ok)
                            dhcpView.reloadDhcpData()
                    }
                }
            }
        }

        // 2. Vùng nội dung
        Item {
            Layout.fillWidth:  true
            Layout.fillHeight: true

            // ── Info ──────────────────────────────────────────────
            // Phase D: converted from static Text to Loader (consistent with other tabs).
            // When DhcpInfoView is implemented, replace the placeholder component.
            Loader {
                anchors.fill: parent
                active: dhcpView.infoLoaded
                visible:      dhcpView.currentTab === "Info"
                sourceComponent: Component {
                    Item {
                        Text {
                            anchors.centerIn: parent
                            text:             "DHCP Info — Not yet implemented"
                            color:            Theme.textDisabled
                            font.pixelSize:   Theme.fontSizeNormal
                            font.family:      Theme.fontFamily
                        }
                    }
                }
            }

            // ── Pool ──────────────────────────────────────────────
            Loader {
                id: poolLoader
                anchors.fill:  parent
                active: dhcpView.poolLoaded
                visible: dhcpView.currentTab === "Pool"
                sourceComponent: Component {
                    DhcpPoolForm {
                        currentHostIp: dhcpView.currentHostIp
                        onDataChanged: dhcpView.refreshViewPush()
                    }
                }
            }

            // ── Excluded Address ──────────────────────────────────
            Loader {
                id: excludedLoader
                anchors.fill:  parent
                active: dhcpView.excludedLoaded
                visible: dhcpView.currentTab === "Excluded"
                sourceComponent: Component {
                    DhcpExcludedForm {
                        currentHostIp: dhcpView.currentHostIp
                        onDataChanged: dhcpView.refreshViewPush()
                    }
                }
            }

            // -- Helper Address --------------------------------------------
            Loader {
                id: helperLoader
                anchors.fill: parent
                active: dhcpView.helperLoaded
                visible: dhcpView.currentTab === "Helper"
                sourceComponent: Component {
                    DhcpHelperForm {
                        currentHostIp: dhcpView.currentHostIp
                        onDataChanged: dhcpView.refreshViewPush()
                    }
                }
            }
        }
    }

    onCurrentHostIpChanged: refreshViewPush()
}
