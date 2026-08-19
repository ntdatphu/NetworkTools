pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

Rectangle {
    id: root
    objectName: "vtpPage"

    required property string host
    property var hostOptions: []
    property string errorText: ""
    property int dataRevision: 0
    readonly property int maxHosts: 5
    readonly property bool isViewLoading: false
    readonly property bool compactLayout: width < Theme.dataWorkspaceBreakpoint
    readonly property bool readyToSave: memberModel.count >= 2
                                            && domainField.text.trim() !== ""

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
        const result = dbManager.getVtpGroupOptions()
        hostOptions = result && result.hosts ? result.hosts : []
    }

    function loadGroups() {
        groupModel.clear()
        const result = dbManager.getVtpGroups()
        const rows = result && result.groups ? result.groups : []
        for (let i = 0; i < rows.length; i++)
            groupModel.append(rows[i])
        dataRevision++
    }

    function findMemberIndex(targetHost) {
        for (let i = 0; i < memberModel.count; i++) {
            if (memberModel.get(i).host === targetHost)
                return i
        }
        return -1
    }

    function toggleHost(targetHost, selected) {
        const index = findMemberIndex(targetHost)
        if (selected && index < 0) {
            if (memberModel.count >= maxHosts) {
                errorText = "VTP Group supports at most " + maxHosts + " switches."
                return
            }
            memberModel.append({
                host: targetHost,
                vtpMode: memberModel.count === 0 ? "server" : "client",
                pruning: false
            })
        } else if (!selected && index >= 0) {
            memberModel.remove(index)
        }
        errorText = ""
    }

    function memberPayload() {
        const members = []
        for (let i = 0; i < memberModel.count; i++) {
            const row = memberModel.get(i)
            members.push({
                host: row.host,
                mode: row.vtpMode,
                pruning: row.pruning
            })
        }
        return members
    }

    function resetDraft() {
        memberModel.clear()
        domainField.clear()
        descriptionField.clear()
        versionCombo.currentIndex = 1
        errorText = ""
    }

    function saveGroup(pushAfterSave) {
        errorText = ""
        if (memberModel.count < 2) {
            errorText = "Select at least two connected switches."
            return
        }
        const result = dbManager.saveVtpGroup({
            domain_name: domainField.text.trim(),
            version: Number(versionCombo.currentValue),
            description: descriptionField.text.trim(),
            members: memberPayload()
        })
        const severity = result.ok ? "success" : (result.partial ? "warning" : "error")
        notify(String(result.message || ""), severity)
        if (!result.ok && !result.partial) {
            errorText = String(result.message || "Could not save VTP Group.")
            return
        }
        loadGroups()
        if (pushAfterSave)
            batchDialog.openPreview(result.successful || [], "vtp")
    }

    Component.onCompleted: reloadData("initial")

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacing16
        spacing: Theme.spacing12

        WorkspaceHeader {
            Layout.fillWidth: true
            title: "VTP Group"
            subtitle: "Stage one VTP domain for two to five connected switches."

            StandardButton {
                text: "Refresh"
                icon.source: AppAssets.actionRefresh
                type: "Secondary"
                onClicked: root.reloadData("manual")
            }
        }

        InlineMessage {
            Layout.fillWidth: true
            visible: root.errorText !== ""
            message: root.errorText
            severity: "warning"
        }

        SplitView {
            id: workspaceSplit
            Layout.fillWidth: true
            Layout.fillHeight: true
            orientation: root.compactLayout ? Qt.Vertical : Qt.Horizontal
            handle: StandardSplitHandle { orientation: workspaceSplit.orientation }

            ScrollView {
                SplitView.fillWidth: !root.compactLayout
                SplitView.fillHeight: root.compactLayout
                SplitView.minimumWidth: root.compactLayout ? 0 : 520
                SplitView.minimumHeight: root.compactLayout ? 300 : 0
                clip: true

                ColumnLayout {
                    width: parent.width
                    spacing: Theme.spacing12

                    FormSection {
                        Layout.fillWidth: true
                        title: "Domain settings"

                        Text {
                            Layout.fillWidth: true
                            text: "Authentication and VTPv3 primary/MST activation remain outside this non-interactive workflow."
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            wrapMode: Text.WordWrap
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: width < 660 ? 1 : 2
                            columnSpacing: Theme.spacing12
                            rowSpacing: Theme.spacing8

                            StandardTextField {
                                id: domainField
                                Layout.fillWidth: true
                                labelText: "Domain name"
                                placeholderText: "e.g. CAMPUS"
                            }
                            StandardComboBox {
                                id: versionCombo
                                Layout.fillWidth: true
                                labelText: "VTP version"
                                model: ["Version 1", "Version 2", "Version 3"]
                                valueModel: [1, 2, 3]
                                currentIndex: 1
                            }
                            StandardTextField {
                                id: descriptionField
                                Layout.fillWidth: true
                                Layout.columnSpan: width < 660 ? 1 : 2
                                labelText: "Description"
                                placeholderText: "Optional group description"
                            }
                        }
                    }

                    FormSection {
                        Layout.fillWidth: true
                        title: "Participating switches"

                        Text {
                            Layout.fillWidth: true
                            text: "Select at least two switches; no more than five are pushed in one batch."
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            wrapMode: Text.WordWrap
                        }

                        GridLayout {
                            objectName: "vtpHostPicker"
                            Layout.fillWidth: true
                            columns: width < 660 ? 1 : 2
                            columnSpacing: Theme.spacing8
                            rowSpacing: Theme.spacing8

                            Repeater {
                                model: root.hostOptions
                                delegate: Rectangle {
                                    id: hostCard
                                    required property var modelData
                                    readonly property bool selected: root.findMemberIndex(
                                                                         modelData.host) >= 0
                                    Layout.fillWidth: true
                                    implicitHeight: 62
                                    radius: Theme.radiusSmall
                                    color: selected ? Theme.alertInfoSubtle
                                                    : Theme.contentBackground
                                    border.color: selected ? Theme.accentColor
                                                           : Theme.contentPanelBorder
                                    border.width: Theme.borderWidth

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: Theme.spacing8
                                        spacing: Theme.spacing8
                                        StandardCheckBox {
                                            checked: hostCard.selected
                                            onToggled: root.toggleHost(
                                                           hostCard.modelData.host, checked)
                                        }
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: Theme.spacing2
                                            Text {
                                                Layout.fillWidth: true
                                                text: hostCard.modelData.device_name || "Switch"
                                                color: Theme.textPrimary
                                                font.family: Theme.fontFamily
                                                font.bold: true
                                                elide: Text.ElideRight
                                            }
                                            Text {
                                                Layout.fillWidth: true
                                                text: hostCard.modelData.host
                                                color: Theme.textSecondary
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSizeSmall
                                                elide: Text.ElideRight
                                            }
                                        }
                                        Rectangle {
                                            Layout.preferredWidth: 8
                                            Layout.preferredHeight: 8
                                            radius: 4
                                            color: Theme.statusConnected
                                        }
                                    }
                                }
                            }
                        }
                    }

                    FormSection {
                        Layout.fillWidth: true
                        title: "Member policy"

                        EmptyState {
                            visible: memberModel.count === 0
                            Layout.fillWidth: true
                            Layout.preferredHeight: 96
                            title: "Select switches to configure their VTP mode"
                            emphasized: false
                        }

                        Repeater {
                            model: memberModel
                            delegate: Rectangle {
                                id: memberCard
                                required property int index
                                required property string host
                                required property string vtpMode
                                required property bool pruning
                                Layout.fillWidth: true
                                implicitHeight: 88
                                radius: Theme.radiusSmall
                                color: Theme.contentPanelSurface
                                border.color: Theme.contentPanelBorder
                                border.width: Theme.borderWidth

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: Theme.spacing12
                                    spacing: Theme.spacing12
                                    Text {
                                        Layout.fillWidth: true
                                        text: memberCard.host
                                        color: Theme.textPrimary
                                        font.family: Theme.fontFamily
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }
                                    StandardComboBox {
                                        Layout.preferredWidth: 180
                                        labelText: "VLAN database mode"
                                        model: ["server", "client", "transparent", "off"]
                                        currentIndex: Math.max(0, model.indexOf(memberCard.vtpMode))
                                        onActivated: index => memberModel.setProperty(
                                                         memberCard.index, "vtpMode", model[index])
                                    }
                                    StandardCheckBox {
                                        text: "Pruning"
                                        checked: memberCard.pruning
                                        onToggled: memberModel.setProperty(
                                                       memberCard.index, "pruning", checked)
                                    }
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            Layout.fillWidth: true
                            text: memberModel.count < 2
                                  ? "Select at least two switches"
                                  : "Ready to save " + memberModel.count + " members"
                            color: memberModel.count >= 2 ? Theme.statusConnected
                                                          : Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                        }
                        StandardButton {
                            text: "Reset"
                            type: "Text"
                            onClicked: root.resetDraft()
                        }
                        StandardButton {
                            text: "Save"
                            icon.source: AppAssets.actionSave
                            type: "Secondary"
                            enabled: root.readyToSave
                            onClicked: root.saveGroup(false)
                        }
                        StandardButton {
                            text: "Save & Push"
                            icon.source: AppAssets.actionSave
                            type: "Primary"
                            enabled: root.readyToSave
                            onClicked: root.saveGroup(true)
                        }
                    }
                }
            }

            Rectangle {
                SplitView.fillWidth: root.compactLayout
                SplitView.fillHeight: !root.compactLayout
                SplitView.preferredWidth: root.compactLayout
                                          ? workspaceSplit.width
                                          : workspaceSplit.width * 0.32
                SplitView.minimumWidth: root.compactLayout ? 0 : 320
                SplitView.minimumHeight: root.compactLayout ? 200 : 0
                color: Theme.contentSurface
                radius: Theme.radiusSmall
                border.color: Theme.contentPanelBorder
                border.width: Theme.borderWidth

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacing12
                    spacing: Theme.spacing8
                    Text {
                        text: "Saved domains"
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLarge
                        font.bold: true
                    }
                    Text {
                        text: groupModel.count + " domain(s)"
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                    }
                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: Theme.spacing8
                        model: groupModel
                        delegate: Rectangle {
                            required property string domain_name
                            required property int version
                            required property var members
                            width: ListView.view.width
                            height: 72
                            radius: Theme.radiusSmall
                            color: Theme.contentPanelSurface
                            border.color: Theme.contentPanelBorder
                            border.width: Theme.borderWidth
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: Theme.spacing8
                                spacing: Theme.spacing2
                                Text {
                                    Layout.fillWidth: true
                                    text: domain_name
                                    color: Theme.textPrimary
                                    font.family: Theme.fontFamily
                                    font.bold: true
                                    elide: Text.ElideRight
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: "Version " + version + " · "
                                          + (members ? members.length : 0) + " switch(es)"
                                    color: Theme.textSecondary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                }
                            }
                        }
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                    }
                }
            }
        }
    }

    MultiHostViewPushDialog {
        id: batchDialog
        parent: Overlay.overlay
        controllerName: "switching"
        featureLabel: "VTP"
        ownerForm: root
    }
}
