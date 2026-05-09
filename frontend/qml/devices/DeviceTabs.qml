pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import NetworkTools

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
    }

    // Mở Tab mới hoặc Focus vào Tab đã tồn tại dựa trên IP (uid)
    function openTab(ip, name) {
        for (let i = 0; i < tabModel.count; i++) {
            if (tabModel.get(i).uid === ip) {
                selectTab(i)
                return
            }
        }

        const displayName = (name && name.trim() !== "") ? name : ip
        tabModel.append({
            uid:      ip,
            title:    displayName,
            isActive: false,
            fMain:    0,
            fText:    -1
        })
        selectTab(tabModel.count - 1)
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

    // Cập nhật giao diện và ghi nhận lịch sử khi chuyển đổi Tab
    function selectTab(idx) {
        if (idx < 0 || idx >= tabModel.count) return
        const uid = tabModel.get(idx).uid

        for (let i = 0; i < tabModel.count; i++) {
            tabModel.setProperty(i, "isActive", i === idx)
        }

        root.currentFMain = tabModel.get(idx).fMain
        root.currentFText = tabModel.get(idx).fText

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
            fMain: tab.fMain,
            fText: tab.fText
        })
        
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
        }
    }

    function closeTabByUid(uid) {
        const idx = findIndexByUid(uid)
        if (idx !== -1) closeTab(idx)
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
            fMain:    lastClosed.fMain,
            fText:    lastClosed.fText
        })
        
        selectTab(tabModel.count - 1)
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