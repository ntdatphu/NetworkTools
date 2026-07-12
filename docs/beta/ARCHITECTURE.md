# ARCHITECTURE.md — Kiến trúc kỹ thuật dự án NetworkTools

Ngày cập nhật: 2026-07-12  
Workspace: `r:\NetworkTools\`  
Mục đích: Cung cấp đủ ngữ cảnh kỹ thuật để AI mới hiểu và chỉnh sửa đúng mà không cần đọc hết toàn bộ codebase.

---

## 1. Tổng quan kiến trúc

NetworkTools là ứng dụng desktop Qt/QML + Python (PySide6) theo mô hình:

```
[QML Frontend] ←→ [Python Backend via QObject/Slot] ←→ [SQLite DB]
                         ↓ (nếu có)
                   [CLI/SSH Worker → Thiết bị thật]
```

**Runtime**: `app/core/runtime.py` — khởi tạo toàn bộ context: tạo `DatabaseManager`, `ExternalTools`, `CLI`, expose qua `QQmlApplicationEngine.rootContext().setContextProperty(...)`.

**App entry**: `app/main.py` → `app/UI/qml/app/Main.qml`.

---

## 2. Cây thư mục quan trọng

```
r:\NetworkTools\
├── app/
│   ├── main.py                  # Entry point Python
│   ├── core/
│   │   ├── runtime.py           # Khởi tạo backend: DB, CLI, ExternalTools
│   │   ├── database.py          # DatabaseManager(QObject) — CRUD chính
│   │   ├── database_stubs.py    # StubSlotsMixin — placeholder method (trả về rỗng)
│   │   ├── acl_slots.py         # AclSlotsMixin — CRUD cho ACL
│   │   ├── nat_slots.py         # NatSlotsMixin — CRUD cho NAT
│   │   ├── dhcp_slots.py        # DhcpSlotsMixin — CRUD cho DHCP
│   │   ├── background_task.py   # Quản lý background task
│   │   └── view_push.py         # Push config đến thiết bị
│   ├── backend/
│   │   ├── acl/                 # Repository ACL: acl_db.py, common.py
│   │   ├── nat/                 # Repository NAT
│   │   └── dhcp/                # Repository DHCP
│   └── UI/
│       ├── qml/                 # Toàn bộ QML frontend
│       ├── theme/               # Design tokens
│       ├── components/          # Reusable QML components
│       └── resources/           # SVG icons, assets
├── docs/
│   └── beta/
│       ├── schema.md            # Tiến độ + roadmap (nguồn sự thật)
│       ├── CHANGES_PENDING.md   # Đặc tả chi tiết 12 issues cần fix
│       └── ARCHITECTURE.md     # File này
└── app/UI/main_numbered_tables.sql  # Toàn bộ schema SQLite
```

---

## 3. QML Frontend — cấu trúc file

### 3.1 Entry point

```
app/UI/qml/app/Main.qml          # Root window (StatefulWindow)
app/UI/qml/app/StatefulWindow.qml # Window với save/restore geometry
```

`Main.qml` chứa:
- `ActivityBar` — thanh icon bên trái, chọn mode (devices/settings/database)
- `SplitView` — chia Sidebar | Content
- `PanelSideBar` — sidebar đa năng (devices, settings, database browser, open editors)
- `DeviceTabs` — tab bar thiết bị (nằm trong content area)
- `FeatureBar` — sub-bar chọn feature (Routing, DHCP, ACL, NAT, Interface...)
- `ContentArea` — vùng nội dung chính, chứa tất cả views
- `StatusBar` — thanh status phía dưới

### 3.2 Sidebar (Panel Side Bar)

```
app/UI/qml/panels/
├── PanelSideBar.qml             # Controller chính của sidebar
├── DevicesPanel.qml             # Giao diện quản lý thiết bị
├── SettingsPanel.qml            # Giao diện Settings navigator
└── OpenEditorsPanel.qml         # Giao diện "Open Editors" (danh sách tabs)

