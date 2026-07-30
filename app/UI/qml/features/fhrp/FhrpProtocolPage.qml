pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

Rectangle {
    id: root

    required property string protocol
    property string currentHostIp: ""
    property var hostOptions: []
    property var matchingInterfaces: []
    property string errorText: ""
    property int viewPushRevision: 0
    property alias savedGroupModel: groupModel
    readonly property bool isViewLoading: false

    color: Theme.contentBackground

    ListModel { id: memberModel }
    ListModel { id: groupModel }

    function notify(message, type) {
        if (typeof statusBar !== "undefined")
            statusBar.showMessage(message, type)
    }

    function reloadData(reason) {
        loadOptions()
        loadGroups()
        return true
    }

    function loadOptions() {
        const result = dbManager.getFhrpOptions()
        hostOptions = result && result.hosts ? result.hosts : []
    }

    function loadGroups() {
        groupModel.clear()
        const result = dbManager.getFhrpGroups(currentHostIp)
        const rows = result && result.groups ? result.groups : []
        for (let i = 0; i < rows.length; i++) {
            if (String(rows[i].protocol || "").toLowerCase() === root.protocol)
                groupModel.append(rows[i])
        }
        viewPushRevision++
    }

    function findMemberIndex(host) {
        for (let i = 0; i < memberModel.count; i++) {
            if (memberModel.get(i).host === host)
                return i
        }
        return -1
    }

    function toggleHost(host, selected) {
        const index = findMemberIndex(host)
        if (selected && index < 0) {
            memberModel.append({
                host: host,
                ifaceId: 0,
                priority: "100",
                preempt: true,
                authType: "none",
                authSecret: "",
                interfaceOptions: []
            })
        } else if (!selected && index >= 0) {
            memberModel.remove(index)
        }
        refreshMatchingInterfaces()
    }

    function selectedHosts() {
        const hosts = []
        for (let i = 0; i < memberModel.count; i++)
            hosts.push(memberModel.get(i).host)
        return hosts
    }

    function refreshMatchingInterfaces() {
        const gateway = gatewayField.text.trim()
        if (gateway === "" || memberModel.count === 0) {
            matchingInterfaces = []
            return
        }
        const result = dbManager.getFhrpMatchingInterfaces(
            selectedHosts(), gateway)
        if (!result.ok) {
            errorText = String(result.message || "")
            matchingInterfaces = []
            return
        }
        errorText = ""
        matchingInterfaces = result.interfaces || []
        for (let i = 0; i < memberModel.count; i++) {
            const host = memberModel.get(i).host
            const options = matchingInterfaces.filter(item => item.host === host)
            memberModel.setProperty(i, "interfaceOptions", options)
            const current = Number(memberModel.get(i).ifaceId || 0)
            if (!options.some(item => Number(item.iface_id) === current))
                memberModel.setProperty(i, "ifaceId",
                                        options.length > 0 ? Number(options[0].iface_id) : 0)
        }
    }

    function updateMember(index, field, value) {
        memberModel.setProperty(index, field, value)
    }

    function memberPayload() {
        const members = []
        for (let i = 0; i < memberModel.count; i++) {
            const row = memberModel.get(i)
            members.push({
                host: row.host,
                iface_id: Number(row.ifaceId),
                priority: Number(row.priority),
                preempt: row.preempt,
                shutdown: false,
                auth_type: row.authType,
                auth_secret: row.authSecret,
                version: root.protocol === "vrrp" ? 3 : 2
            })
        }
        return members
    }

    function saveGroup(pushAfterSave) {
        errorText = ""
        if (memberModel.count < 2) {
            errorText = "Select at least two hosts."
            return
        }
        for (let i = 0; i < memberModel.count; i++) {
            if (Number(memberModel.get(i).ifaceId || 0) <= 0) {
                errorText = "No matching interface for " + memberModel.get(i).host + "."
                return
            }
        }
        const result = dbManager.saveFhrpGroup({
            protocol: root.protocol,
            group_number: groupField.text.trim(),
            default_gateway: gatewayField.text.trim(),
            description: descriptionField.text.trim(),
            members: memberPayload()
        })
        if (!result.ok) {
            errorText = String(result.message || "Could not save FHRP group.")
            notify(errorText, "error")
            return
        }
        notify(String(result.message || ""), "success")
        loadGroups()
        if (pushAfterSave)
            batchDialog.openPreview(result.hosts || [], root.protocol)
    }

    function deleteGroup(fhrpId) {
        const result = dbManager.deleteFhrpGroup(Number(fhrpId))
        notify(String(result.message || ""), result.ok ? "success" : "error")
        if (result.ok) {
            loadGroups()
            batchDialog.openPreview(result.hosts || [], root.protocol)
        }
    }

    onCurrentHostIpChanged: loadGroups()
    Component.onCompleted: {
        loadOptions()
        loadGroups()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 68
            color: Theme.contentSurface
            WorkspaceHeader {
                anchors.fill: parent
                anchors.leftMargin: Theme.spacing24
                anchors.rightMargin: Theme.spacing24
                title: root.protocol.toUpperCase()
                subtitle: "Multi-device " + root.protocol.toUpperCase()
                          + " default-gateway configuration"
                ViewPushButton {
                    type: "Primary"
                    controllerName: "fhrp"
                    moduleName: root.protocol
                    hostIp: root.currentHostIp
                    ownerForm: root
                    refreshKey: root.viewPushRevision
                }
            }
        }

        SplitView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            orientation: width < Theme.dataWorkspaceBreakpoint
                         ? Qt.Vertical : Qt.Horizontal
            handle: StandardSplitHandle {}

            SplitFormPane {
                SplitView.preferredWidth: parent.width * 0.66
                SplitView.minimumWidth: 520

                SectionTitle { text: "New " + root.protocol.toUpperCase() + " group" }
                InlineMessage {
                    Layout.fillWidth: true
                    visible: root.errorText !== ""
                    severity: "warning"
                    message: root.errorText
                }

                FormSection {
                    Layout.fillWidth: true
                    title: "1. Group and Default Gateway"
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: Theme.spacing12
                        StandardTextField {
                            id: groupField
                            Layout.fillWidth: true
                            labelText: "Group / VRID"
                            inputMethodHints: Qt.ImhDigitsOnly
                        }
                        StandardNetworkField {
                            id: gatewayField
                            Layout.fillWidth: true
                            inputKind: "ipv4"
                            labelText: "Default Gateway IP"
                            placeholderText: "192.168.10.1"
                            onTextEdited: matchingTimer.restart()
                        }
                        StandardTextField {
                            id: descriptionField
                            Layout.fillWidth: true
                            labelText: "Description"
                        }
                    }
                }

                FormSection {
                    Layout.fillWidth: true
                    title: "2. Participating hosts"
                    Flow {
                        Layout.fillWidth: true
                        spacing: Theme.spacing12
                        Repeater {
                            model: root.hostOptions
                            delegate: StandardCheckBox {
                                required property var modelData
                                text: modelData.host
                                checked: root.findMemberIndex(modelData.host) >= 0
                                onToggled: root.toggleHost(modelData.host, checked)
                            }
                        }
                    }
                }

                FormSection {
                    Layout.fillWidth: true
                    title: "3. Per-host interface and parameters"
                    Repeater {
                        model: memberModel
                        delegate: FhrpMemberEditor {
                            required property int index
                            required property string host
                            required property var interfaceOptions
                            required property int ifaceId
                            required property string priority
                            required property bool preempt
                            required property string authType
                            required property string authSecret
                            memberIndex: index
                            protocol: root.protocol
                            onFieldChanged: function(memberIndex, field, value) {
                                root.updateMember(memberIndex, field, value)
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Item { Layout.fillWidth: true }
                    StandardButton {
                        text: "Save"
                        icon.source: AppAssets.actionSave
                        type: "Secondary"
                        onClicked: root.saveGroup(false)
                    }
                    StandardButton {
                        text: "Save & Push"
                        icon.source: AppAssets.actionSave
                        type: "Primary"
                        onClicked: root.saveGroup(true)
                    }
                }
            }

            FhrpSavedGroupsPanel {
                SplitView.fillWidth: true
                SplitView.minimumWidth: 300
                groupModel: root.savedGroupModel
                onRemoveRequested: function(fhrpId) {
                    root.deleteGroup(fhrpId)
                }
            }
        }
    }

    Timer {
        id: matchingTimer
        interval: 250
        repeat: false
        onTriggered: root.refreshMatchingInterfaces()
    }

    MultiHostViewPushDialog {
        id: batchDialog
        parent: Overlay.overlay
        controllerName: "fhrp"
        featureLabel: "FHRP"
        ownerForm: root
    }
}
