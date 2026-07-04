pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import NetworkTools

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
    property bool initialized: false

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

    function targetHost() {
        const typedHost = hostField.text.trim()
        return typedHost !== "" ? typedHost : currentHostIp
    }

    function currentIfaceId() {
        if (interfaceCombo.currentIndex <= 0)
            return 0
        return interfaceIds[interfaceCombo.currentIndex - 1] || 0
    }

    function clearRuleInputs() {
        standardInput.clearFields()
        extendedInput.clearFields()
        dynamicInput.clearFields()
        reflexiveInput.clearFields()
        macInput.clearFields()
    }

    function clearAllRules() {
        ruleModel.clear()
        selectedAclId = 0
        loadedRulesSignature = ""
        loadedBindingSignature = ""
        lastError = ""
    }

    function clearDraft() {
        clearAllRules()
        aclNameField.text = ""
        descriptionField.text = ""
        loadedDescription = ""
        hostField.text = currentHostIp
        sequenceField.text = ""
        actionCombo.currentIndex = 0
        interfaceCombo.currentIndex = 0
        directionCombo.currentIndex = 0
        clearRuleInputs()
    }

    function bindingLabel(bindings) {
        if (!bindings || bindings.length === 0)
            return "Unbound"

        const binding = bindings[0]
        const ifaceName = binding.interface_name || ("Interface #" + binding.iface_id)
        const direction = String(binding.direction || "").toUpperCase()
        return direction !== "" ? ifaceName + " " + direction : ifaceName
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
                labels.push(iface.interface_name || ("Interface #" + iface.iface_id))
            }
        }
        interfaceCombo.model = labels
        interfaceCombo.currentIndex = 0
    }

    function refreshSavedAcls() {
        savedAclModel.clear()
        savedAcls = []
        if (currentHostIp === "" || typeof dbManager === "undefined")
            return

        savedAcls = dbManager.getAcls(currentHostIp, currentAclType)
        for (let i = 0; i < savedAcls.length; ++i) {
            const acl = savedAcls[i]
            const rules = acl.rules || []
            const bindings = acl.bindings || []
            savedAclModel.append({
                aclId: acl.Acl_id || 0,
                aclName: acl.acl_name || "",
                ruleCount: rules.length,
                bindingText: bindingLabel(bindings),
                descriptionText: acl.description || ""
            })
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

    function loadAcl(index) {
        if (index < 0 || index >= savedAcls.length)
            return

        const acl = savedAcls[index]
        selectedAclId = acl.Acl_id || 0
        aclNameField.text = acl.acl_name || ""
        descriptionField.text = acl.description || ""
        hostField.text = acl.host || currentHostIp
        loadedDescription = descriptionField.text
        ruleModel.clear()

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
        sequenceField.text = ""
        actionCombo.currentIndex = 0
        clearRuleInputs()
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
            clearDraft()
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
            direction: String(directionCombo.currentText || "in").toLowerCase()
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

    function nextRuleSequence() {
        let maxSequence = 0
        for (let i = 0; i < ruleModel.count; ++i)
            maxSequence = Math.max(maxSequence, ruleModel.get(i).ruleSequence || 0)
        return maxSequence + 10
    }

    function validateBeforeAdd() {
        if (targetHost() === "") {
            lastError = "Select a host before adding ACL rules."
            return false
        }

        const aclName = aclNameField.text.trim()
        if (aclName === "") {
            lastError = "ACL Name is required."
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
        const action = actionCombo.currentText
        const ruleData = input.buildRule()
        ruleData.sequence = seq !== "" ? parseInt(seq, 10) : nextRuleSequence()
        ruleData.action = action.toLowerCase()

        ruleModel.append({
            ruleSequence: ruleData.sequence,
            ruleAction: action,
            ruleDetail: input.buildDetail(),
            ruleAclType: currentAclType,
            ruleData: ruleData
        })

        sequenceField.text = ""
        input.clearFields()
        lastError = ""
    }

    function removeRule(index) {
        if (index >= 0 && index < ruleModel.count) {
            ruleModel.remove(index)
            selectedAclId = 0
            loadedRulesSignature = ""
            loadedBindingSignature = ""
        }
    }

    function syncSelectedAfterSave(aclName) {
        selectedAclId = 0
        for (let i = 0; i < savedAcls.length; ++i) {
            const acl = savedAcls[i]
            if (String(acl.acl_name || "") === aclName) {
                selectedAclId = acl.Acl_id || 0
                return
            }
        }
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

        const host = targetHost()
        if (host === "") {
            lastError = "Host is required before saving."
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
                direction: String(directionCombo.currentText || "in").toLowerCase()
            }
        }

        if (typeof dbManager === "undefined" || !dbManager.saveAcl(payload)) {
            lastError = "Save ACL failed. Check application logs for database details."
            return
        }

        refreshSavedAcls()
        syncSelectedAfterSave(aclName)
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
        if (!initialized)
            return
        clearDraft()
        refreshSavedAcls()
    }

    onCurrentHostIpChanged: {
        if (!initialized)
            return
        loadRouterInterfaces()
        clearDraft()
        refreshSavedAcls()
    }

    Component.onCompleted: {
        initialized = true
        hostField.text = currentHostIp
        loadRouterInterfaces()
        refreshSavedAcls()
    }

    SplitView {
        anchors.fill: parent
        orientation: Qt.Horizontal
        handle: StandardSplitHandle {}

        SplitFormPane {
            SplitView.preferredWidth: 440
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
                id: formScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: availableWidth
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                ColumnLayout {
                    width: formScroll.availableWidth
                    spacing: Theme.spacing12

                    Text {
                        Layout.fillWidth: true
                        text: "General"
                        color: Theme.textSecondary
                        font.pixelSize: Theme.fontSizeSmall
                        font.family: Theme.fontFamily
                        font.bold: true
                        font.capitalization: Font.AllUppercase
                    }

                    StandardTextField {
                        id: aclNameField
                        Layout.fillWidth: true
                        labelText: "ACL Name"
                        placeholderText: "e.g., ACL_INBOUND"
                    }

                    StandardTextField {
                        id: hostField
                        Layout.fillWidth: true
                        labelText: "Host"
                        placeholderText: "e.g., 192.168.1.1"
                        text: aclForm.currentHostIp
                        readOnly: true
                    }

                    StandardTextField {
                        id: descriptionField
                        Layout.fillWidth: true
                        labelText: "Description"
                        placeholderText: "e.g., Block inbound traffic from untrusted network"
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
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.topMargin: Theme.spacing4
                        height: Theme.borderWidth
                        color: Theme.splitHandleColor
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Rule"
                        color: Theme.textSecondary
                        font.pixelSize: Theme.fontSizeSmall
                        font.family: Theme.fontFamily
                        font.bold: true
                        font.capitalization: Font.AllUppercase
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacing12

                        StandardTextField {
                            id: sequenceField
                            Layout.preferredWidth: 124
                            labelText: "Sequence"
                            placeholderText: String(aclForm.nextRuleSequence())
                            validator: IntValidator { bottom: 1; top: 65535 }
                        }

                        StandardComboBox {
                            id: actionCombo
                            Layout.fillWidth: true
                            labelText: "Action"
                            model: ["Permit", "Deny"]
                            contentColor: currentText === "Permit" ? Theme.statusConnected : Theme.alertError
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
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    type: "Primary"
                    text: "Add Rule"
                    enabled: aclNameField.text.trim() !== "" && aclForm.targetHost() !== ""
                    onClicked: aclForm.addRule()
                }

                StandardButton {
                    Layout.preferredWidth: 84
                    Layout.preferredHeight: 36
                    type: "Secondary"
                    text: "Clear"
                    enabled: aclForm.hasPendingRules || aclNameField.text.trim() !== "" || descriptionField.text.trim() !== ""
                    onClicked: aclForm.clearDraft()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacing8

                Text {
                    Layout.fillWidth: true
                    text: aclForm.hasPendingRules
                          ? ruleModel.count + " rule(s) ready to save."
                          : "Add at least one rule before saving."
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontSizeSmall
                    font.family: Theme.fontFamily
                    elide: Text.ElideRight
                }

                StandardButton {
                    Layout.preferredWidth: 116
                    Layout.preferredHeight: 36
                    type: "Primary"
                    text: "Save ACL"
                    enabled: aclForm.hasPendingRules &&
                             aclNameField.text.trim() !== "" &&
                             aclForm.targetHost() !== ""
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
                    Layout.fillHeight: true
                    Layout.preferredHeight: aclForm.height * 0.45
                    title: "Saved ACLs"
                    count: savedAclModel.count
                    countColor: Theme.accentColor
                    emptyText: "No saved ACLs for this host and type.\nCreate one from the form on the left."
                    headerComponent: Component {
                        SavedListHeader {
                            width: parent ? parent.width : 0

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 64
                                spacing: 0

                                Text {
                                    width: 150
                                    text: "ACL Name"
                                    color: Theme.textSecondary
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.family: Theme.fontFamily
                                    font.bold: true
                                }
                                Text {
                                    width: 72
                                    text: "Rules"
                                    color: Theme.textSecondary
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.family: Theme.fontFamily
                                    font.bold: true
                                }
                                Text {
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
                            required property int ruleCount
                            required property string bindingText
                            required property string descriptionText

                            rowIndex: index
                            height: 40
                            baseColor: aclForm.selectedAclId === aclId
                                       ? Qt.rgba(Theme.accentColor.r, Theme.accentColor.g, Theme.accentColor.b, 0.14)
                                       : (zebra && rowIndex % 2 !== 0 ? alternateColor : Theme.contentSurface)

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 8
                                spacing: 0

                                Text {
                                    width: 150
                                    height: parent.height
                                    text: aclName
                                    color: Theme.textPrimary
                                    font.pixelSize: Theme.fontSizeNormal
                                    font.family: Theme.fontFamily
                                    elide: Text.ElideRight
                                    verticalAlignment: Text.AlignVCenter
                                }

                                Text {
                                    width: 72
                                    height: parent.height
                                    text: ruleCount
                                    color: Theme.textSecondary
                                    font.pixelSize: Theme.fontSizeNormal
                                    font.family: Theme.fontFamily
                                    elide: Text.ElideRight
                                    verticalAlignment: Text.AlignVCenter
                                }

                                Text {
                                    width: Math.max(0, parent.width - 150 - 72 - 56)
                                    height: parent.height
                                    text: bindingText
                                    color: Theme.textSecondary
                                    font.pixelSize: Theme.fontSizeNormal
                                    font.family: Theme.fontFamily
                                    elide: Text.ElideRight
                                    verticalAlignment: Text.AlignVCenter
                                }

                                Item {
                                    width: 56
                                    height: parent.height

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 4

                                        IconButton {
                                            buttonSize: 24
                                            iconSize: 12
                                            glyph: "E"
                                            selected: aclForm.selectedAclId === aclId
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
                }

                SavedListPanel {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredHeight: aclForm.height * 0.55
                    title: "Rules in Editor"
                    count: ruleModel.count
                    countColor: Theme.statusConnected
                    emptyText: "No rules in the editor yet.\nUse the form on the left to add rules."
                    headerComponent: Component {
                        SavedListHeader {
                            width: parent ? parent.width : 0

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 40
                                spacing: 0

                                Text {
                                    width: 48
                                    text: "Seq"
                                    color: Theme.textSecondary
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.family: Theme.fontFamily
                                    font.bold: true
                                }
                                Text {
                                    width: 76
                                    text: "Action"
                                    color: Theme.textSecondary
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.family: Theme.fontFamily
                                    font.bold: true
                                }
                                Text {
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

                        delegate: SavedListRow {
                            required property int index
                            required property int ruleSequence
                            required property string ruleAction
                            required property string ruleDetail

                            rowIndex: index
                            height: 40

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 8
                                spacing: 0

                                Text {
                                    width: 48
                                    height: parent.height
                                    text: String(ruleSequence)
                                    color: Theme.textSecondary
                                    font.pixelSize: Theme.fontSizeNormal
                                    font.family: Theme.fontFamily
                                    elide: Text.ElideRight
                                    verticalAlignment: Text.AlignVCenter
                                }

                                Rectangle {
                                    width: 76
                                    height: parent.height
                                    color: "transparent"

                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left: parent.left
                                        width: actionText.implicitWidth + 16
                                        height: 22
                                        radius: Theme.radiusSmall
                                        color: ruleAction === "Permit"
                                               ? Theme.alertSuccessSubtle
                                               : Qt.rgba(Theme.alertError.r, Theme.alertError.g, Theme.alertError.b, 0.15)

                                        Text {
                                            id: actionText
                                            anchors.centerIn: parent
                                            text: ruleAction
                                            color: ruleAction === "Permit" ? Theme.statusConnected : Theme.alertError
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.family: Theme.fontFamily
                                            font.bold: true
                                        }
                                    }
                                }

                                Text {
                                    width: Math.max(0, parent.width - 48 - 76 - 32)
                                    height: parent.height
                                    text: ruleDetail
                                    color: Theme.textPrimary
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
                                        tooltip: "Delete Rule"
                                        onClicked: aclForm.removeRule(index)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
