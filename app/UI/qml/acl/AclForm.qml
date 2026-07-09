pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

Rectangle {
    id: aclForm
    color: Theme.contentBackground

    property string currentHostIp: ""
    property string currentAclType: "Standard"

    property bool hasPendingRules: ruleModel.count > 0
    property string lastError: ""
    property var savedAcls: []
    property var routerInterfaces: []
    property var interfaceIds: []
    property int selectedAclId: 0
    property string loadedDescription: ""
    property string loadedRulesSignature: ""
    property string loadedBindingSignature: ""

    ListModel { id: ruleModel }
    ListModel { id: savedAclModel }

    function isEditing() {
        return selectedAclId > 0
    }

    function normalizeType(typeName) {
        return String(typeName || "").toLowerCase()
    }

    function titleAction(action) {
        const value = String(action || "permit").toLowerCase()
        return value === "deny" ? "Deny" : "Permit"
    }

    function currentActionText() {
        return actionCombo.currentIndex === 1 ? "Deny" : "Permit"
    }

    function ifaceNameFromId(ifaceId) {
        if (ifaceId <= 0)
            return "None"

        for (let i = 0; i < routerInterfaces.length; ++i) {
            const iface = routerInterfaces[i]
            if ((iface.iface_id || 0) === ifaceId)
                return iface.interface_name || "Interface #%1".arg(ifaceId)
        }
        return "Interface #%1".arg(ifaceId)
    }

    function currentIfaceId() {
        if (interfaceCombo.currentIndex <= 0)
            return 0
        return interfaceIds[interfaceCombo.currentIndex - 1] || 0
    }

    function loadRouterInterfaces() {
        routerInterfaces = []
        interfaceIds = []
        const labels = ["None"]

        if (currentHostIp !== "" && typeof dbManager !== "undefined") {
            routerInterfaces = dbManager.getRouterInterfaces(currentHostIp)
            for (let i = 0; i < routerInterfaces.length; ++i) {
                const iface = routerInterfaces[i]
                interfaceIds.push(iface.iface_id || 0)
                labels.push(iface.interface_name || "Interface #%1".arg(iface.iface_id))
            }
        }

        interfaceCombo.model = labels
        interfaceCombo.currentIndex = 0
    }

    function bindingLabel(acl) {
        const bindings = acl.bindings || []
        if (bindings.length === 0)
            return "Not applied"

        const binding = bindings[0]
        const ifaceName = binding.interface_name || ifaceNameFromId(binding.iface_id || 0)
        const direction = String(binding.direction || "in").toUpperCase()
        return ifaceName + " / " + direction
    }

    function refreshSavedAcls() {
        savedAclModel.clear()
        savedAcls = []

        if (currentHostIp === "" || typeof dbManager === "undefined")
            return

        savedAcls = dbManager.getAcls(currentHostIp, currentAclType)
        for (let i = 0; i < savedAcls.length; ++i) {
            const acl = savedAcls[i]
            savedAclModel.append({
                aclId: acl.Acl_id || 0,
                aclName: acl.acl_name || "",
                description: acl.description || "",
                ruleCount: acl.rules ? acl.rules.length : 0,
                bindingText: bindingLabel(acl)
            })
        }
    }

    function selectSavedAclByName(aclName) {
        const normalizedName = String(aclName || "").trim()
        for (let i = 0; i < savedAcls.length; ++i) {
            const acl = savedAcls[i]
            if (String(acl.acl_name || "").trim() === normalizedName) {
                selectedAclId = acl.Acl_id || 0
                return
            }
        }
    }

    function detailFromRule(rule, typeName) {
        const type = normalizeType(typeName)
        if (type === "standard") {
            const src = rule.source || "any"
            return "src: " + src + (rule.wildcard ? " / " + rule.wildcard : "")
        }
        if (type === "mac") {
            let srcPart = rule.src_mac || "any"
            if (rule.src_mask) srcPart += "/" + rule.src_mask
            let dstPart = rule.dst_mac || "any"
            if (rule.dst_mask) dstPart += "/" + rule.dst_mask
            return "MAC  " + srcPart + "  ->  " + dstPart + (rule.ethertype ? "  ethertype: " + rule.ethertype : "")
        }

        let src = rule.source || "any"
        if (rule.src_wildcard) src += "/" + rule.src_wildcard
        if (rule.src_port) src += ":" + rule.src_port
        let dst = rule.destination || "any"
        if (rule.dst_wildcard) dst += "/" + rule.dst_wildcard
        if (rule.dst_port) dst += ":" + rule.dst_port

        let detail = String(rule.protocol || "ip").toUpperCase() + "  " + src + "  ->  " + dst
        if (type === "dynamic" && rule.dynamic_name)
            detail += "  |  dynamic: " + rule.dynamic_name
        if (type === "reflexive" && rule.reflect_name)
            detail += "  |  reflect: " + rule.reflect_name
        if ((type === "dynamic" || type === "reflexive") && rule.timeout_seconds)
            detail += "  timeout: " + rule.timeout_seconds + "s"
        return detail
    }

    function clearRuleInputs() {
        sequenceField.text = ""
        standardInput.clearFields()
        extendedInput.clearFields()
        dynamicInput.clearFields()
        reflexiveInput.clearFields()
        macInput.clearFields()
    }

    function clearRulesOnly() {
        ruleModel.clear()
        clearRuleInputs()
        lastError = ""
        loadedRulesSignature = ""
    }

    function clearEditor() {
        selectedAclId = 0
        aclNameField.text = ""
        descriptionField.text = ""
        hostField.text = currentHostIp
        interfaceCombo.currentIndex = 0
        directionCombo.currentIndex = 0
        loadedDescription = ""
        loadedRulesSignature = ""
        loadedBindingSignature = ""
        clearRulesOnly()
    }

    function clearAllRules() {
        clearEditor()
    }

    function loadAcl(index) {
        if (index < 0 || index >= savedAcls.length)
            return

        const acl = savedAcls[index]
        selectedAclId = acl.Acl_id || 0
        aclNameField.text = acl.acl_name || ""
        descriptionField.text = acl.description || ""
        hostField.text = currentHostIp
        loadedDescription = descriptionField.text
        ruleModel.clear()
        clearRuleInputs()

        const rules = acl.rules || []
        for (let i = 0; i < rules.length; ++i) {
            const rule = rules[i]
            ruleModel.append({
                ruleSequence: rule.sequence || ((i + 1) * 10),
                ruleAction: titleAction(rule.action),
                ruleDetail: detailFromRule(rule, currentAclType),
                ruleAclType: currentAclType,
                ruleData: rule
            })
        }
        loadedRulesSignature = rulesSignature()

        interfaceCombo.currentIndex = 0
        directionCombo.currentIndex = 0
        const bindings = acl.bindings || []
        if (bindings.length > 0) {
            const ifaceId = bindings[0].iface_id || 0
            for (let j = 0; j < interfaceIds.length; ++j) {
                if (interfaceIds[j] === ifaceId)
                    interfaceCombo.currentIndex = j + 1
            }
            directionCombo.currentIndex = String(bindings[0].direction || "in").toLowerCase() === "out" ? 1 : 0
        }
        loadedBindingSignature = bindingSignature()
        lastError = ""
    }

    function deleteSavedAcl(aclId) {
        if (aclId <= 0 || typeof dbManager === "undefined")
            return

        if (!dbManager.deleteAcl(aclId)) {
            lastError = "Delete ACL failed."
            return
        }

        if (selectedAclId === aclId)
            clearEditor()

        refreshSavedAcls()
        if (typeof statusBar !== "undefined")
            statusBar.showMessage("ACL deleted.", "info")
    }

    function rulesSignature() {
        const rows = []
        for (let i = 0; i < ruleModel.count; ++i) {
            const row = ruleModel.get(i)
            rows.push({
                sequence: row.ruleSequence,
                action: String(row.ruleAction).toLowerCase(),
                detail: row.ruleDetail
            })
        }
        return JSON.stringify(rows)
    }

    function bindingSignature() {
        return JSON.stringify({
            iface_id: currentIfaceId(),
            direction: directionCombo.currentValue
        })
    }

    function activeRuleInput() {
        if (currentAclType === "Standard")  return standardInput
        if (currentAclType === "Extended")  return extendedInput
        if (currentAclType === "Dynamic")   return dynamicInput
        if (currentAclType === "Reflexive") return reflexiveInput
        if (currentAclType === "MAC")       return macInput
        return null
    }

    function validateBeforeAdd() {
        const aclName = aclNameField.text.trim()
        if (aclName === "") {
            lastError = "ACL Name is required."
            return false
        }

        const host = hostField.text.trim()
        if (host === "") {
            lastError = "Select a device before creating an ACL."
            return false
        }

        const seq = sequenceField.text.trim()
        if (seq !== "") {
            const seqNum = parseInt(seq, 10)
            if (isNaN(seqNum) || seqNum < 1 || seqNum > 65535) {
                lastError = "Sequence must be an integer between 1 and 65535."
                return false
            }
        }

        lastError = ""
        return true
    }

    function addRule() {
        if (!validateBeforeAdd())
            return

        const input = activeRuleInput()
        if (!input)
            return

        const seq = sequenceField.text.trim()
        const action = currentActionText()
        const detail = input.buildDetail()
        const ruleData = input.buildRule()
        ruleData.sequence = seq !== "" ? parseInt(seq, 10) : ruleModel.count + 10
        ruleData.action = action.toLowerCase()

        ruleModel.append({
            ruleSequence: ruleData.sequence,
            ruleAction: action,
            ruleDetail: detail,
            ruleAclType: currentAclType,
            ruleData: ruleData
        })

        sequenceField.text = ""
        input.clearFields()
    }

    function removeRule(index) {
        if (index >= 0 && index < ruleModel.count)
            ruleModel.remove(index)
    }

    function saveAcl() {
        if (ruleModel.count === 0) {
            lastError = "No rules to save. Add at least one rule."
            return
        }

        const aclName = aclNameField.text.trim()
        if (aclName === "") {
            lastError = "ACL Name is required before saving."
            return
        }

        const host = hostField.text.trim()
        if (host === "") {
            lastError = "Select a device before saving."
            return
        }

        const rules = []
        for (let i = 0; i < ruleModel.count; ++i) {
            const row = ruleModel.get(i)
            let data = row.ruleData || {}
            data.sequence = row.ruleSequence
            data.action = String(row.ruleAction).toLowerCase()
            rules.push(data)
        }

        const currentRulesSignature = rulesSignature()
        const currentBindingSignature = bindingSignature()
        const payload = {
            acl_id: selectedAclId,
            host: host,
            acl_name: aclName,
            acl_type: currentAclType,
            description: descriptionField.text.trim(),
            description_only: selectedAclId > 0 &&
                              loadedDescription !== descriptionField.text.trim() &&
                              loadedRulesSignature === currentRulesSignature &&
                              loadedBindingSignature === currentBindingSignature,
            rules: rules,
            binding: {
                iface_id: currentIfaceId(),
                direction: directionCombo.currentValue
            }
        }

        if (typeof dbManager === "undefined" || !dbManager.saveAcl(payload)) {
            lastError = "Save ACL failed. Check console output for database details."
            return
        }

        refreshSavedAcls()
        selectSavedAclByName(aclName)
        loadedDescription = descriptionField.text.trim()
        loadedRulesSignature = currentRulesSignature
        loadedBindingSignature = currentBindingSignature
        if (typeof statusBar !== "undefined")
            statusBar.showMessage(
                "ACL \"" + aclName + "\" saved with " + ruleModel.count + " rule(s).",
                "info"
            )

        lastError = ""
    }

    onCurrentAclTypeChanged: {
        clearEditor()
        refreshSavedAcls()
    }

    onCurrentHostIpChanged: {
        hostField.text = aclForm.currentHostIp
        loadRouterInterfaces()
        clearEditor()
        refreshSavedAcls()
    }

    Component.onCompleted: {
        hostField.text = aclForm.currentHostIp
        loadRouterInterfaces()
        refreshSavedAcls()
    }

    SplitView {
        anchors.fill: parent
        orientation: Qt.Horizontal
        handle: StandardSplitHandle {}

        SplitFormPane {
            SplitView.preferredWidth: aclForm.width >= 1080 ? 440 : 400
            SplitView.minimumWidth: 360

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacing8

                Text {
                    Layout.fillWidth: true
                    text: aclForm.isEditing() ? "Edit ACL" : "Create ACL"
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSizeLarge
                    font.family: Theme.fontFamily
                    font.bold: true
                    elide: Text.ElideRight
                }

                StandardBadge {
                    text: aclForm.currentAclType
                    badgeColor: Theme.accentEmphasis
                    textColor: Theme.buttonTextSolid
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: Theme.borderWidth
                color: Theme.splitHandleColor
            }

            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: availableWidth
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                ColumnLayout {
                    width: parent.width
                    spacing: Theme.spacing12

                    StandardTextField {
                        id: aclNameField
                        Layout.fillWidth: true
                        labelText: "ACL Name *"
                        placeholderText: "e.g., ACL_INBOUND"
                    }

                    StandardTextField {
                        id: hostField
                        Layout.fillWidth: true
                        labelText: "Host"
                        placeholderText: "Select a device first"
                        readOnly: true
                    }

                    StandardTextField {
                        id: descriptionField
                        Layout.fillWidth: true
                        labelText: "Description"
                        placeholderText: "e.g., Block untrusted inbound traffic"
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacing12

                        StandardComboBox {
                            id: interfaceCombo
                            Layout.fillWidth: true
                            labelText: "Apply to Interface"
                            model: ["None"]
                        }

                        StandardComboBox {
                            id: directionCombo
                            Layout.preferredWidth: 116
                            labelText: "Direction"
                            model: ["In", "Out"]
                            valueModel: ["in", "out"]
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: Theme.borderWidth
                        color: Theme.splitHandleColor
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Rule Builder"
                        color: Theme.textPrimary
                        font.pixelSize: Theme.fontSizeNormal
                        font.family: Theme.fontFamily
                        font.bold: true
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacing12

                        StandardTextField {
                            id: sequenceField
                            Layout.preferredWidth: 128
                            labelText: "Sequence"
                            placeholderText: "e.g., 10"
                            validator: IntValidator { bottom: 1; top: 65535 }
                        }

                        StandardComboBox {
                            id: actionCombo
                            Layout.fillWidth: true
                            labelText: "Action"
                            model: ["Permit", "Deny"]
                            contentColor: currentIndex === 0 ? Theme.statusConnected : Theme.alertError
                            contentBold: true
                        }
                    }

                    AclRuleInputStandard {
                        id: standardInput
                        Layout.fillWidth: true
                        visible: aclForm.currentAclType === "Standard"
                    }

                    AclRuleInputExtended {
                        id: extendedInput
                        Layout.fillWidth: true
                        visible: aclForm.currentAclType === "Extended"
                    }

                    AclRuleInputDynamic {
                        id: dynamicInput
                        Layout.fillWidth: true
                        visible: aclForm.currentAclType === "Dynamic"
                    }

                    AclRuleInputReflexive {
                        id: reflexiveInput
                        Layout.fillWidth: true
                        visible: aclForm.currentAclType === "Reflexive"
                    }

                    AclRuleInputMac {
                        id: macInput
                        Layout.fillWidth: true
                        visible: aclForm.currentAclType === "MAC"
                    }

                    Text {
                        visible: aclForm.lastError !== ""
                        Layout.fillWidth: true
                        text: aclForm.lastError
                        color: Theme.alertError
                        font.pixelSize: Theme.fontSizeSmall
                        font.family: Theme.fontFamily
                        wrapMode: Text.WordWrap
                    }

                    StandardButton {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        text: "+ Add Rule"
                        type: "Primary"
                        enabled: aclNameField.text.trim() !== "" &&
                                 hostField.text.trim() !== ""
                        onClicked: aclForm.addRule()
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: Theme.borderWidth
                color: Theme.splitHandleColor
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacing8

                StandardButton {
                    Layout.preferredWidth: 72
                    Layout.preferredHeight: 36
                    text: "New"
                    type: "Secondary"
                    onClicked: aclForm.clearEditor()
                }

                StandardButton {
                    Layout.preferredWidth: 104
                    Layout.preferredHeight: 36
                    text: "Clear Rules"
                    type: "Secondary"
                    enabled: ruleModel.count > 0
                    onClicked: aclForm.clearRulesOnly()
                }

                StandardButton {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    text: aclForm.isEditing() ? "Save Changes" : "Save ACL"
                    type: "Primary"
                    enabled: ruleModel.count > 0 &&
                             aclNameField.text.trim() !== "" &&
                             hostField.text.trim() !== ""
                    onClicked: aclForm.saveAcl()
                }
            }
        }

        Item {
            SplitView.fillWidth: true
            SplitView.minimumWidth: 360

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                SavedListPanel {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.max(210, aclForm.height * 0.38)
                    title: "Saved ACLs"
                    count: savedAclModel.count
                    countColor: Theme.accentColor
                    emptyText: "No saved ACLs for this host and type.\nCreate one using the form on the left."
                    headerComponent: Component {
                        SavedListHeader {
                            width: parent ? parent.width : 0

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 68
                                spacing: Theme.spacing8

                                Text {
                                    Layout.preferredWidth: 34
                                    text: "#"
                                    color: Theme.textSecondary
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.family: Theme.fontFamily
                                    font.bold: true
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: "ACL"
                                    color: Theme.textSecondary
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.family: Theme.fontFamily
                                    font.bold: true
                                }

                                Text {
                                    Layout.preferredWidth: 76
                                    text: "Rules"
                                    color: Theme.textSecondary
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.family: Theme.fontFamily
                                    font.bold: true
                                    horizontalAlignment: Text.AlignRight
                                }

                                Text {
                                    Layout.preferredWidth: 124
                                    text: "Binding"
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
                        model: savedAclModel
                        clip: true
                        spacing: 2
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                        delegate: SavedListRow {
                            required property int index
                            required property int aclId
                            required property string aclName
                            required property string description
                            required property int ruleCount
                            required property string bindingText

                            rowIndex: index
                            height: description !== "" ? 48 : 36
                            baseColor: aclForm.selectedAclId === aclId
                                       ? Qt.rgba(Theme.accentColor.r, Theme.accentColor.g, Theme.accentColor.b, 0.14)
                                       : (zebra && index % 2 !== 0 ? Theme.sideBarBackground : Theme.contentSurface)
                            width: ListView.view ? ListView.view.width : 0

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 8
                                spacing: Theme.spacing8

                                Text {
                                    Layout.preferredWidth: 34
                                    text: index + 1
                                    color: Theme.textDisabled
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.family: Theme.fontFamily
                                    verticalAlignment: Text.AlignVCenter
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0

                                    Text {
                                        Layout.fillWidth: true
                                        text: aclName
                                        color: Theme.textPrimary
                                        font.pixelSize: Theme.fontSizeNormal
                                        font.family: Theme.fontFamily
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        visible: description !== ""
                                        Layout.fillWidth: true
                                        text: description
                                        color: Theme.textDisabled
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.family: Theme.fontFamily
                                        elide: Text.ElideRight
                                    }
                                }

                                Text {
                                    Layout.preferredWidth: 76
                                    text: ruleCount + " rule(s)"
                                    color: Theme.textSecondary
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.family: Theme.fontFamily
                                    horizontalAlignment: Text.AlignRight
                                    verticalAlignment: Text.AlignVCenter
                                }

                                Text {
                                    Layout.preferredWidth: 124
                                    text: bindingText
                                    color: Theme.textSecondary
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.family: Theme.fontFamily
                                    elide: Text.ElideRight
                                    verticalAlignment: Text.AlignVCenter
                                }

                                Row {
                                    Layout.preferredWidth: 56
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 4

                                    IconButton {
                                        buttonSize: 24
                                        iconSize: 12
                                        glyph: "E"
                                        tooltip: "Load ACL"
                                        onClicked: aclForm.loadAcl(index)
                                    }

                                    IconButton {
                                        buttonSize: 24
                                        iconSize: 11
                                        glyph: "X"
                                        danger: true
                                        tooltip: "Delete ACL"
                                        onClicked: aclForm.deleteSavedAcl(aclId)
                                    }
                                }
                            }
                        }
                    }
                }

                SavedListPanel {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    title: aclForm.isEditing() ? "Rules in Selected ACL" : "Pending Rules"
                    count: ruleModel.count
                    countColor: aclForm.hasPendingRules ? Theme.accentColor : Theme.textDisabled
                    emptyText: "No rules in the editor yet.\nAdd rules from the builder on the left."
                    headerComponent: Component {
                        SavedListHeader {
                            width: parent ? parent.width : 0

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 40
                                spacing: Theme.spacing8

                                Text {
                                    Layout.preferredWidth: 44
                                    text: "Seq"
                                    color: Theme.textSecondary
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.family: Theme.fontFamily
                                    font.bold: true
                                    horizontalAlignment: Text.AlignHCenter
                                }

                                Text {
                                    Layout.preferredWidth: 70
                                    text: "Action"
                                    color: Theme.textSecondary
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.family: Theme.fontFamily
                                    font.bold: true
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: "Detail"
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
                        model: ruleModel
                        clip: true
                        spacing: 2
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                        delegate: AclRuleRow {
                            required property int index
                            required property int ruleSequence
                            required property string ruleAction
                            required property string ruleDetail
                            required property string ruleAclType

                            width: ListView.view ? ListView.view.width : 0
                            rowIndex: index
                            rowSequence: ruleSequence
                            rowAction: ruleAction
                            rowDetail: ruleDetail
                            rowAclType: ruleAclType

                            onDeleteClicked: (idx) => aclForm.removeRule(idx)
                        }
                    }
                }
            }
        }
    }
}
