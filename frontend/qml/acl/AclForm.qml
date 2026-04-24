pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import NetworkUI

// ── AclForm ──────────────────────────────────────────────────────────────────
// Form chính của ACL feature, gồm 3 khu vực:
//   1. General Info  — ACL Name, Host, Description (dùng chung 5 loại ACL)
//   2. Rule Input    — Sequence, Action + box nhập liệu theo từng ACL type
//   3. Rule List     — Bảng danh sách rules đang chờ lưu + nút Save
// ─────────────────────────────────────────────────────────────────────────────
Rectangle {
    id: aclForm

    property string currentHostIp: ""
    property string currentAclType: "Standard"  // Nhận từ AclView khi tab thay đổi

    // ── Trạng thái form ──
    property bool hasPendingRules: ruleModel.count > 0
    property string lastError:     ""

    color: Theme.contentBackground

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

    ColumnLayout {
        anchors.fill: parent
        spacing:      0

        // ════════════════════════════════════════════════════════════
        // SCROLLABLE CONTENT
        // ════════════════════════════════════════════════════════════
        ScrollView {
            Layout.fillWidth:  true
            Layout.fillHeight: true
            clip:              true
            contentWidth:      availableWidth
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.policy:   ScrollBar.AsNeeded

            ColumnLayout {
                width:   aclForm.width
                spacing: 16

                // ────────────────────────────────────────────────────
                // KHU VỰC 1 — General Info
                // ────────────────────────────────────────────────────
                Rectangle {
                    Layout.fillWidth:    true
                    Layout.leftMargin:   24
                    Layout.rightMargin:  24
                    Layout.topMargin:    16
                    implicitHeight:      generalLayout.implicitHeight + 24
                    radius:              Theme.cardRadius
                    color:               Theme.searchBackground2
                    border.color:        Theme.borderColor
                    border.width:        Theme.borderWidth

                    ColumnLayout {
                        id:              generalLayout
                        anchors.fill:    parent
                        anchors.margins: 12
                        spacing:         12

                        // ── Tiêu đề khu vực ──────────────────────────
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

                        // ── Hàng 1: ACL Name (bắt buộc) + Host ───────
                        RowLayout {
                            Layout.fillWidth: true
                            spacing:          12

                            // ACL Name
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing:          4

                                // ── Label có dấu * để báo bắt buộc ──
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

                            // Host
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
                                    // ── Pre-fill từ currentHostIp nếu có ──
                                    text:             aclForm.currentHostIp
                                }
                            }
                        }

                        // ── Hàng 2: Description ───────────────────────
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

                // ────────────────────────────────────────────────────
                // KHU VỰC 2 — Rule Input
                // ────────────────────────────────────────────────────
                Rectangle {
                    Layout.fillWidth:   true
                    Layout.leftMargin:  24
                    Layout.rightMargin: 24
                    implicitHeight:     ruleInputLayout.implicitHeight + 24
                    radius:             Theme.cardRadius
                    color:              Theme.searchBackground2
                    border.color:       Theme.borderColor
                    border.width:       Theme.borderWidth

                    ColumnLayout {
                        id:              ruleInputLayout
                        anchors.fill:    parent
                        anchors.margins: 12
                        spacing:         12

                        // ── Tiêu đề khu vực ──────────────────────────
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

                        // ── Hàng Sequence + Action ────────────────────
                        RowLayout {
                            Layout.fillWidth: true
                            spacing:          12

                            // Sequence
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

                            // Action
                            ColumnLayout {
                                Layout.preferredWidth: 140
                                spacing:               4

                                Text {
                                    text:           "Action"
                                    color:          Theme.textSecondary
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.family:    Theme.fontFamily
                                }

                                // ── ComboBox Action dùng style nhất quán ──
                                ComboBox {
                                    id:               actionCombo
                                    Layout.fillWidth: true
                                    model:            ["Permit", "Deny"]
                                    font.pixelSize:   Theme.fontSizeNormal
                                    font.family:      Theme.fontFamily

                                    background: Rectangle {
                                        color:        Theme.searchBackground
                                        border.color: actionCombo.activeFocus || actionCombo.popup.visible
                                                          ? Theme.accentColor
                                                          : Theme.borderColor
                                        border.width: Theme.borderWidth
                                        radius:       Theme.borderRadius
                                    }

                                    contentItem: Text {
                                        text:              actionCombo.currentText
                                        // ── Màu tự động theo action đang chọn ──
                                        color:             actionCombo.currentText === "Permit"
                                                               ? Theme.statusConnected
                                                               : Theme.alertError
                                        font.pixelSize:    Theme.fontSizeNormal
                                        font.family:       Theme.fontFamily
                                        font.bold:         true
                                        verticalAlignment: Text.AlignVCenter
                                        leftPadding:       10
                                    }

                                    delegate: ItemDelegate {
                                        required property int    index
                                        required property string modelData

                                        width: actionCombo.width

                                        contentItem: Text {
                                            text:              modelData
                                            color:             modelData === "Permit"
                                                                   ? Theme.statusConnected
                                                                   : Theme.alertError
                                            font.family:       Theme.fontFamily
                                            font.pixelSize:    Theme.fontSizeNormal
                                            font.bold:         true
                                            verticalAlignment: Text.AlignVCenter
                                        }

                                        background: Rectangle {
                                            color:  highlighted ? Theme.sideBarItemHover : Theme.searchBackground
                                            radius: Theme.borderRadius
                                        }

                                        highlighted: actionCombo.highlightedIndex === index
                                    }

                                    popup: Popup {
                                        y:              actionCombo.height + 4
                                        width:          actionCombo.width
                                        implicitHeight: contentItem.implicitHeight
                                        padding:        4

                                        contentItem: ListView {
                                            clip:           true
                                            implicitHeight: contentHeight
                                            model:          actionCombo.popup.visible ? actionCombo.delegateModel : null
                                            currentIndex:   actionCombo.highlightedIndex
                                            ScrollIndicator.vertical: ScrollIndicator {}
                                        }

                                        background: Rectangle {
                                            color:        Theme.searchBackground
                                            border.color: Theme.borderColor
                                            border.width: Theme.borderWidth
                                            radius:       Theme.borderRadius
                                        }
                                    }
                                }
                            }

                            // ── Spacer đẩy các field sang trái ──
                            Item { Layout.fillWidth: true }
                        }

                        // ── Box nhập liệu theo ACL type ───────────────
                        // Dùng visible thay vì Loader để tránh mất state khi ẩn/hiện
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

                        // ── Nút Add Rule ──────────────────────────────
                        RowLayout {
                            Layout.fillWidth: true

                            // ── Thông báo lỗi validation ──
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

                            Rectangle {
                                Layout.preferredWidth:  110
                                Layout.preferredHeight: 34
                                radius:                 Theme.borderRadius
                                color:                  addRuleHover.hovered
                                                            ? Qt.lighter(Theme.accentColor, 1.2)
                                                            : Theme.accentColor

                                Behavior on color {
                                    ColorAnimation { duration: Theme.animationDurationFast }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text:             "+ Add Rule"
                                    color:            Theme.buttonTextSolid
                                    font.pixelSize:   Theme.fontSizeNormal
                                    font.family:      Theme.fontFamily
                                    font.bold:        true
                                }

                                HoverHandler { id: addRuleHover }
                                TapHandler   { onTapped: aclForm.addRule() }
                            }
                        }
                    }
                }

                // ────────────────────────────────────────────────────
                // KHU VỰC 3 — Rule List
                // ────────────────────────────────────────────────────
                Rectangle {
                    Layout.fillWidth:   true
                    Layout.leftMargin:  24
                    Layout.rightMargin: 24
                    implicitHeight:     ruleListLayout.implicitHeight + 24
                    radius:             Theme.cardRadius
                    color:              Theme.searchBackground2
                    border.color:       Theme.borderColor
                    border.width:       Theme.borderWidth

                    ColumnLayout {
                        id:              ruleListLayout
                        anchors.fill:    parent
                        anchors.margins: 12
                        spacing:         8

                        // ── Tiêu đề + badge số lượng ─────────────────
                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text:           "Pending Rules"
                                color:          Theme.textPrimary
                                font.pixelSize: Theme.fontSizeNormal
                                font.family:    Theme.fontFamily
                                font.bold:      true
                            }

                            // ── Badge số lượng rule ──
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

                            // ── Nút Clear All ──
                            Rectangle {
                                visible:                ruleModel.count > 0
                                Layout.preferredWidth:  80
                                Layout.preferredHeight: 28
                                radius:                 Theme.borderRadius
                                color:                  clearAllHover.hovered
                                                            ? Theme.sideBarItemHover
                                                            : "transparent"
                                border.color:           Theme.borderColor
                                border.width:           Theme.borderWidth

                                Text {
                                    anchors.centerIn: parent
                                    text:             "Clear All"
                                    color:            Theme.textSecondary
                                    font.pixelSize:   Theme.fontSizeSmall
                                    font.family:      Theme.fontFamily
                                }

                                HoverHandler { id: clearAllHover }
                                TapHandler   { onTapped: aclForm.clearAllRules() }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height:           Theme.borderWidth
                            color:            Theme.borderColor
                            opacity:          0.6
                        }

                        // ── Header cột bảng ───────────────────────────
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

                                // ── Placeholder cho cột nút Delete ──
                                Item { Layout.preferredWidth: 24 }
                            }
                        }

                        // ── Placeholder khi chưa có rule nào ─────────
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

                        // ── Danh sách rules ───────────────────────────
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

                // ── Spacer cuối trang ─────────────────────────────────
                Item { height: 8 }
            }
        }

        // ════════════════════════════════════════════════════════════
        // FOOTER — Save button
        // ════════════════════════════════════════════════════════════
        Rectangle {
            Layout.fillWidth: true
            height:           Theme.borderWidth
            color:            Theme.borderColor
        }

        Rectangle {
            Layout.fillWidth:  true
            height:            56
            color:             Theme.contentBackground

            RowLayout {
                anchors.fill:          parent
                anchors.leftMargin:    24
                anchors.rightMargin:   24
                anchors.topMargin:     10
                anchors.bottomMargin:  10
                spacing:               8

                // ── Thông tin trạng thái footer ──
                Text {
                    text:             aclForm.hasPendingRules
                                          ? ruleModel.count + " rule(s) pending — not yet saved."
                                          : "Add rules above, then save the ACL configuration."
                    color:            Theme.textSecondary
                    font.pixelSize:   Theme.fontSizeSmall
                    font.family:      Theme.fontFamily
                    Layout.fillWidth: true
                    elide:            Text.ElideRight
                }

                // ── Nút Save ACL Config ──
                Rectangle {
                    Layout.preferredWidth:  140
                    Layout.preferredHeight: 34
                    radius:                 Theme.borderRadius
                    opacity:                aclForm.hasPendingRules ? 1.0 : 0.45
                    color:                  aclForm.hasPendingRules
                                                ? (saveHover.hovered
                                                       ? Qt.lighter(Theme.accentColor, 1.2)
                                                       : Theme.accentColor)
                                                : Theme.borderColor

                    Behavior on color {
                        ColorAnimation { duration: Theme.animationDurationFast }
                    }

                    Text {
                        anchors.centerIn: parent
                        text:             "Save ACL Config"
                        color:            Theme.buttonTextSolid
                        font.pixelSize:   Theme.fontSizeSmall
                        font.family:      Theme.fontFamily
                        font.bold:        true
                    }

                    HoverHandler { id: saveHover }
                    TapHandler {
                        enabled:  aclForm.hasPendingRules
                        onTapped: aclForm.saveAcl()
                    }
                }
            }
        }
    }
}