app/UI/qml/sidebar/devices/
├── DeviceSection.qml            # Section (Connected/Waiting/Disconnected)
├── DeviceContextMenu.qml        # Right-click menu cho device
├── DeviceItem.qml               # Một dòng device trong list
└── ...
```

### 3.3 Device tabs

```
app/UI/qml/devices/
├── DeviceTabs.qml               # Tab bar + tab model + logic navigate/open/close
└── DeviceTabItem.qml            # Một tab item trong tab bar
```

**DeviceTabs.qml state model**: `tabModel` (ListModel) chứa các object:
```js
{
  uid: "192.168.1.1",       // IP = unique ID
  title: "Router-01",       // Display name
  isActive: false,
  deviceType: "router",
  status: "connected",      // "connected" | "waiting" | "disconnected"
  sessionState: "pending",  // "pending" | "opening" | "connected" | "error" | "closed"
  fMain: 0,                 // Active main feature index (Routing=0, DHCP=1, ...)
  fText: -1                 // Active text feature index (-1 = none)
}
```

### 3.4 Content Area

```
app/UI/qml/content/
├── ContentArea.qml              # Router chính — điều phối loading views
├── SettingsView.qml             # Toàn bộ settings UI
├── ExternalToolsSettings.qml    # External tools form + list
├── InformationView.qml          # Thông tin hệ thống
├── DatabaseBrowserView.qml      # Browser cho toàn bộ DB
└── WelcomeScreen.qml            # Màn hình chào

app/UI/qml/routing/             # Views cho Routing feature
app/UI/qml/dhcp/                # Views cho DHCP feature
app/UI/qml/acl/                 # Views cho ACL feature
app/UI/qml/nat/                 # Views cho NAT feature
app/UI/qml/interface/           # Views cho Router Interface feature
app/UI/qml/feature/             # FeatureBar.qml
```

### 3.5 Component library

```
app/UI/components/
├── base/
│   ├── BaseButton.qml           # Nút cơ bản (không dùng trực tiếp)
│   ├── BaseCard.qml             # Deprecated, dùng ProcessCard thay
│   ├── ProcessCard.qml          # Card cho F4 (OSPF/EIGRP process)
│   ├── IconButton.qml           # Nút chỉ icon (kích thước tùy chỉnh)
│   ├── CloseButton.qml          # Nút X đóng
│   ├── DialogTitleBar.qml
│   └── ThemedIcon.qml           # Wrapper cho SVG icon với màu
├── standard/
│   ├── StandardButton.qml       # Button chuẩn (Primary/Secondary/Danger/Ghost/Icon)
│   ├── StandardTextField.qml    # Input text field chuẩn
│   ├── StandardSpinBox.qml      # SpinBox chuẩn
│   ├── StandardComboBox.qml     # ComboBox chuẩn
│   ├── StandardDropdown.qml     # Dropdown (custom popup)
│   ├── StandardCheckBox.qml     # CheckBox chuẩn
│   ├── StandardNetworkField.qml # TextField chuyên cho IP/subnet
│   ├── StandardToggleButton.qml # Toggle button
│   ├── StandardBadge.qml        # Badge nhỏ (count, status)
│   └── RemoveIconButton.qml     # Nút X nhỏ xóa item
└── layout/
    ├── SplitFormPane.qml        # Pane trái trong SplitView (F2/F3)
    ├── SavedListPanel.qml       # Pane phải trong SplitView (danh sách đã lưu)
    ├── SavedListRow.qml         # Một dòng trong SavedListPanel
    ├── SavedListHeader.qml      # Header của SavedListPanel
    ├── FormLayout.qml           # Layout cho form nhập liệu
    ├── SubBar.qml               # Sub-bar navigation (tab routing/dhcp/acl...)
    ├── SectionTitle.qml         # Tiêu đề section trong form
    ├── SegmentTab.qml           # Tab nút trong sub-bar
    ├── ContextMenuItem.qml      # Một item trong context menu
    └── ContextMenuDivider.qml   # Divider trong context menu
```

### 3.6 Theme / Design tokens

```
app/UI/theme/
├── Theme.qml                    # Singleton — expose tất cả tokens
├── tokens/
│   ├── SizeTokens.qml           # Kích thước cố định (spacing, radius, icon size...)
│   ├── ColorTokens.qml          # Màu sắc (light/dark mode)
│   ├── TypographyTokens.qml     # Font family, sizes
│   └── MotionTokens.qml         # Animation duration
└── state/
    ├── ThemeState.qml           # Dark/light mode state
    └── StatusBarState.qml
```

**Các token quan trọng**:
```qml
Theme.spacing2  = 2px
Theme.spacing4  = 4px
Theme.spacing8  = 8px
Theme.spacing12 = 12px
Theme.spacing16 = 16px
Theme.spacing24 = 24px
Theme.spacing32 = 32px

