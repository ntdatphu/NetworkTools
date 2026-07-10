pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

Rectangle {
    id: dhcpHelperForm
    color: Theme.contentBackground

    property string currentHostIp: ""
    property var ifaceIds: []
    property var ifaceNames: []
    property var pushDialog: null

    function selectedIfaceId() {
        if (interfaceCombo.currentIndex < 0 || interfaceCombo.currentIndex >= ifaceIds.length)
            return -1
        return ifaceIds[interfaceCombo.currentIndex]
    }

    function notify(message, type) {
        if (typeof statusBar !== "undefined")
            statusBar.showMessage(message, type)
    }

    function normalizedHelper(row) {
        return {
            id: Number(row.id || 0),
            iface_id: Number(row.iface_id || 0),
            interface_name: String(row.interface_name || ""),
            helper_ip: String(row.helper_ip || ""),
            success: Number(row.success || 0)
        }
    }

    function reloadInterfaces() {
        const ids = []
        const names = []
        if (currentHostIp === "") {
            ifaceIds = ids
            ifaceNames = names
            interfaceCombo.currentIndex = -1
            return
        }

        const rows = dbManager.getRouterInterfaces(currentHostIp)
        for (let i = 0; i < rows.length; i++) {
            const name = rows[i].interface_name || ""
            if (name === "") continue
            ids.push(rows[i].iface_id)
            names.push(name)
        }
        ifaceIds = ids
        ifaceNames = names
        interfaceCombo.currentIndex = ifaceNames.length > 0 ? 0 : -1
    }

    function reloadHelpers() {
        helperListModel.clear()
        if (currentHostIp === "") return

        const rows = dbManager.getDhcpHelperAddresses(currentHostIp)
        for (let i = 0; i < rows.length; i++)
            helperListModel.append(normalizedHelper(rows[i]))
    }

    function reloadAll() {
        reloadInterfaces()
        reloadHelpers()
    }

    function openPushPreview() {
        if (!pushDialog) {
            pushDialog = pushDialogComponent.createObject(dhcpHelperForm, {
                hostIp: dhcpHelperForm.currentHostIp,
                ownerForm: dhcpHelperForm
            })
            pushDialog.pushCompleted.connect(function(ok, message) {
                if (ok)
                    dhcpHelperForm.reloadAll()
            })
        }
        pushDialog.hostIp = dhcpHelperForm.currentHostIp
        pushDialog.openPreview()
    }

    onCurrentHostIpChanged: reloadAll()
    Component.onCompleted: reloadAll()

    ListModel { id: helperListModel }

    Component {
        id: pushDialogComponent
        DhcpPushDialog {}
    }

    SplitView {
        anchors.fill: parent
        anchors.bottomMargin: 60
        orientation: Qt.Horizontal
        handle: StandardSplitHandle {}

        SplitFormPane {
            SplitView.preferredWidth: 320
            SplitView.minimumWidth: 240

            Text {
                text: "Add Helper Address"
                color: Theme.textPrimary
                font.pixelSize: Theme.fontSizeLarge
                font.family: Theme.fontFamily
                font.bold: true
            }

            Rectangle {
                Layout.fillWidth: true
                height: Theme.borderWidth
                color: Theme.splitHandleColor
            }

            StandardComboBox {
                id: interfaceCombo
                Layout.fillWidth: true
                labelText: "Interface"
                model: dhcpHelperForm.ifaceNames
                emptyWarningText: "No Interface options are available for this device. Add or load interfaces before configuring DHCP Helper."
            }

            StandardTextField {
                id: helperIpField
                Layout.fillWidth: true
                labelText: "Helper IP"
                placeholderText: "e.g., 10.10.10.5"
            }

            Item { Layout.fillHeight: true }

            StandardButton {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                type: "Primary"
                text: "Add Helper"
                enabled: dhcpHelperForm.selectedIfaceId() >= 0 &&
                         helperIpField.text.trim() !== "" &&
                         currentHostIp !== ""

                onClicked: {
                    const ok = dbManager.addDhcpHelperAddress(
                        dhcpHelperForm.selectedIfaceId(),
                        helperIpField.text.trim()
                    )
                    if (ok) {
                        helperIpField.text = ""
                        dhcpHelperForm.reloadHelpers()
                    }
                }
            }
        }

        SavedListPanel {
            SplitView.fillWidth: true
            SplitView.minimumWidth: 0
            title: "Helper Addresses"
            count: helperListModel.count
            countColor: Theme.accentColor
            emptyText: "No helper addresses configured yet.\nAdd one from the form on the left."
            headerComponent: Component {
                SavedListHeader {
                    width: parent ? parent.width : 0

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 40
                        spacing: 0

                        Text {
                            width: parent.width / 2 - 20
                            text: "Interface"
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: Theme.fontFamily
                            font.bold: true
                        }
                        Text {
                            text: "Helper IP"
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: Theme.fontFamily
                            font.bold: true
                        }
                    }
                }
            }

            ListView {
                anchors.fill: parent
                model: helperListModel
                clip: true
                spacing: 2
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                delegate: SavedListRow {
                    required property int index
                    required property var model
                    rowIndex: index

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 8
                        spacing: 0

                        Text {
                            width: (parent.width - 32) / 2
                            height: parent.height
                            text: model.interface_name
                            color: Theme.textPrimary
                            font.pixelSize: Theme.fontSizeNormal
                            font.family: Theme.fontFamily
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }
                        Text {
                            width: (parent.width - 32) / 2
                            height: parent.height
                            text: model.helper_ip
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeNormal
                            font.family: Theme.fontFamily
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }

                        Item {
                            width: 32
                            height: parent.height

                            IconButton {
                                anchors.centerIn: parent
                                buttonSize: 24
                                iconSize: 11
                                glyph: "X"
                                danger: true
                                tooltip: "Delete"
                                onClicked: {
                                    dbManager.deleteDhcpHelperAddress(model.id)
                                    dhcpHelperForm.reloadHelpers()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 12
        spacing: Theme.spacing8

        Text {
            Layout.fillWidth: true
            text: "Helper addresses are saved locally before push."
            color: Theme.textSecondary
            font.pixelSize: Theme.fontSizeSmall
            font.family: Theme.fontFamily
            elide: Text.ElideRight
        }

        StandardButton {
            text: "Reload"
            type: "Secondary"
            enabled: currentHostIp !== ""
            onClicked: {
                dhcpHelperForm.reloadAll()
                dhcpHelperForm.notify("Reloaded DHCP helper addresses for host " + currentHostIp, "info")
            }
        }

        StandardButton {
            text: "View & Push"
            type: "Primary"
            enabled: currentHostIp !== ""
            onClicked: dhcpHelperForm.openPushPreview()
        }
    }
}
