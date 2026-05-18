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

    // ── Model lưu danh sách rules đang chờ lưu ──
    ListModel { id: ruleModel }

    // ── Hàm xóa toàn bộ rules khi chuyển ACL type ──
    function clearAllRules() {
        ruleModel.clear()
        lastError = ""
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

        ruleModel.append({
            ruleSequence: seq !== "" ? parseInt(seq, 10) : ruleModel.count + 10,
            ruleAction:   action,
            ruleDetail:   detail,
            ruleAclType:  currentAclType
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

    // ── Hàm Save — hiện tại chỉ notify vì chưa có backend ──
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

        // ── Placeholder: sẽ gọi dbManager.saveAcl() khi có backend ──
        if (typeof statusBar !== "undefined")
            statusBar.showMessage(
                "ACL \"" + aclName + "\" (" + currentAclType + ") — "
                + ruleModel.count + " rule(s) ready. Backend not yet implemented.",
                "warning"
            )

        lastError = ""
    }

    // ── Reset form khi chuyển ACL type ──
    onCurrentAclTypeChanged: {
        lastError = ""
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