Theme.fontSizeSmall  = 11px
Theme.fontSizeNormal = 13px
Theme.fontSizeLarge  = 15px

Theme.itemHeight = 32px  (chiều cao standard control)
Theme.radiusSmall = 4px
Theme.radiusMedium = 6px
```

---

## 4. Backend Python — cấu trúc

### 4.1 DatabaseManager (core/database.py)

**Inheritance chain**:
```python
class DatabaseManager(DhcpSlotsMixin, AclSlotsMixin, NatSlotsMixin, StubSlotsMixin, QObject):
    pass
```

Tất cả method `@Slot` được expose sang QML qua `setContextProperty("dbManager", db_manager)`.

**Pattern chung của Slot**:
```python
@Slot(str, result="QVariant")
def getThings(self, host_ip: str) -> list:
    """Return list of dicts from DB."""
    with self._get_connection() as conn:
        rows = conn.execute("SELECT ... WHERE ip = ?", (host_ip,)).fetchall()
        return [dict(r) for r in rows]

@Slot("QVariantMap", result="bool")
def saveThing(self, data: dict) -> bool:
    """Save/update a record. Return True on success."""
    ...
```

### 4.2 StubSlotsMixin (core/database_stubs.py)

Chứa tất cả method chưa implement thật. Method stub trả về `[]` hoặc `False`. Khi implement thật, method cùng tên ở Mixin thật (DhcpSlotsMixin, AclSlotsMixin, v.v.) sẽ override vì thứ tự MRO (trái → phải).

### 4.3 Runtime (core/runtime.py)

Expose các context properties sang QML:
```python
ctx = engine.rootContext()
ctx.setContextProperty("dbManager",      db_manager)
ctx.setContextProperty("cli",            cli_manager)
ctx.setContextProperty("externalTools",  external_tools_manager)
ctx.setContextProperty("themeSettings",  theme_settings)
ctx.setContextProperty("statusBarSettings", statusbar_settings)
# UiState, AppAssets, v.v.
```

---

## 5. Patterns quan trọng

### 5.1 SplitView form pattern (F2 — Entity Workspace)

```qml
SplitView {
    orientation: Qt.Horizontal
    handle: StandardSplitHandle {}

    // LEFT: Form nhập liệu
    SplitFormPane {
        SplitView.preferredWidth: 340
        SplitView.minimumWidth: 260

        // Nội dung form: Text (title), Rectangle (divider),
        // StandardTextField, StandardComboBox, StandardSpinBox,
        // StandardButton (Save/Clear)
    }

    // RIGHT: Danh sách đã lưu
    SavedListPanel {
        SplitView.fillWidth: true
        title: "Database reference"
        count: model.count
        // ListView với SavedListRow delegate
    }
}
```

### 5.2 Process card pattern (F4 — OSPF/EIGRP)

```qml
// Sử dụng ProcessCard (đã rename từ BaseCard)
ProcessCard {
    // Section tabs, pinned header, data binding
}
```

### 5.3 Device Context Menu signal pattern

`DeviceContextMenu.qml` emit signals → `DevicesPanel.qml` connect:
```qml
// DeviceContextMenu.qml
signal editRequested(string ip)
signal deleteRequested(string ip)
signal pingRequested(string ip)
signal connecRequested(string ip)  // typo: "connec" not "connect"
signal upDevRequested(string ip)
signal downDevRequested(string ip)
// TODO: signal reconnectRequested(string ip)

