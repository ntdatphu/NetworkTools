pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

Rectangle {
    id: root
    objectName: "informationView"

    property string currentHostIp: ""
    property string configText: ""
    property string configPath: ""
    property string loadError: ""
    property var commitHistory: []
    property var commitHistoryLabels: []
    property string selectedCommitId: ""
    property string selectedCommitDateTime: ""
    property bool isLoadingHistory: false
    property bool isLoadingCommit: false
    property string lastLoadedHost: ""
    property string lastReloadReason: ""
    readonly property bool isViewLoading: root.isLoadingHistory
                                          || root.isLoadingCommit
                                          || informationConfigViewer.highlightingInProgress

    color: Theme.contentBackground

    // Xóa toàn bộ dữ liệu của host cũ trước khi tải lịch sử host mới.
    function clearContent() {
        root.configText = ""
        root.configPath = ""
        root.loadError = ""
        root.selectedCommitId = ""
        root.selectedCommitDateTime = ""
    }

    // Đọc một Git blob lịch sử; thao tác này không checkout hay gửi lệnh thiết bị.
    function loadCommit(commitId) {
        const host = String(root.currentHostIp || "").trim()
        const requestedCommit = String(commitId || "").trim()
        if (host === "" || requestedCommit === "")
            return false
        root.isLoadingCommit = true
        const payload = dbManager.getRunningConfigAtCommit(host, requestedCommit)
        root.applyCommitPayload(requestedCommit, payload)
        root.isLoadingCommit = false
        return true
    }

    // Ánh xạ payload snapshot backend vào ConfigTextViewer hiện có.
    function applyCommitPayload(requestedCommit, payload) {
        const ok = payload && payload.ok === true
        root.configPath = payload && payload.path ? String(payload.path) : ""
        if (ok) {
            root.configText = payload && payload.content ? String(payload.content) : ""
            root.selectedCommitId = String(payload.commitId || requestedCommit)
            root.selectedCommitDateTime = String(payload.dateTime || "")
            root.loadError = ""
        } else {
            root.configText = ""
            root.loadError = payload && payload.message ? String(payload.message) : "Load committed running-config failed."
        }
    }

    // Tải lại tối đa 100 commit và luôn đưa lựa chọn về HEAD mới nhất.
    function reloadData(reason) {
        const host = String(root.currentHostIp || "").trim()
        root.lastReloadReason = String(reason || "manual")
        root.clearContent()
        root.commitHistory = []
        root.commitHistoryLabels = []
        commitHistoryComboBox.currentIndex = -1
        root.lastLoadedHost = host
        if (host === "")
            return false

        root.isLoadingHistory = true
        const payload = dbManager.getRunningConfigHistory(host)
        root.applyHistoryPayload(payload)
        root.isLoadingHistory = false
        return true
    }

    // Tạo model nhãn cho StandardComboBox từ metadata commit mới nhất trước.
    function applyHistoryPayload(payload) {
        if (!payload || payload.ok !== true) {
            root.loadError = payload && payload.message ? String(payload.message) : "Load running-config history failed."
            return
        }
        root.commitHistory = payload.commits || []
        const labels = []
        for (let index = 0; index < root.commitHistory.length; ++index)
            labels.push(String(root.commitHistory[index].displayText || ""))
        root.commitHistoryLabels = labels
        if (root.commitHistory.length > 0) {
            commitHistoryComboBox.currentIndex = 0
            root.loadCommit(root.commitHistory[0].commitId)
        }
    }

    Connections {
        target: typeof cli !== "undefined" ? cli : null
        function onRunningConfigFinished(host, ok, message) {
            if (ok && String(host || "") === String(root.currentHostIp || "").trim())
                root.reloadData()
        }
    }

    onCurrentHostIpChanged: reloadData()
    Component.onCompleted: {
        if (root.lastLoadedHost !== String(root.currentHostIp || "").trim())
            root.reloadData()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: Theme.spacing12

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing12

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                Text {
                    text: "Information"
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLarge
                    font.bold: true
                }

                Text {
                    Layout.fillWidth: true
                    text: root.currentHostIp === ""
                          ? "No device selected"
                          : root.currentHostIp + (root.configPath !== "" ? " · " + root.configPath : "")
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    elide: Text.ElideLeft
                }
            }

            StandardComboBox {
                id: commitHistoryComboBox
                objectName: "informationCommitHistoryComboBox"
                Layout.preferredWidth: 240
                model: root.commitHistoryLabels
                emptyText: "No backup history"
                enabled: String(root.currentHostIp || "").trim() !== ""
                         && root.commitHistory.length > 0
                         && !root.isLoadingHistory
                         && !root.isLoadingCommit
                onActivated: function(index) {
                    if (index >= 0 && index < root.commitHistory.length)
                        root.loadCommit(root.commitHistory[index].commitId)
                }
            }

            StandardButton {
                objectName: "informationReloadButton"
                text: "Reload"
                icon.source: AppAssets.actionBackup
                type: "Secondary"
                enabled: String(root.currentHostIp || "").trim() !== ""
                         && !root.isLoadingHistory
                         && !root.isLoadingCommit
                onClicked: root.reloadData()
            }

            StandardButton {
                objectName: "informationCopyAllButton"
                Layout.preferredWidth: 104
                text: informationConfigViewer.copyFeedbackVisible ? "Copied" : "Copy All"
                icon.source: AppAssets.actionCopy
                type: "Secondary"
                enabled: root.configText !== ""
                onClicked: informationConfigViewer.copyAll()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.radiusSmall
            color: Theme.contentPanelSurface
            border.color: Theme.contentPanelBorder
            border.width: Theme.borderWidth

            ConfigTextViewer {
                id: informationConfigViewer
                objectName: "informationConfigViewer"
                anchors.fill: parent
                anchors.margins: Theme.spacing12
                text: root.configText
                sourceLabel: root.selectedCommitDateTime !== ""
                             ? "Running configuration · " + root.selectedCommitDateTime
                               + " · " + root.selectedCommitId.slice(0, 7)
                             : "Running configuration"
                loading: root.isLoadingHistory || root.isLoadingCommit
                loadingText: "Loading running-config history..."
                errorText: root.loadError
                emptyText: root.currentHostIp === ""
                           ? "Choose a device to view its running-config backup."
                           : "No running-config data is available."
            }
        }
    }
}
