# QML Analysis

Tài liệu này tóm tắt cấu trúc QML hiện tại của `NetworkTools` theo source trên nhánh `main`.

## Nguồn tham chiếu

Các file QML được đăng ký trong:

```text
frontend/CMakeLists.txt
```

QML module:

```text
NetworkTools
```

Khi thêm, xóa hoặc di chuyển QML file, cần cập nhật `qt_add_qml_module(... QML_FILES ...)`.

## Cấu trúc QML chính

```text
frontend/
├── qml/
├── components/
└── theme/
```

## `theme/`

Vai trò:

- Chứa theme singleton.
- Chứa UI state.
- Chứa design tokens.

Nhóm file chính:

```text
theme/Theme.qml
theme/state/ThemeState.qml
theme/state/UiState.qml
theme/tokens/SizeTokens.qml
theme/tokens/TypographyTokens.qml
theme/tokens/ColorTokens.qml
theme/tokens/MotionTokens.qml
```

Các file này được khai báo singleton trong CMake. Khi đổi vị trí hoặc đổi tên, phải cập nhật `set_source_files_properties(...)` và `QML_FILES`.

## `components/`

Vai trò:

- Chứa component QML dùng lại.
- Giảm lặp UI.
- Chuẩn hóa nút, input, panel, layout, validation, badge, split handle.

Nhóm chính:

```text
components/base/
components/standard/
components/layout/
components/utils/
```

### `components/base/`

Ví dụ:

```text
BaseCard.qml
BaseButton.qml
IconButton.qml
SectionCard.qml
```

Vai trò: component nền tảng, dùng để xây dựng các component chuẩn/phức tạp hơn.

### `components/standard/`

Ví dụ:

```text
StandardButton.qml
StandardTextField.qml
StandardComboBox.qml
StandardSpinBox.qml
StandardCheckBox.qml
StandardValidationDialog.qml
StandardDropdown.qml
StandardBadge.qml
StandardSideBar.qml
```

Vai trò: các control chuẩn, dùng xuyên suốt app.

### `components/layout/`

Ví dụ:

```text
FormLayout.qml
SavedListHeader.qml
SavedListPanel.qml
SavedListRow.qml
SegmentTab.qml
SplitFormPane.qml
StandardSplitHandle.qml
SubBar.qml
```

Vai trò: layout form, danh sách, split view, sub navigation.

### `components/utils/`

Ví dụ:

```text
ValidationUtils.js
```

Vai trò: logic validation dùng lại trong QML.

## `qml/app/`

Vai trò:

- Root UI.
- Điều phối cửa sổ chính.
- Kết nối các panel chính, sidebar, content area, status bar.

File chính:

```text
Main.qml
StatefulWindow.qml
```

`Main.qml` được load bằng:

```cpp
engine.loadFromModule("NetworkTools", "Main");
```

## `qml/panels/`

Vai trò:

- Chứa các panel cấp cao.

File chính:

```text
DevicesPanel.qml
LogsAlertsPanel.qml
PanelSideBar.qml
SettingsPanel.qml
```

## `qml/layout/`

Vai trò:

- Layout global của app.
- Thanh điều hướng/trạng thái.

File chính:

```text
ActivityBar.qml
ActivityBarItem.qml
StatusBar.qml
```

## `qml/sidebar/`

Vai trò:

- Sidebar thiết bị.
- Tìm kiếm, hiển thị, thao tác với thiết bị.
- Form thêm/sửa thiết bị và YANG config.

Nhóm chính:

```text
qml/sidebar/header_search/
qml/sidebar/devices/
qml/sidebar/new_device/
```

## `qml/devices/`

Vai trò:

- Quản lý tab theo thiết bị.

File chính:

```text
DeviceTabs.qml
DeviceTabItem.qml
```

## `qml/content/`

Vai trò:

- Điều phối nội dung chính theo thiết bị/tính năng đang chọn.

File chính:

```text
ContentArea.qml
WelcomeScreen.qml
LogsAlertsView.qml
SettingsView.qml
```

## `qml/interface/`

Vai trò:

- Giao diện cấu hình interface.

File chính:

```text
InterfaceView.qml
```

## `qml/routing/`

Vai trò:

- Giao diện routing.
- Chia theo Static, OSPF, EIGRP.

Nhóm chính:

```text
qml/routing/RoutingView.qml
qml/routing/RoutingSubBar.qml
qml/routing/static/
qml/routing/ospf/
qml/routing/eigrp/
```

## `qml/dhcp/`

Vai trò:

- Giao diện DHCP pool và excluded address.

File chính:

```text
DhcpView.qml
DhcpSubBar.qml
DhcpPoolForm.qml
DhcpExcludedForm.qml
```

## `qml/acl/`

Vai trò:

- Giao diện ACL.
- Hỗ trợ nhiều loại ACL input.

File chính:

```text
AclView.qml
AclForm.qml
AclSubBar.qml
AclRuleRow.qml
AclRuleInputStandard.qml
AclRuleInputExtended.qml
AclRuleInputDynamic.qml
AclRuleInputReflexive.qml
AclRuleInputMac.qml
```

## `qml/nat/`

Vai trò:

- Giao diện NAT.
- Hỗ trợ static NAT, dynamic NAT, PAT, NAT interface, NAT ACL, route map.

File chính:

```text
NatView.qml
NatSubBar.qml
NatStaticForm.qml
NatDynamicForm.qml
NatPatForm.qml
NatInterfaceForm.qml
NatAclForm.qml
NatRouteMapForm.qml
```

## `qml/shared/`

Vai trò:

- Component dùng chung ở cấp app.

File chính:

```text
CustomAlert.qml
ResizeHandles.qml
ToastManager.qml
NotificationPanel.qml
```

## Tương tác QML với C++

Các object C++ được inject sang QML:

```text
dbManager
cli
networkMonitor
```

Nguyên tắc:

- UI không truy cập database trực tiếp.
- UI gọi qua `dbManager` hoặc repository exposed methods.
- Tác vụ terminal đi qua `cli`.
- Trạng thái mạng/runtime đi qua `networkMonitor`.

## Quy tắc bảo trì QML

1. Thêm file QML mới thì cập nhật `frontend/CMakeLists.txt`.
2. Thêm asset mới thì cập nhật `RESOURCES`.
3. Không hard-code màu/kích thước nếu đã có token trong `theme/`.
4. Ưu tiên dùng component trong `components/standard/` và `components/layout/`.
5. Tránh tạo component trùng chức năng.
6. Khi đổi tên module hoặc URI `NetworkTools`, phải rà toàn bộ import và resource path.
