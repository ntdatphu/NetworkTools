pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import UI

Rectangle {
    id: root
    width: parent.width
    height: Theme.tabBarHeight
    color: Theme.tabBarBackground

    Rectangle {
        anchors.bottom: parent.bottom; width: parent.width; height: 1
        color: Theme.borderColor; z: 10
    }

    // Quản lý trạng thái và lịch sử điều hướng Tab nội bộ (chỉ lưu trên RAM)
    property var activeHistory: []
    property var closedTabsHistory: []
    property int nextTabId: 100
    property int tabCount: tabModel.count

    property int currentFMain: 0
    property int currentFText: -1
    property string activeUid: ""
    property string activeDeviceType: ""

    // Cờ kiểm soát vòng đời khởi tạo của thanh Tabs
    property bool isInitialized: false
    
    signal openNewDeviceRequested()
    signal activeTabChanged(string uid)

    ListModel {
        id: tabModel
    }

    // Thiết lập trạng thái rỗng cho toàn bộ Tabs khi ứng dụng bắt đầu
    function initializeTabs(validIps) {
        if (isInitialized) return 
        isInitialized = true
        
        tabModel.clear()
        activeHistory = []
        closedTabsHistory = []
        root.currentFMain = 0
        root.currentFText = -1
        root.activeUid = ""
        root.activeDeviceType = ""
    }

    function cleanTitle(value) {
        return String(value || "").replace(/[\x00-\x1F\x7F]/g, "").replace(/^[#>`'"]+|[#>`'"]+$/g, "").trim()
    }

    function shouldOpenSessionForStatus(status) {
        return String(status || "").toLowerCase() === "connected"
    }

    function notifySessionResult(result) {
        if (!result || !result.message)
            return
        const type = result.severity || (result.ok ? "success" : "error")
        if (typeof statusBar !== "undefined")
            statusBar.showMessage(String(result.message), type)
    }

    function ensureSessionForTab(uid, status) {
        const host = String(uid || "").trim()
        if (host === "" || !shouldOpenSessionForStatus(status))
            return
        if (typeof cli === "undefined" || !cli.openDeviceSession)
            return
        if (cli.hasDeviceSession && cli.hasDeviceSession(host))
            return

        const result = cli.openDeviceSession(host)
        const idx = findIndexByUid(host)
        if (idx !== -1)
            tabModel.setProperty(idx, "sessionState", result && result.ok ? "connected" : "error")
        notifySessionResult(result)
    }

    function closeSessionForTab(uid) {
        const host = String(uid || "").trim()
        if (host === "" || typeof cli === "undefined" || !cli.closeDeviceSession)
            return
        cli.closeDeviceSession(host)
    }

    // Mở Tab mới hoặc Focus vào Tab đã tồn tại dựa trên IP (uid)
    function openTab(ip, name, deviceType, status) {
        const cleanName = cleanTitle(name)
        for (let i = 0; i < tabModel.count; i++) {
            if (tabModel.get(i).uid === ip) {
                if (cleanName !== "")
                    tabModel.setProperty(i, "title", cleanName)
                tabModel.setProperty(i, "deviceType", deviceType || tabModel.get(i).deviceType || "unknown")
                tabModel.setProperty(i, "status", status || tabModel.get(i).status || "disconnected")
                selectTab(i)
                ensureSessionForTab(ip, status || tabModel.get(i).status)
                return
            }
        }

        const displayName = cleanName !== "" ? cleanName : ip
        tabModel.append({
            uid:      ip,
            title:    displayName,
            isActive: false,
            deviceType: deviceType || "unknown",
            status:   status || "disconnected",
            sessionState: "pending",
            fMain:    0,
            fText:    -1
        })
        selectTab(tabModel.count - 1)
        ensureSessionForTab(ip, status || "disconnected")
    }

    function findIndexByUid(uid) {
        for (let i = 0; i < tabModel.count; i++) {
            if (tabModel.get(i).uid === uid) return i
        }
        return -1
    }

    function getActiveIndex() {
        for (let i = 0; i < tabModel.count; i++) {
            if (tabModel.get(i).isActive) return i
        }
        return -1
    }

    function setFeatureForActiveTab(mIdx, tIdx) {
        const idx = getActiveIndex()
        if (idx !== -1) {
            tabModel.setProperty(idx, "fMain", mIdx)
            tabModel.setProperty(idx, "fText", tIdx)
            root.currentFMain = mIdx
            root.currentFText = tIdx
        }
    }

    function updateDeviceMetadata(devices) {
        if (!devices) return

        for (let i = 0; i < devices.length; i++) {
            const device = devices[i]
            const uid = device && device.ip ? String(device.ip) : ""
            if (uid === "") continue

            const idx = findIndexByUid(uid)
            if (idx === -1) continue

            const current = tabModel.get(idx)
            const cleanName = cleanTitle(device.name)
            const displayName = cleanName !== ""
                              ? cleanName
                              : uid

            tabModel.setProperty(idx, "title", displayName)
            tabModel.setProperty(idx, "deviceType", device.type || current.deviceType || "unknown")
            const nextStatus = device.status || current.status || "disconnected"
            tabModel.setProperty(idx, "status", nextStatus)
            ensureSessionForTab(uid, nextStatus)
        }
    }

    // Cập nhật giao diện và ghi nhận lịch sử khi chuyển đổi Tab
    function selectTab(idx) {
        if (idx < 0 || idx >= tabModel.count) return
        const uid = tabModel.get(idx).uid

        for (let i = 0; i < tabModel.count; i++) {
            tabModel.setProperty(i, "isActive", i === idx)
        }

        root.currentFMain = tabModel.get(idx).fMain
        root.currentFText = tabModel.get(idx).fText
        root.activeDeviceType = tabModel.get(idx).deviceType || "unknown"

        // Chỉ lưu vào lịch sử nếu chuyển sang một Tab khác
        if (activeHistory.length === 0 || activeHistory[activeHistory.length - 1] !== uid) {
            activeHistory.push(uid)
        }

        activeTabChanged(uid)
        root.activeUid = uid
    }

    // Đóng Tab và tự động Focus lại Tab vừa sử dụng trước đó (Fallback)
    function closeTab(idx) {
        const tab = tabModel.get(idx)
        const wasActive = tab.isActive
        const uid = tab.uid

        closedTabsHistory.push({
            title: tab.title,
            uid:   tab.uid,
            deviceType: tab.deviceType,
            status: tab.status,
            sessionState: tab.sessionState || "closed",
            fMain: tab.fMain,
            fText: tab.fText
        })
        closeSessionForTab(uid)
        
        tabModel.remove(idx)

        // Nếu Tab đang được chọn bị đóng, tìm Tab gần nhất trong lịch sử để Focus
        if (wasActive && tabModel.count > 0) {
            let nextUid = ""
            while (activeHistory.length > 0) {
                const last = activeHistory.pop()
                if (last !== uid && findIndexByUid(last) !== -1) {
                    nextUid = last
                    activeHistory.push(nextUid)
                    break
                }
            }
            
            if (nextUid !== "") selectTab(findIndexByUid(nextUid))
            else selectTab(tabModel.count - 1)
        }

        // Xóa sạch trạng thái nếu không còn Tab nào
        if (tabModel.count === 0) {
            root.currentFMain = 0
            root.currentFText = -1
            root.activeUid = ""
            root.activeDeviceType = ""
        }
    }

    function closeTabByUid(uid) {
        const idx = findIndexByUid(uid)
        if (idx !== -1) closeTab(idx)
    }

    // Mở tab theo uid — nếu đã có thì focus, chưa có thì không làm gì
    // (khác openTab là không cần name)
    function openTabByUid(uid) {
        const idx = findIndexByUid(uid)
        if (idx !== -1) selectTab(idx)
    }

    // Trả về snapshot danh sách tab hiện tại để PanelSideBar hiển thị
    // dưới dạng array of {uid, title, isActive, deviceType, status}
    function buildOpenEditorSnapshot() {
        const result = []
        for (let i = 0; i < tabModel.count; i++) {
            const row = tabModel.get(i)
            result.push({
                uid:      row.uid,
                title:    row.title,
                isActive: row.isActive,
                deviceType: row.deviceType,
                status: row.status
            })
        }
        return result
    }

    function closeCurrentTab() {
        const idx = getActiveIndex()
        if (idx !== -1) closeTab(idx)
    }

    function reopenLastClosedTab() {
        if (closedTabsHistory.length === 0) return
        const lastClosed = closedTabsHistory.pop()
        
        tabModel.append({
            uid:      lastClosed.uid,
            title:    lastClosed.title,
            isActive: false,
            deviceType: lastClosed.deviceType || "unknown",
            status:   lastClosed.status || "disconnected",
            sessionState: "pending",
            fMain:    lastClosed.fMain,
            fText:    lastClosed.fText
        })
        
        selectTab(tabModel.count - 1)
        ensureSessionForTab(lastClosed.uid, lastClosed.status || "disconnected")
    }

    function nextTab() {
        if (tabModel.count <= 1) return
        const idx = getActiveIndex()
        selectTab((idx + 1) % tabModel.count)
    }

    function prevTab() {
        if (tabModel.count <= 1) return
        const idx = getActiveIndex()
        selectTab((idx - 1 + tabModel.count) % tabModel.count)
    }

    function moveTab(fromIdx, toIdx) {
        tabModel.move(fromIdx, toIdx, 1)
    }

    ListView {
        id: tabListView
        anchors.fill: parent
        orientation: ListView.Horizontal
        interactive: true
        clip: true
        model: tabModel

        move: Transition {
            NumberAnimation { properties: "x,y"; duration: Theme.animationDurationMedium; easing.type: Easing.OutQuad }
        }

        delegate: DeviceTabItem {
            onMoveRequested:   function(fromIdx, toIdx) { root.moveTab(fromIdx, toIdx) }
            onSelectRequested: function(idx) { root.selectTab(idx) }
            onCloseRequested:  function(idx) { root.closeTab(idx) }
        }
    }

    Shortcut { sequence: "Ctrl+T";         onActivated: root.openNewDeviceRequested() }
    Shortcut { sequence: "Ctrl+W";         onActivated: root.closeCurrentTab() }
    Shortcut { sequence: "Ctrl+Shift+T";   onActivated: root.reopenLastClosedTab() }
    Shortcut { sequence: "Ctrl+Tab";       onActivated: root.nextTab() }
    Shortcut { sequence: "Ctrl+Shift+Tab"; onActivated: root.prevTab() }
}
