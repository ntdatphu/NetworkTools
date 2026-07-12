# CHANGES_PENDING.md — Đặc tả chi tiết các thay đổi cần thực hiện

Ngày tạo: 2026-07-12  
Liên kết: `docs/beta/schema.md` §8  
Mục đích: Tài liệu đặc tả **đủ chi tiết để AI khác thực hiện** mà không cần thêm ngữ cảnh ngoài.

> **Quy ước đọc tài liệu này**
> - Mỗi mục có ID tương ứng với schema.md §8 (UI-8-01 … LOGIC-8-03).
> - Đường dẫn file dùng dạng `app/UI/...` tính từ gốc workspace `r:\NetworkTools\`.
> - `[LINE ~N]` = số dòng tham chiếu tại thời điểm viết tài liệu (có thể lệch nhẹ).
> - Mỗi thay đổi có mục **"Thực hiện"** mô tả chính xác những gì cần làm.
> - Mỗi thay đổi có mục **"Xác nhận"** mô tả cách verify sau khi làm xong.

---

## UI-8-01 — Split-pane size inconsistency across Features

### Vấn đề
Khi người dùng chuyển giữa các tab NAT (NAT ACL → NAT Route Map → v.v.), vị trí thanh chia đôi màn hình (SplitView handle) thay đổi. Mỗi form dùng `SplitView.preferredWidth` hardcoded khác nhau và Qt SplitView không chia sẻ state khi switch giữa Loader instances.

### Files liên quan
- `app/UI/qml/nat/NatAclForm.qml` — line ~35-37: `SplitView.preferredWidth: 320`
- `app/UI/qml/nat/NatRouteMapForm.qml` — line tương tự
- `app/UI/qml/nat/NatDynamicForm.qml`
- `app/UI/qml/nat/NatStaticForm.qml`
- `app/UI/qml/nat/NatInterfaceForm.qml`
- `app/UI/qml/nat/NatPatForm.qml`

### Hiện trạng
`NatAclForm.qml` line ~35-37:
```qml
SplitFormPane {
    SplitView.preferredWidth: 320
    SplitView.minimumWidth:   240
```

### Thực hiện
1. Grep `SplitView.preferredWidth` trong `app/UI/qml/nat/` để lấy tất cả giá trị hiện tại.
2. Chuẩn hóa tất cả NAT forms sang cùng giá trị:
   - Left pane: `SplitView.preferredWidth: 340`, `SplitView.minimumWidth: 260`
3. KHÔNG thay đổi `InterfaceView.qml` (dùng 640px, hợp lý do form phức tạp hơn).

### Xác nhận
Mở NAT → chuyển qua lại giữa ACL và Route Map → thanh chia không nhảy vị trí.

---

## UI-8-02 — SpinBox left-side padding bất thường

### Vấn đề
`StandardSpinBox` có `contentItem.leftPadding = 12px` nhưng người dùng nhận thấy nội dung text bên trái SpinBox có khoảng trắng lớn hơn `StandardTextField` (cũng 12px). Nguyên nhân có thể do Qt positioning rule cho SpinBox contentItem.

### Files liên quan
- `app/UI/components/standard/StandardSpinBox.qml` — line ~44-59

### Hiện trạng
```qml
contentItem: TextInput {
    // ...
    horizontalAlignment: Qt.AlignLeft
    verticalAlignment: Qt.AlignVCenter
    leftPadding: Theme.spacing12      // 12px
    rightPadding: 36
```

### Thực hiện
**Phương án A (thử trước)**: Giảm `leftPadding` từ `Theme.spacing12` (12) xuống `Theme.spacing8` (8):
```qml
leftPadding: Theme.spacing8   // 8px thay vì 12px
```

**Phương án B (nếu A không đủ)**: Thêm explicit anchors vào contentItem để bỏ qua Qt default positioning:
```qml
contentItem: TextInput {
    anchors.left: parent ? parent.left : undefined
    anchors.leftMargin: Theme.spacing8
    anchors.right: parent ? parent.right : undefined
    anchors.rightMargin: 30
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    // ... các properties còn lại giữ nguyên (bỏ leftPadding/rightPadding khi dùng anchors)
```

**So sánh**: Mở form có cả `StandardTextField` và `StandardSpinBox` trên cùng một hàng → canh cho text content bên trái thẳng hàng nhau.

### Xác nhận
Mở ACL form hoặc OSPF form → nội dung số trong SpinBox ngang hàng với text trong TextField cùng hàng.

---

## UI-8-03 — Button text alignment không nhất quán

### Vấn đề
`StandardButton` dùng `contentItem: RowLayout { Text { ... } }`. Text không có `horizontalAlignment` rõ ràng và không có `Layout.fillWidth: true`, khiến khi button có `Layout.fillWidth: true` text bị căn trái thay vì căn giữa.

### Files liên quan
- `app/UI/components/standard/StandardButton.qml` — line ~100-124

### Hiện trạng (line ~113-124):
```qml
Text {
    visible: root.text !== "" && root.type !== "Icon"
    text: root.text
    color: root._textColor
    font.pixelSize: Theme.fontSizeNormal
    font.family: Theme.fontFamily
    font.bold: root.type === "Primary" || root.type === "Danger"
    Layout.alignment: Qt.AlignVCenter
    // THIẾU: horizontalAlignment và Layout.fillWidth
}
```

### Thực hiện
Thêm 2 dòng vào `Text` trong `contentItem`:
```qml
Text {
    visible: root.text !== "" && root.type !== "Icon"
    text: root.text
    color: root._textColor
    font.pixelSize: Theme.fontSizeNormal
    font.family: Theme.fontFamily
    font.bold: root.type === "Primary" || root.type === "Danger"
    Layout.alignment: Qt.AlignVCenter
    Layout.fillWidth: true                       // THÊM
    horizontalAlignment: Text.AlignHCenter       // THÊM
}
```

**KHÔNG sửa** `ContextMenuItem.qml` — button menu phải căn trái.

### Xác nhận
- Mở Interface form → "Save Interface" button text căn giữa.
- Mở bất kỳ form nào → tất cả Primary/Secondary button text căn giữa.
- Context menu (right-click device) → menu items vẫn căn trái (không thay đổi).

---

## UI-8-04 — Xóa Settings tabs: General và Advanced

### Vấn đề
`SettingsPanel.qml` hiển thị 4 settings groups. 2 group cuối (General, Advanced) là placeholder L0, chưa có nội dung và không có kế hoạch dùng.

### Files liên quan
- `app/UI/qml/panels/SettingsPanel.qml` — line ~17-22
- `app/UI/qml/content/SettingsView.qml` — cần kiểm tra case cho "general"/"advanced"

### Hiện trạng (line ~17-22):
```qml
property var allItems: [
    { "key": "theme",          "title": "Theme",          "desc": "Theme, accent, and Status Bar settings" },
    { "key": "external_tools", "title": "External Tools", "desc": "Import, classify, and open external tools" },
    { "key": "general",        "title": "General",        "desc": "Language, startup, and default behavior" },
    { "key": "advanced",       "title": "Advanced",       "desc": "Diagnostics, debug, and experimental options" }
]
```

### Thực hiện
**Bước 1** — `SettingsPanel.qml`: Xóa 2 entries cuối:
```qml
property var allItems: [
    { "key": "theme",          "title": "Theme",          "desc": "Theme, accent, and Status Bar settings" },
    { "key": "external_tools", "title": "External Tools", "desc": "Import, classify, and open external tools" }
]
```

**Bước 2** — `SettingsView.qml`: Grep `"general"` và `"advanced"`. Nếu có switch/if case, thêm comment `// Removed: no use case` hoặc xóa case (đừng crash nếu key không match).

**Bước 3** — `schema.md` mục 6: Đổi `Settings (General, Advanced) | L0` → `Settings (General, Advanced) | Removed`.

### Xác nhận
- Mở Settings sidebar → chỉ thấy "Theme" và "External Tools".
- Search "general" → "No matching settings group."

---

## UI-8-05 — Routing Info: lỗi hiển thị Routes và Config

### Vấn đề
`info_routing.qml` dùng `visible:` để switch giữa 3 pages (Overview/Routes/Config). Tất cả instantiated cùng lúc. Các Rectangle dùng `implicitHeight` thay vì `Layout.fillHeight`, gây layout tính sai khi switch page:

- **Routes** (line ~526): `implicitHeight: tableLayout.implicitHeight` — table không fill chiều cao scrollview
- **Config** (line ~440): `implicitHeight: Math.max(560, configLayout.implicitHeight)` kết hợp với `configLayout.anchors.fill: parent` — pattern mâu thuẫn

### Files liên quan
- `app/UI/qml/routing/info_routing.qml` — line ~440-734

### Hiện trạng (Routes block, line ~526-535):
```qml
Rectangle {
    visible: root.activeInfoPage === "Routes"
    Layout.fillWidth: true
    Layout.leftMargin: 24
    Layout.rightMargin: 24
    Layout.topMargin: 18
    implicitHeight: tableLayout.implicitHeight   // VẤN ĐỀ
    // ...
    ColumnLayout {
        id: tableLayout
        width: parent.width                      // VẤN ĐỀ: không dùng anchors
```

### Thực hiện

**Fix Routes** (tìm `visible: root.activeInfoPage === "Routes"` — Rectangle):
```qml
Rectangle {
    visible: root.activeInfoPage === "Routes"
    Layout.fillWidth: true
    Layout.fillHeight: visible                   // THAY: fillHeight khi visible
    Layout.maximumHeight: visible ? 99999 : 0   // THÊM: collapse khi ẩn
    Layout.leftMargin: 24
    Layout.rightMargin: 24
    Layout.topMargin: visible ? 18 : 0          // THÊM: collapse margin khi ẩn
    // ... (xóa dòng implicitHeight)

    ColumnLayout {
        id: tableLayout
        anchors.fill: parent                     // THAY: dùng anchors thay vì width
        spacing: 0
        // ... nội dung bên trong giữ nguyên
```

**Fix Config** (tìm `visible: root.activeInfoPage === "Config"` — Rectangle):
```qml
Rectangle {
    visible: root.activeInfoPage === "Config"
    Layout.fillWidth: true
    Layout.fillHeight: visible                   // THAY
    Layout.maximumHeight: visible ? 99999 : 0   // THÊM
    Layout.leftMargin: 24
    Layout.rightMargin: 24
    Layout.topMargin: visible ? 18 : 0          // THÊM
    // ... (xóa dòng implicitHeight: Math.max(560, ...))
    // configLayout đã dùng anchors.fill: parent — KHÔNG thay đổi
```

**Fix Overview** (tìm `visible: root.activeInfoPage === "Overview"` — GridLayout stats):
```qml
GridLayout {
    visible: root.activeInfoPage === "Overview"
    // ...
    Layout.topMargin: visible ? 18 : 0          // THÊM để collapse khi ẩn
```

### Xác nhận
- Mở Routing → Info → click Routes → bảng fill đầy màn hình, có thể scroll.
- Click Config → text area fill đầy, có thể scroll nội dung config.
- Switch qua lại không gây layout jump hay blank space.

---

## UI-8-07 — Nút CLI: kết nối SSH qua External Tools

### Vấn đề
`FeatureBar.qml` → `Main.qml` line ~367-370: nút CLI hiện gọi `cli.openTerminal()` (mở terminal hệ thống, không phải SSH đến thiết bị). Cần đổi để mở SSH client đến IP của active device.

### Files liên quan
- `app/UI/qml/app/Main.qml` — line ~367-370
- `app/UI/qml/content/ExternalToolsSettings.qml`
- Backend External Tools (trong `app/core/runtime.py` hoặc `app/backend/`)

### Hiện trạng (Main.qml line ~367-370):
```qml
onCliOpenRequested: {
    statusBar.showMessage("Opened new Terminal", "info")
    cli.openTerminal()
}
```

### Thực hiện

**Bước 1** — `Main.qml`: Sửa handler:
```qml
onCliOpenRequested: {
    const ip = deviceTabs.activeUid
    if (ip === "") {
        statusBar.showMessage("No active device selected for CLI.", "warning")
        return
    }
    if (typeof externalTools !== "undefined" && externalTools !== null
        && externalTools.openSshTool) {
        const result = externalTools.openSshTool(ip)
        if (result && result.ok) {
            statusBar.showMessage("Opened SSH session to " + ip, "info")
            return
        }
        statusBar.showMessage(
            result && result.message ? result.message : "SSH tool not configured. Falling back to terminal.",
            "warning")
    }
    // Fallback
    statusBar.showMessage("Opened new Terminal", "info")
    cli.openTerminal()
}
```

**Bước 2** — Backend External Tools: thêm method `openSshTool(host)`:
```python
@Slot(str, result="QVariant")
def openSshTool(self, host: str) -> dict:
    """Mở SSH client External Tool với host IP."""
    try:
        tools = self.getToolsByType("SSH")  # hoặc getToolsByType("ssh")
        if not tools:
            return {"ok": False, "message": "No SSH tool configured in External Tools."}
        tool = tools[0]  # dùng tool đầu tiên tìm được
        executable = tool.get("executable", "")
        args_template = tool.get("arguments", "{ip}")
        if not executable:
            return {"ok": False, "message": "SSH tool has no executable path."}
        args = args_template.replace("{ip}", host).replace("{host}", host)
        import subprocess, shlex
        subprocess.Popen([executable] + shlex.split(args), close_fds=True)
        return {"ok": True}
    except Exception as e:
        return {"ok": False, "message": str(e)}
```

**Bước 3** — External Tools UI: Đảm bảo tool type "SSH" có trong danh sách types. Thêm hint vào argument field placeholder: `e.g., -ssh {ip} 22` hoặc `-P 22 {ip}`.

### Xác nhận
- Cấu hình PuTTY/ssh.exe trong External Tools với Type = SSH và Arguments = `-ssh {ip} 22`.
- Chọn thiết bị connected → click CLI → PuTTY mở với IP đúng.
- Không có SSH tool → warning message, fallback terminal.

---

## UI-8-08 — External Tools: giao diện và CRUD fix

### Vấn đề
`ExternalToolsSettings.qml` (301 dòng) có form nhập liệu và danh sách tools. Các vấn đề cần kiểm tra và fix.

### Files liên quan
- `app/UI/qml/content/ExternalToolsSettings.qml` — toàn bộ file
- `app/external_tools.db` — SQLite database lưu tools
- Backend: tìm `externalTools` trong `app/core/runtime.py`

### Thực hiện

**Bước 1**: Đọc toàn bộ `ExternalToolsSettings.qml` để map flow:
- Xác định Save button và signal gọi backend
- Xác định Delete button và signal
- Xác định có `refreshTools()` sau mỗi operation không

**Bước 2**: Kiểm tra backend:
- Grep `externalTools` hoặc `ExternalTools` trong `app/core/runtime.py`
- Xác nhận `getTools()`, `saveExternalTool(data)`, `deleteExternalTool(app)` tồn tại
- Xác nhận signal `toolsChanged` được emit sau save/delete

**Bước 3**: Fix các vấn đề phổ biến:
- List không refresh → đảm bảo `root.refreshTools()` sau mỗi save/delete
- Form không clear → đảm bảo `root.clearForm()` sau save thành công
- Thiếu feedback → thêm `statusBar.showMessage(...)` sau mỗi operation

**Bước 4**: Thêm nút "Test" verify executable path:
```qml
StandardButton {
    text: "Test"
    type: "Secondary"
    enabled: executable.text.trim() !== ""
    onClicked: {
        if (typeof externalTools !== "undefined" && externalTools.testTool) {
            const r = externalTools.testTool(executable.text.trim())
            statusBar.showMessage(
                r && r.ok
                    ? "Executable found: " + executable.text
                    : "Not found: " + (r ? r.message : "unknown"),
                r && r.ok ? "success" : "error"
            )
        }
    }
}
```

Backend method `testTool(path)`:
```python
@Slot(str, result="QVariant")
def testTool(self, path: str) -> dict:
    import shutil, os
    found = shutil.which(path) or os.path.isfile(path)
    return {"ok": bool(found), "message": "" if found else f"Not found: {path}"}
```

### Xác nhận
- Add tool → xuất hiện ngay trong danh sách.
- Edit/Save tool → cập nhật trong danh sách.
- Delete tool → biến mất.
- Test với path hợp lệ → success. Path sai → error.

---

## UI-8-09 — Interface DB reference table: spacing và lỗi hiển thị

### Vấn đề
Trong `InterfaceView.qml`, bên phải là `SavedListPanel` chứa `ListView` với `spacing: 2` (quá sát). Ngoài ra, trong delegate, `Flow > Repeater` dùng `model: interfaceView.referenceTables(model)` có thể bị **property shadowing**: `model` là required property của SavedListRow delegate, nhưng cũng là property mặc định của Repeater — dẫn đến Qt resolve sai `model`.

### Files liên quan
- `app/UI/qml/interface/InterfaceView.qml` — line ~440-533
- `app/UI/components/layout/SavedListRow.qml`

### Hiện trạng (line ~447-509):
```qml
ListView {
    spacing: 2          // QUÁ SÁT

    delegate: SavedListRow {
        required property int index
        required property var model        // delegate's model data
        rowIndex: index

        RowLayout {
            ColumnLayout {
                spacing: 2                  // QUÁ SÁT

                // ...
                Flow {
                    Repeater {
                        model: interfaceView.referenceTables(model)   // AMBIGUOUS: model?
```

### Thực hiện

**Bước 1**: Tăng ListView spacing:
```qml
ListView {
    spacing: 6    // tăng từ 2 → 6
```

**Bước 2**: Tăng ColumnLayout spacing trong delegate:
```qml
ColumnLayout {
    spacing: 4    // tăng từ 2 → 4
```

**Bước 3**: Fix property shadowing trong Repeater. Thêm `id` cho `SavedListRow` và reference explicitly:
```qml
delegate: SavedListRow {
    id: ifaceRow                    // THÊM id
    required property int index
    required property var model
    rowIndex: index

    // ...
    Flow {
        Repeater {
            model: interfaceView.referenceTables(ifaceRow.model)  // EXPLICIT reference
```

**Bước 4** (tuỳ chọn): Kiểm tra `SavedListRow.qml` có `implicitHeight` cố định không. Nếu có và nhỏ hơn 70px, tăng lên để chứa đủ 3 dòng text + badges (≥ 72px).

### Xác nhận
- Mở Interface tab với ≥ 2 interfaces → rows có khoảng cách rõ ràng.
- Badges (router_iface_l3, v.v.) hiển thị đúng và không bị trống.
- Không bị clip hoặc layout sai.

---

## LOGIC-8-01 — Device Disconnected: thêm Reconnect action

### Vấn đề
`DeviceContextMenu.qml` không có action nào cho thiết bị `disconnected` (chỉ có Edit và Delete). Người dùng phải xóa và tạo lại để kết nối lại.

### Files liên quan
- `app/UI/qml/sidebar/devices/DeviceContextMenu.qml` — toàn bộ file (217 dòng)
- `app/UI/qml/panels/DevicesPanel.qml` — line ~160-197, ~362-375, ~424-431
- `app/core/database.py` — cần thêm `resetDeviceToWaiting()`

### Hiện trạng (`DeviceContextMenu.qml` line ~16-38):
```qml
readonly property bool canPing: targetStatus === "connected"
readonly property bool isWaiting: targetStatus === "waiting"
readonly property bool isConnected: targetStatus === "connected"
// THIẾU isDisconnected

signal editRequested(string ip)
signal deleteRequested(string ip)
// ... các signals khác ...
signal connecRequested(string ip)   // note: typo "connec" (không phải "connect")
// THIẾU reconnectRequested
```

### Thực hiện

**Bước 1** — `DeviceContextMenu.qml`:

Sau line `readonly property bool isConnected`:
```qml
readonly property bool isDisconnected: targetStatus === "disconnected"
```

Sau line `signal connecRequested(string ip)`:
```qml
signal reconnectRequested(string ip)
```

Thêm `ContextMenuItem` trong `menuColumn` — đặt giữa khối Connect items và divider trước Delete:
```qml
ContextMenuItem {
    visible: contextMenu.isDisconnected
    text: "Reconnect"
    shortcutText: "Ctrl+Alt+R"
    iconSource: AppAssets.resource("resources/sidebar/monitor-up.svg")
    onTriggered: {
        contextMenu.reconnectRequested(contextMenu.targetIp)
        contextMenu.close()
    }
}
```

**Bước 2** — `DevicesPanel.qml`:

Trong `DeviceContextMenu` instance (line ~366-375), thêm:
```qml
onReconnectRequested: (ip) => devicesPanel.handleReconnectDevice(ip)
```

Thêm function sau `handleDownDevDevice` (line ~172):
```qml
function handleReconnectDevice(ip) {
    const result = dbManager.resetDeviceToWaiting(ip)
    notifyOperationResult(result, "Reset to Waiting finished for " + ip + ".")
    if (result && result.ok)
        devicesPanel.reloadDevices()
}

function handleShortcutReconnect() {
    const dev = requireShortcutDevice("Reconnect")
    if (requireShortcutStatus(dev, "Reconnect", "disconnected"))
        devicesPanel.handleReconnectDevice(dev.ip)
}
```

Thêm Shortcut (sau các Shortcut hiện có, line ~424-431):
```qml
Shortcut { sequence: "Ctrl+Alt+R"; enabled: devicesPanel.deviceShortcutEnabled; onActivated: devicesPanel.handleShortcutReconnect() }
```

**Bước 3** — `app/core/database.py`:

Thêm method vào `DatabaseManager` class (hoặc appropriate mixin). Kiểm tra tên table/column trong `main.sql` trước (`t01_devices`, cột `status`, `dev`):
```python
@Slot(str, result="QVariant")
def resetDeviceToWaiting(self, ip: str) -> dict:
    """Reset thiết bị disconnected về waiting để cho phép kết nối lại."""
    try:
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(
                "UPDATE t01_devices SET status = 'waiting', dev = 0 WHERE ip = ?",
                (ip,)
            )
            conn.commit()
            if cursor.rowcount == 0:
                return {"ok": False, "message": f"Device {ip} not found.", "severity": "error"}
            return {"ok": True, "message": f"Device {ip} reset to Waiting.", "severity": "success"}
    except Exception as e:
        return {"ok": False, "message": str(e), "severity": "error"}
```

### Xác nhận
- Right-click thiết bị `disconnected` → menu có "Reconnect" option.
- Click Reconnect → thiết bị chuyển vào section Waiting trong sidebar.
- `Ctrl+Alt+R` shortcut hoạt động cho thiết bị disconnected.
- Right-click thiết bị `connected` hoặc `waiting` → không thấy "Reconnect".

---

## LOGIC-8-02 — Tự động ngắt kết nối khi đóng DeviceTab

### Hiện trạng — Logic đã được implement một phần
`DeviceTabs.qml` line ~96-101 đã có:
```qml
function closeSessionForTab(uid) {
    const host = String(uid || "").trim()
    if (host === "" || typeof cli === "undefined" || !cli.closeDeviceSession)
        return
    cli.closeDeviceSession(host)
}
```

Và `closeTab()` (line ~205-246) đã gọi `closeSessionForTab(uid)` trước khi remove tab.

### Files liên quan
- `app/UI/qml/devices/DeviceTabs.qml` — line ~96-101, ~204-246
- `app/core/runtime.py` — `cli.closeDeviceSession`

### Thực hiện — Kiểm tra và hoàn thiện

**Bước 1**: Tìm `closeDeviceSession` trong `app/core/runtime.py`:
- Verify method tồn tại
- Verify nó dừng worker/connection cho host đó
- Kiểm tra có emit signal `deviceSessionClosed(host)` không

**Bước 2**: Nếu `closeDeviceSession` chưa cập nhật DB status, thêm:
```python
# Trong closeDeviceSession():
# Sau khi dừng worker...
try:
    with self._get_db_connection() as conn:
        conn.execute(
            "UPDATE t01_devices SET status = 'waiting' WHERE ip = ?",
            (host,)
        )
        conn.commit()
except Exception:
    pass  # best-effort
self.deviceSessionClosed.emit(host)  # emit signal cho QML
```

**Bước 3**: Nếu `deviceSessionClosed` signal chưa có → thêm signal vào class:
```python
deviceSessionClosed = Signal(str)
```

**Bước 4**: Trong `Main.qml`, lắng nghe signal để reload sidebar:
```qml
Connections {
    target: typeof cli !== "undefined" ? cli : null
    // ... existing handlers ...
    function onDeviceSessionClosed(host) {
        panelSideBar.reloadDevices()
    }
}
```

**Bước 5 — UX Decision**: Đóng tab nên đưa device về `waiting` (không phải `disconnected`) vì user vẫn muốn device trong hệ thống và có thể connect lại.

### Xác nhận
- Mở tab thiết bị connected → đóng tab (X button hoặc Ctrl+W).
- Sidebar: thiết bị chuyển từ Connected → Waiting.
- Mở lại tab → có thể Connect lại bình thường.

---

## LOGIC-8-03 — Sidebar: ẩn section khi count = 0; auto-expand khi có device mới

### Vấn đề
`DeviceSection.qml` hiển thị header ngay cả khi `devices = []`. Sidebar luôn thấy 3 sections (Connected/Waiting/Disconnected) dù không có device.

### Files liên quan
- `app/UI/qml/sidebar/devices/DeviceSection.qml` — toàn bộ file (83 dòng)
- `app/UI/qml/panels/DevicesPanel.qml` — line ~338-358

### Hiện trạng (`DeviceSection.qml` line ~6-14):
```qml
Column {
    id: deviceSection

    property string sectionTitle: ""
    property bool expanded: false
    property var devices: []
    property int selectedIndex: -1
    property string displayFormat: "name"
    // THIẾU: visible binding, autoExpand property, onDevicesChanged
```

### Thực hiện

**Bước 1** — `DeviceSection.qml`: Thêm `visible` và `autoExpand`:
```qml
Column {
    id: deviceSection

    property string sectionTitle: ""
    property bool expanded: false
    property var devices: []
    property int selectedIndex: -1
    property string displayFormat: "name"
    property bool autoExpand: true      // THÊM: true = tự expand khi có device

    visible: deviceSection.devices.length > 0   // THÊM: ẩn khi rỗng

    signal deviceClicked(int index)
    signal deviceRightClicked(string ip, string status, int mouseX, int mouseY)

    width: parent.width

    // THÊM: auto-expand khi devices thay đổi từ 0 → >0
    onDevicesChanged: {
        if (deviceSection.autoExpand
                && deviceSection.devices.length > 0
                && !deviceSection.expanded) {
            deviceSection.expanded = true
        }
    }
```

**Bước 2** — `DevicesPanel.qml` (line ~338-358): Thêm `autoExpand` property cho từng section:
```qml
DeviceSection {
    id: connectedSection
    width: parent.width
    sectionTitle: "Connected"
    expanded: true
    autoExpand: true          // THÊM
    selectedIndex: devicesPanel.selectedSection === 0 ? devicesPanel.selectedIndex : -1
    displayFormat: devicesPanel.displayFormat
    onDeviceClicked: (idx) => devicesPanel.handleDeviceClicked(0, idx)
    onDeviceRightClicked: (ip, status, mx, my) => devicesPanel.handleDeviceRightClicked(0, ip, status, mx, my)
}
DeviceSection {
    id: waitingSection
    width: parent.width
    sectionTitle: "Waiting"
    expanded: true
    autoExpand: true          // THÊM
    // ...
}
DeviceSection {
    id: disconnectedSection
    width: parent.width
    sectionTitle: "Disconnected"
    expanded: false
    autoExpand: false         // THÊM: KHÔNG auto-expand disconnected
    // ...
}
```

**Bước 3** — Edge case: khi app start có sẵn devices, các sections đã expanded:
- `connectedSection.expanded: true` → ok, section visible ngay từ đầu nếu có device.
- `waitingSection.expanded: true` → ok.
- `disconnectedSection.expanded: false` → ok, user tự expand khi muốn.

### Xác nhận
- App start không có device → sidebar hiển thị trống (không thấy headers).
- Add 1 waiting device → "Waiting" section xuất hiện và expand tự động.
- Device connect → "Connected" section expand, "Waiting" section ẩn (nếu không còn waiting device).
- Device disconnect → "Disconnected" section xuất hiện nhưng collapsed.

---

## Thứ tự thực hiện đề xuất

| Ưu tiên | ID | Lý do |
|---|---|---|
| 1 | LOGIC-8-01 | Ảnh hưởng workflow — không reconnect được |
| 2 | UI-8-05 | Bug hiển thị rõ ràng trong Routing Info |
| 3 | UI-8-04 | Dễ nhất, 1 dòng xóa khỏi allItems array |
| 4 | UI-8-08 | External Tools phải fix trước khi làm CLI |
| 5 | LOGIC-8-02 | Kiểm tra xem đã implement chưa (có thể đã done) |
| 6 | LOGIC-8-03 | Sidebar UX improvement |
| 7 | UI-8-01 | Split-pane batch fix (nhanh nếu grep xong) |
| 8 | UI-8-02 | SpinBox padding tweak |
| 9 | UI-8-03 | Button text alignment tweak |
| 10 | UI-8-09 | Interface table spacing |
| 11 | UI-8-06 | Vietnamese text (grep trước, sửa sau) |
| 12 | UI-8-07 | CLI integration (phụ thuộc UI-8-08) |

