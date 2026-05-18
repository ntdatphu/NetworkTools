pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import NetworkTools // <-- ĐÃ THÊM IMPORT QUAN TRỌNG

Rectangle {
    id: root

    property var form
    property ListModel routeModel
    property bool canSaveStatic: root.form && root.form.canSaveStaticOnly()

    Layout.fillWidth: true
    Layout.leftMargin: 24
    Layout.rightMargin: 24
    radius: 8
    color: Theme.contentPanelSurface
    border.color: Theme.contentPanelBorder
    border.width: Theme.borderWidth
    implicitHeight: staticCardLayout.implicitHeight + 16

    ColumnLayout {
        id: staticCardLayout
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "Static Routes"
                color: Theme.textPrimary
                font.pixelSize: Theme.fontSizeNormal
                font.family: Theme.fontFamily
                font.bold: true
                Layout.fillWidth: true
            }

            // ── Nút Add ──
            StandardButton {
                text: "+ Add"
                type: "Primary"
                onClicked: {
                    if (!root.form.canAddStaticRow())
                        return

                    root.routeModel.append({
                        id: 0,
                        routeId: 0,
                        network: "",
                        mask: "",
                        nexthop: "",
                        ad: "1",
                        originalNetwork: "",
                        originalMask: "",
                        originalNexthop: "",
                        originalAd: "1",
                        success: 0,
                        edited: false,
                        canEdit: true,
                        networkError: false,
                        maskError: false,
                        nexthopError: false
                    })
                    root.form.markDirty()
                }
            }

            // ── Nút Save Static ──
            StandardButton {
                text: root.form.isSaving ? "Saving..." : "Save Static"
                type: "Primary"
                enabled: root.canSaveStatic
                onClicked: root.form.saveStaticOnly()
            }
        }

        Text {
            visible: root.routeModel.count === 0
            text: "No static routes. Use + Add to create one."
            color: Theme.textSecondary
            font.pixelSize: Theme.fontSizeSmall
            font.family: Theme.fontFamily
            Layout.fillWidth: true
        }

        Repeater {
            model: root.routeModel

            delegate: Item {
                required property int index
                required property string network
                required property string mask
                required property string nexthop
                required property var ad
                required property int routeId
                required property string originalNetwork
                required property string originalMask
                required property string originalNexthop
                required property var originalAd
                required property int success
                required property bool edited
                required property bool canEdit
                required property bool networkError
                required property bool maskError
                required property bool nexthopError

                Layout.fillWidth: true
                implicitHeight: rowComp.implicitHeight

                StaticRouteRow {
                    id: rowComp
                    anchors.left: parent.left
                    anchors.right: parent.right

                    rowIndex: index
                    rowNetwork: network
                    rowMask: mask
                    rowNexthop: nexthop
                    rowAd: ad
                    rowRouteId: routeId
                    rowOriginalNetwork: originalNetwork
                    rowOriginalMask: originalMask
                    rowOriginalNexthop: originalNexthop
                    rowOriginalAd: originalAd
                    rowSuccess: success
                    rowEdited: edited
                    rowCanEdit: canEdit
                    rowNetworkError: networkError
                    rowMaskError: maskError
                    rowNexthopError: nexthopError

                    onNetworkTextChanged: function (text) {
                        root.routeModel.setProperty(index, "network", text)
                        if (String(text).trim() !== "")
                            root.routeModel.setProperty(index, "networkError", false)
                        if (rowRouteId > 0 && rowCanEdit)
                            root.routeModel.setProperty(index, "edited", true)
                        root.form.markDirty()
                    }
                    onMaskTextChanged: function (text) {
                        root.routeModel.setProperty(index, "mask", text)
                        if (String(text).trim() !== "")
                            root.routeModel.setProperty(index, "maskError", false)
                        if (rowRouteId > 0 && rowCanEdit)
                            root.routeModel.setProperty(index, "edited", true)
                        root.form.markDirty()
                    }
                    onNextHopTextChanged: function (text) {
                        root.routeModel.setProperty(index, "nexthop", text)
                        if (String(text).trim() !== "")
                            root.routeModel.setProperty(index, "nexthopError", false)
                        if (rowRouteId > 0 && rowCanEdit)
                            root.routeModel.setProperty(index, "edited", true)
                        root.form.markDirty()
                    }
                    onAdTextChanged: function (text) {
                        root.routeModel.setProperty(index, "ad", text)
                        if (rowRouteId > 0 && rowCanEdit)
                            root.routeModel.setProperty(index, "edited", true)
                        root.form.markDirty()
                    }
                    onChangeClicked: {
                        root.routeModel.setProperty(index, "canEdit", true)
                        root.routeModel.setProperty(index, "edited", false)
                    }
                    onCancelClicked: {
                        root.form.suppressDirty = true
                        root.routeModel.setProperty(index, "canEdit", false)
                        root.routeModel.setProperty(index, "network", rowOriginalNetwork)
                        root.routeModel.setProperty(index, "mask", rowOriginalMask)
                        root.routeModel.setProperty(index, "nexthop", rowOriginalNexthop)
                        root.routeModel.setProperty(index, "ad", String(rowOriginalAd))
                        root.routeModel.setProperty(index, "edited", false)
                        root.routeModel.setProperty(index, "networkError", false)
                        root.routeModel.setProperty(index, "maskError", false)
                        root.routeModel.setProperty(index, "nexthopError", false)
                        root.form.suppressDirty = false
                        root.form.refreshDirtyFlag()
                    }
                    onDeleteClicked: {
                            const f = root.form
                            root.routeModel.remove(index)
                            f.markDirty()
                    }
                    onAccepted: {
                        if (root.canSaveStatic)
                            root.form.saveStaticOnly()
                    }
                }
            }
        }
    }
}