// DevicesPanel.qml
DeviceContextMenu {
    onEditRequested:   (ip) => devicesPanel.handleEditDevice(ip)
    onDeleteRequested: (ip) => devicesPanel.handleDeleteDevice(ip)
    // ...
}
```

### 5.4 Backend operation result pattern

Tất cả slot write (save/delete/update) trả về `dict`:
```python
{"ok": True,  "message": "Saved successfully.", "severity": "success"}
{"ok": False, "message": "Device not found.",   "severity": "error"}
```

QML đọc result:
```qml
const result = dbManager.doSomething(data)
if (result && result.ok) {
    statusBar.showMessage(result.message || "Done.", "success")
} else {
    statusBar.showMessage(result && result.message ? result.message : "Error.", "error")
}
```

### 5.5 Reconnect pattern (DevicesPanel.qml)

`DevicesPanel.qml` có các helper function:
```qml
function notifyOperationResult(result, fallbackMessage) { ... }
function requireShortcutDevice(actionName) { ... }  // trả về device đang chọn, hoặc null
function requireShortcutStatus(dev, actionName, expectedStatus) { ... }
function reloadDevices() { ... }
```

---

## 6. Database schema (tóm tắt)

File chính: `app/UI/main_numbered_tables.sql`

**Bảng thiết bị**:
```sql
t01_devices (
    id INTEGER PRIMARY KEY,
    ip TEXT UNIQUE,
    name TEXT,
    device_type TEXT,  -- "router" | "switch" | "firewall" | ...
    status TEXT,       -- "connected" | "waiting" | "disconnected"
    dev INTEGER        -- 0 = thật, 1 = dev mode (giả lập)
)
```

**Quan hệ**: Tất cả bảng feature đều có cột `host TEXT` trỏ về `t01_devices.ip`.

**Pattern bảng feature** (ví dụ ACL):
```sql
ACL_DB (
    acl_id INTEGER PRIMARY KEY,
    host TEXT,                     -- IP thiết bị
    acl_name TEXT,
    acl_type TEXT,                 -- "Standard" | "Extended" | ...
    success INTEGER DEFAULT 0      -- 0=pending, 1=pushed, -1=failed
)
standard_acl_rules (
    rule_id INTEGER PRIMARY KEY,
    acl_id INTEGER REFERENCES ACL_DB(acl_id),
    sequence_number INTEGER,
    permit_deny TEXT,
    source_ip TEXT,
    source_wildcard TEXT
)
```

---

## 7. Signal/Slot naming conventions

| Pattern | Ví dụ |
|---|---|
| QML signal từ component con | `signal saveRequested(...)` |
| QML signal từ Panel → Main | `signal deviceSelected(string ip, string name, ...)` |
| Python Slot sang QML | `@Slot(str, result="QVariant") def getXxx(self, host): ...` |
| Python Signal → QML Connections | `xChanged = Signal(str)` → `function onXChanged(x) {...}` |
| Context property tên | `dbManager`, `cli`, `externalTools`, `themeSettings` |

---

## 8. UI module system (qmldir)

```
app/UI/qmldir                    # Module "UI" — import UI
```

Tất cả QML files trong `app/UI/` được expose qua module `UI`. Import trong QML:
```qml
import UI
// Sử dụng: Theme.spacing8, AppAssets.resource(...), SizeTokens.xxx, ...
```

`AppAssets.resource(path)` trả về URL đến file resource, dùng cho icon:
```qml
iconSource: AppAssets.resource("resources/general/chevron-up.svg")
```

---

## 9. Lưu ý khi chỉnh sửa

1. **pragma ComponentBehavior: Bound** — hầu hết QML files có pragma này. Nghĩa là: delegate của `Repeater`/`ListView` phải dùng `required property` để access model data, không được dùng implicit scope. Ví dụ:
   ```qml
   delegate: MyItem {
       required property var model    // ĐÚNG
       // Không được: model.someField  (nếu không có required property)
   }
   ```

2. **Layout.fillWidth vs anchors.fill** — không mix 2 loại trong cùng một item. Nếu parent là `ColumnLayout`/`RowLayout`, dùng `Layout.*`. Nếu parent là `Rectangle`/`Item`, dùng `anchors.*`.

3. **visible: false trong ColumnLayout** — item có `visible: false` **vẫn chiếm không gian** trong ColumnLayout. Dùng thêm `Layout.maximumHeight: visible ? 99999 : 0` để collapse.

4. **SplitView.preferredWidth** — chỉ là giá trị ban đầu, user có thể kéo. Sau khi kéo, giá trị không reset về `preferredWidth` trừ khi force set.

5. **Theme singleton** — import `UI` rồi dùng `Theme.xxx`. Không dùng hardcoded values.

6. **Python DB connection** — dùng `with self._get_connection() as conn:` (context manager), không commit manually trừ khi cần. Connection pool hoặc thread-safe pattern đã được xử lý trong `_get_connection()`.

7. **Slot return type** — `result="QVariant"` cho phép return dict/list. `result="bool"` chỉ cho bool. Luôn check type kỳ vọng trong QML (`result && result.ok`).

