pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import NetworkTools

// Bọc toàn bộ form bằng FormLayout
FormLayout {
    id: aclForm

    // Gắn dữ liệu vào Public API của FormLayout
    title: "ACL Configuration (" + currentAclType + ")"
    hostIp: currentHostIp
    isDirty: hasPendingRules
    errorMessage: "" // Lỗi được hiển thị cụ thể ở từng khu vực bên trong

    property string currentHostIp: ""
    property string currentAclType: "Standard"  // Nhận từ AclView khi tab thay đổi

    // ── Trạng thái form ──
    property bool hasPendingRules: ruleModel.count > 0
    property string lastError:     ""
    property var savedAcls: []
    property var routerInterfaces: []
    property var interfaceIds: []
    property int selectedAclId: 0
    property string loadedDescription: ""
    property string loadedRulesSignature: ""
    property string loadedBindingSignature: ""

    // ── Model lưu danh sách rules đang chờ lưu ──
    ListModel { id: ruleModel }
    ListModel { id: savedAclModel }

    // ── Hàm xóa toàn bộ rules khi chuyển ACL type ──
    function clearAllRules() {
        ruleModel.clear()
        lastError = ""
        selectedAclId = 0
        loadedDescription = ""
        loadedRulesSignature = ""
        loadedBindingSignature = ""
    }

    function normalizeType(typeName) {
        return String(typeName || "").toLowerCase()
    }

    function titleAction(action) {
        const value = String(action || "permit").toLowerCase()
        return value === "deny" ? "Deny" : "Permit"
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
            savedAclModel.append({
                aclId: acl.Acl_id || 0,
                aclName: acl.acl_name || "",
                ruleCount: acl.rules ? acl.rules.length : 0
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
            return "MAC  " + srcPart + "  →  " + dstPart + (rule.ethertype ? "  ethertype: " + rule.ethertype : "")
        }

        let src = rule.source || "any"
        if (rule.src_wildcard) src += "/" + rule.src_wildcard
        if (rule.src_port) src += ":" + rule.src_port
        let dst = rule.destination || "any"
        if (rule.dst_wildcard) dst += "/" + rule.dst_wildcard
        if (rule.dst_port) dst += ":" + rule.dst_port

        let detail = String(rule.protocol || "ip").toUpperCase() + "  " + src + "  →  " + dst
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
            clearAllRules()
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
            direction: directionCombo.currentText.toLowerCase()
        })
    }

    // ── Hàm lấy box nhập rule đang hiển thị theo type ──
    function activeRuleInput() {
        if (currentAclType === "Standard")  return standardInput
        if (currentAclType === "Extended")  return extendedInput
        if (currentAclType === "Dynamic")   return dynamicInput
        if (currentAclType === "Reflexive") return reflexiveInput
        if (currentAclType === "MAC")       return macInput
        return null
    }

    // ── Hàm validate trước khi Add Rule ──
    function validateBeforeAdd() {
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

    // ── Hàm thêm rule vào danh sách ──
    function addRule() {
        if (!validateBeforeAdd())
            return

        const input = activeRuleInput()
        if (!input) return

        const seq    = sequenceField.text.trim()
        const action = actionCombo.currentText
        const detail = input.buildDetail()
        const ruleData = input.buildRule()
        ruleData.sequence = seq !== "" ? parseInt(seq, 10) : ruleModel.count + 10
        ruleData.action = action.toLowerCase()

        ruleModel.append({
            ruleSequence: ruleData.sequence,
            ruleAction:   action,
            ruleDetail:   detail,
            ruleAclType:  currentAclType,
            ruleData:     ruleData
        })

        // ── Xóa input rule sau khi thêm thành công ──
        sequenceField.text = ""
        input.clearFields()
    }

    // ── Hàm xóa rule theo index ──
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
            host: hostField.text.trim() !== "" ? hostField.text.trim() : currentHostIp,
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
                direction: directionCombo.currentText.toLowerCase()
            }
        }

        if (typeof dbManager === "undefined" || !dbManager.saveAcl(payload)) {
            lastError = "Save ACL failed. Check application logs for database details."
            return
        }

        refreshSavedAcls()
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

    // ── Reset form khi chuyển ACL type ──
    onCurrentAclTypeChanged: {
        lastError = ""
        clearAllRules()
        refreshSavedAcls()
    }

    onCurrentHostIpChanged: {
        hostField.text = aclForm.currentHostIp
        clearAllRules()
        loadRouterInterfaces()
        refreshSavedAcls()
    }

    Component.onCompleted: {
        loadRouterInterfaces()
        refreshSavedAcls()
    }

    // ── NỘI DUNG CHÍNH (Body chui vào ScrollView) ──
    // KHU VỰC 1 — General Info
    Rectangle {
        Layout.fillWidth:    true
        Layout.leftMargin:   24
        Layout.rightMargin:  24
        Layout.topMargin:    16
        implicitHeight:      generalLayout.implicitHeight + 24
        radius:              Theme.cardRadius
        color:               Theme.contentSurface
        border.color:        Theme.borderColor
        border.width:        Theme.borderWidth

        ColumnLayout {
            id:              generalLayout
            anchors.fill:    parent
            anchors.margins: 12
            spacing:         12

            Text {
                text:                "General Information"
                color:               Theme.textPrimary
                font.pixelSize:      Theme.fontSizeNormal
                font.family:         Theme.fontFamily
                font.bold:           true
            }

            Rectangle {
                Layout.fillWidth: true
                height:           Theme.borderWidth
                color:            Theme.borderColor
                opacity:          0.6
            }

            RowLayout {
                Layout.fillWidth: true
                spacing:          12

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing:          4
                    RowLayout {
                        spacing: 4
                        Text {
                            text:           "ACL Name"
                            color:          Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family:    Theme.fontFamily
                        }
                        Text {
                            text:           "*"
                            color:          Theme.alertError
                            font.pixelSize: Theme.fontSizeSmall
                            font.family:    Theme.fontFamily
                            font.bold:      true
                        }
                    }
                    StandardTextField {
                        id:               aclNameField
                        Layout.fillWidth: true
                        placeholderText:  "e.g., ACL_INBOUND"
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing:          4
                    Text {
                        text:           "Host"
                        color:          Theme.textSecondary
                        font.pixelSize: Theme.fontSizeSmall
                        font.family:    Theme.fontFamily
                    }
                    StandardTextField {
                        id:               hostField
                        Layout.fillWidth: true
                        placeholderText:  "e.g., 192.168.1.1"
                        text:             aclForm.currentHostIp
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing:          4
                Text {
                    text:           "Description"
                    color:          Theme.textSecondary
                    font.pixelSize: Theme.fontSizeSmall
                    font.family:    Theme.fontFamily
                }
                StandardTextField {
                    id:               descriptionField
                    Layout.fillWidth: true
                    placeholderText:  "e.g., Block inbound traffic from untrusted network"
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                StandardComboBox {
                    id: interfaceCombo
                    Layout.fillWidth: true
                    labelText: "Apply to Interface"
                    model: ["None"]
                }

                StandardComboBox {
                    id: directionCombo
                    Layout.preferredWidth: 160
                    labelText: "Direction"
                    model: ["In", "Out"]
                }
            }
        }
    }

    // KHU VỰC 1B — Saved ACLs
    Rectangle {
        Layout.fillWidth:   true
        Layout.leftMargin:  24
        Layout.rightMargin: 24
        implicitHeight:     savedAclLayout.implicitHeight + 24
        radius:             Theme.cardRadius
        color:              Theme.contentSurface
        border.color:       Theme.borderColor
        border.width:       Theme.borderWidth

        ColumnLayout {
            id: savedAclLayout
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "Saved ACLs"
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSizeNormal
                    font.family: Theme.fontFamily
                    font.bold: true
                }

                Rectangle {
                    visible: savedAclModel.count > 0
                    width: savedAclCountText.implicitWidth + 12
                    height: 20
                    radius: 10
                    color: Theme.accentColor
                    Layout.alignment: Qt.AlignVCenter
                    Layout.leftMargin: 8

                    Text {
                        id: savedAclCountText
                        anchors.centerIn: parent
                        text: savedAclModel.count
                        color: Theme.buttonTextSolid
                        font.pixelSize: Theme.fontSizeSmall
                        font.family: Theme.fontFamily
                        font.bold: true
                    }
                }

                Item { Layout.fillWidth: true }

                StandardButton {
                    Layout.preferredHeight: 28
                    type: "Secondary"
                    text: "Refresh"
                    onClicked: aclForm.refreshSavedAcls()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: Theme.borderWidth
                color: Theme.borderColor
                opacity: 0.6
            }

            Text {
                visible: savedAclModel.count === 0
                Layout.fillWidth: true
                text: "No saved ACLs for this host and type."
                color: Theme.textDisabled
                font.pixelSize: Theme.fontSizeSmall
                font.family: Theme.fontFamily
                horizontalAlignment: Text.AlignHCenter
                topPadding: 8
                bottomPadding: 8
            }

            Repeater {
                model: savedAclModel
                delegate: Rectangle {
                    required property int index
                    required property int aclId
                    required property string aclName
                    required property int ruleCount

                    Layout.fillWidth: true
                    height: Theme.itemHeight + 4
                    radius: Theme.borderRadius
                    color: aclForm.selectedAclId === aclId ? Qt.rgba(Theme.accentColor.r, Theme.accentColor.g, Theme.accentColor.b, 0.16)
                                                    : savedAclHover.hovered ? Theme.sideBarItemHover : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8

                        Text {
                            Layout.fillWidth: true
                            text: aclName
                            color: Theme.textPrimary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: Theme.fontFamily
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.preferredWidth: 74
                            text: ruleCount + " rule(s)"
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: Theme.fontFamily
                            horizontalAlignment: Text.AlignRight
                        }

                        StandardButton {
                            Layout.preferredHeight: 26
                            type: "Secondary"
                            text: "Load"
                            onClicked: aclForm.loadAcl(index)
                        }

                        IconButton {
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24
                            buttonSize: 24
                            glyph: "✕"
                            danger: true
                            tooltip: "Delete ACL"
                            onClicked: aclForm.deleteSavedAcl(aclId)
                        }
                    }

                    HoverHandler { id: savedAclHover }
                }
            }
        }
    }

    // KHU VỰC 2 — Rule Input
    Rectangle {
        Layout.fillWidth:   true
        Layout.leftMargin:  24
        Layout.rightMargin: 24
        implicitHeight:     ruleInputLayout.implicitHeight + 24
        radius:             Theme.cardRadius
        color:              Theme.contentSurface
        border.color:       Theme.borderColor
        border.width:       Theme.borderWidth

        ColumnLayout {
            id:              ruleInputLayout
            anchors.fill:    parent
            anchors.margins: 12
            spacing:         12

            Text {
                text:           "Add Rule — " + aclForm.currentAclType
                color:          Theme.textPrimary
                font.pixelSize: Theme.fontSizeNormal
                font.family:    Theme.fontFamily
                font.bold:      true
            }

            Rectangle {
                Layout.fillWidth: true
                height:           Theme.borderWidth
                color:            Theme.borderColor
                opacity:          0.6
            }

            RowLayout {
                Layout.fillWidth: true
                spacing:          12

                ColumnLayout {
                    Layout.preferredWidth: 120
                    spacing:               4
                    Text {
                        text:           "Sequence"
                        color:          Theme.textSecondary
                        font.pixelSize: Theme.fontSizeSmall
                        font.family:    Theme.fontFamily
                    }
                    StandardTextField {
                        id:               sequenceField
                        Layout.fillWidth: true
                        placeholderText:  "e.g., 10"
                        validator:        IntValidator { bottom: 1; top: 65535 }
                    }
                }

                StandardComboBox {
                    id: actionCombo
                    Layout.preferredWidth: 140
                    labelText: "Action"
                    model: ["Permit", "Deny"]
                    contentColor: currentText === "Permit" ? Theme.statusConnected : Theme.alertError
                    contentBold: true
                }

                Item { Layout.fillWidth: true }
            }

            AclRuleInputStandard {
                id:               standardInput
                Layout.fillWidth: true
                visible:          aclForm.currentAclType === "Standard"
            }

            AclRuleInputExtended {
                id:               extendedInput
                Layout.fillWidth: true
                visible:          aclForm.currentAclType === "Extended"
            }

            AclRuleInputDynamic {
                id:               dynamicInput
                Layout.fillWidth: true
                visible:          aclForm.currentAclType === "Dynamic"
            }

            AclRuleInputReflexive {
                id:               reflexiveInput
                Layout.fillWidth: true
                visible:          aclForm.currentAclType === "Reflexive"
            }

            AclRuleInputMac {
                id:               macInput
                Layout.fillWidth: true
                visible:          aclForm.currentAclType === "MAC"
            }

            RowLayout {
                Layout.fillWidth: true

                Text {
                    visible:        aclForm.lastError !== ""
                    text:           aclForm.lastError
                    color:          Theme.alertError
                    font.pixelSize: Theme.fontSizeSmall
                    font.family:    Theme.fontFamily
                    Layout.fillWidth: true
                    elide:          Text.ElideRight
                }

                Item { Layout.fillWidth: true }

                StandardButton {
                    text: "+ Add Rule"
                    type: "Primary"
                    onClicked: aclForm.addRule()
                }
            }
        }
    }

    // KHU VỰC 3 — Rule List
    Rectangle {
        Layout.fillWidth:   true
        Layout.leftMargin:  24
        Layout.rightMargin: 24
        implicitHeight:     ruleListLayout.implicitHeight + 24
        radius:             Theme.cardRadius
        color:              Theme.contentSurface
        border.color:       Theme.borderColor
        border.width:       Theme.borderWidth

        ColumnLayout {
            id:              ruleListLayout
            anchors.fill:    parent
            anchors.margins: 12
            spacing:         8

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text:           "Pending Rules"
                    color:          Theme.textPrimary
                    font.pixelSize: Theme.fontSizeNormal
                    font.family:    Theme.fontFamily
                    font.bold:      true
                }

                Rectangle {
                    visible:          ruleModel.count > 0
                    width:            ruleCountText.implicitWidth + 12
                    height:           20
                    radius:           10
                    color:            Theme.accentColor
                    Layout.alignment: Qt.AlignVCenter
                    Layout.leftMargin: 8

                    Text {
                        id:               ruleCountText
                        anchors.centerIn: parent
                        text:             ruleModel.count
                        color:            Theme.buttonTextSolid
                        font.pixelSize:   Theme.fontSizeSmall
                        font.family:      Theme.fontFamily
                        font.bold:        true
                    }
                }

                Item { Layout.fillWidth: true }

                StandardButton {
                    visible: ruleModel.count > 0
                    Layout.preferredHeight: 28
                    type: "Secondary"
                    text: "Clear All"
                    onClicked: aclForm.clearAllRules()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height:           Theme.borderWidth
                color:            Theme.borderColor
                opacity:          0.6
            }

            Rectangle {
                Layout.fillWidth: true
                height:           28
                color:            Theme.sideBarBackground
                radius:           Theme.borderRadius

                RowLayout {
                    anchors.fill:        parent
                    anchors.leftMargin:  8
                    anchors.rightMargin: 8
                    spacing:             8

                    Text {
                        Layout.preferredWidth: 36
                        text:                  "Seq"
                        color:                 Theme.textSecondary
                        font.pixelSize:        Theme.fontSizeSmall
                        font.family:           Theme.fontFamily
                        font.bold:             true
                        horizontalAlignment:   Text.AlignHCenter
                    }

                    Text {
                        Layout.preferredWidth: 54
                        text:                  "Action"
                        color:                 Theme.textSecondary
                        font.pixelSize:        Theme.fontSizeSmall
                        font.family:           Theme.fontFamily
                        font.bold:             true
                    }

                    Text {
                        Layout.fillWidth: true
                        text:             "Detail"
                        color:            Theme.textSecondary
                        font.pixelSize:   Theme.fontSizeSmall
                        font.family:      Theme.fontFamily
                        font.bold:        true
                    }

                    Item { Layout.preferredWidth: 24 }
                }
            }

            Text {
                visible:             ruleModel.count === 0
                Layout.fillWidth:    true
                text:                "No rules added yet. Use the form above to add rules."
                color:               Theme.textDisabled
                font.pixelSize:      Theme.fontSizeNormal
                font.family:         Theme.fontFamily
                horizontalAlignment: Text.AlignHCenter
                topPadding:          8
                bottomPadding:       8
            }

            Repeater {
                model: ruleModel
                delegate: AclRuleRow {
                    required property int    index
                    required property int    ruleSequence
                    required property string ruleAction
                    required property string ruleDetail
                    required property string ruleAclType

                    Layout.fillWidth: true
                    rowIndex:         index
                    rowSequence:      ruleSequence
                    rowAction:        ruleAction
                    rowDetail:        ruleDetail
                    rowAclType:       ruleAclType

                    onDeleteClicked: (idx) => aclForm.removeRule(idx)
                }
            }
        }
    }

    Item { height: 8 }

    // ── FOOTER (Nút Bấm) ──
    footer: [
        Text {
            text: aclForm.hasPendingRules
                  ? ruleModel.count + " rule(s) pending — not yet saved."
                  : "Add rules above, then save the ACL configuration."
            color: Theme.textSecondary
            font.pixelSize: Theme.fontSizeSmall
            font.family: Theme.fontFamily
            Layout.fillWidth: true
            elide: Text.ElideRight
        },
        StandardButton {
            text: "Save ACL Config"
            type: "Primary"
            enabled: aclForm.hasPendingRules
            onClicked: aclForm.saveAcl()
        }
    ]
}
