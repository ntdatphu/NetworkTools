pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import UI

StandardButton {
    id: root

    property string controllerName: "routing"
    property string hostIp: ""
    property string moduleName: "all"
    property int refreshKey: 0
    property bool hasPendingConfig: false
    property bool isCheckingPending: false
    property var ownerForm: null
    property var pushDialog: null

    signal pushCompleted(bool ok, string message)

    text: "View & Push"
    icon.source: AppAssets.actionPush
    enabled: !isCheckingPending && hasPendingConfig && String(hostIp || "").trim() !== ""
    tooltip: enabled ? "" : "No configuration required for Push."

    function refreshPending() {
        const host = String(hostIp || "").trim()
        if (host === "") {
            hasPendingConfig = false
            return
        }

        isCheckingPending = true
        hasPendingConfig = dbManager.hasPendingViewPush(controllerName, host, moduleName)
        isCheckingPending = false
    }

    function openPushPreview() {
        if (!enabled)
            return
        if (!pushDialog) {
            const dialogParent = Overlay.overlay || root
            pushDialog = pushDialogComponent.createObject(dialogParent, {
                controllerName: root.controllerName,
                hostIp: root.hostIp,
                moduleName: root.moduleName,
                ownerForm: root.ownerForm
            })
            pushDialog.pushCompleted.connect(function(ok, message) {
                root.refreshPending()
                root.pushCompleted(ok, message)
            })
        }
        pushDialog.controllerName = root.controllerName
        pushDialog.hostIp = root.hostIp
        pushDialog.moduleName = root.moduleName
        pushDialog.ownerForm = root.ownerForm
        pushDialog.openPreview()
    }

    onClicked: openPushPreview()
    onHostIpChanged: refreshPending()
    onModuleNameChanged: refreshPending()
    onControllerNameChanged: refreshPending()
    onRefreshKeyChanged: refreshPending()
    Component.onCompleted: refreshPending()

    Component {
        id: pushDialogComponent
        ViewPushDialog {}
    }
}
