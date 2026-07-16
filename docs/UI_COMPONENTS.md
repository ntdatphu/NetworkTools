# Giao diện và QML components của desktop app

Tài liệu này chỉ áp dụng cho frontend QML trong `app/`; nó không mô tả toàn backend dự án. QML module là `UI`, khai báo tại `app/UI/qmldir`. Component dùng qua `import UI`; asset dùng `AppAssets.resource("resources/...")`.

## 1. Interface families

| Họ | Pattern | Implementation hiện có |
|---|---|---|
| F1 Observe/Info | Dashboard/read-only | `InformationView`, `info_routing` |
| F2 Entity Workspace | Form trái + saved list phải | DHCP, NAT entity, Interface |
| F3 Policy/Rule | Header/rule editor/table | ACL, NAT ACL, Route Map |
| F4 Process Workspace | Process card + pinned header + section | OSPF, EIGRP |
| F5 Guided Setup | Dialog/form hướng dẫn | New Device, Batch New Device |
| F6 Operations/Inspector | Tool/browser/terminal/log/transfer | Database Browser, External Tools, Device Logs và SFTP; Console Serial còn coming-soon/disabled. |
| F7 Settings Catalog | Navigator + setting view | Theme/Status Bar, External Tools và Tool Catalog |

F8 Topology chưa có implementation. Feature mới phải chọn family trước khi tạo layout riêng.

## 2. Component chuẩn

### `components/standard/`

- `StandardButton`: Primary/Secondary/Danger/Ghost/Icon/Text, icon + text, tooltip, accessible metadata và focus ring Accent khi điều hướng bằng Tab. `Text` không có nền/khung ở trạng thái thường, dùng font weight bình thường và gạch chân khi hover/focus.
- `StandardTextField`: wrapper có label, theme, padding và alias tới `TextField`.
- `StandardPasswordField`: password mặc định được che, eye toggle dùng `eye.svg`/`eye-closed.svg`, giữ focus/cursor và có accessible state; đang dùng cho New Device, Batch, Add YANG và PPP.
- `StandardNetworkField`: normalize `/24` thành subnet mask và `-/24` thành wildcard khi editing finished.
- `StandardSpinBox`, `StandardComboBox`, `StandardDropdown`.
- `StandardCheckBox`, `StandardToggleButton`, `StandardBadge`, `StatusIcon`.
- `CopyButton`: nút icon Clipboard dùng chung, có feedback “Copied”, focus/accessibility; chỉ dùng trong Notification History, không hiển thị trên toast nổi.
- `ConfigTextViewer`: viewer cấu hình read-only dùng chung cho Information và Routing Config. Thanh Search/Zoom nằm dưới nội dung; `Ctrl+F` focus ô nhập, Enter/Shift+Enter đi tới kết quả sau/trước. Zoom mặc định 13 px, giới hạn 9–40 px, dùng `Ctrl+wheel` hoặc ba nút `−`, `+`, `Reset`. Gutter và nội dung cùng dùng `TextArea`/font/layout mode để giữ baseline khi zoom. `Copy All` là `StandardButton` cùng hàng action với Reload/title, còn selection hỗ trợ copy bàn phím mặc định. Syntax highlighting theo chunk dùng token màu riêng cho từng ngữ nghĩa; file trên 1.000.000 ký tự fallback về plain text.
- `CommandRegistry`: component phi hiển thị cấp Main, sở hữu shortcut theo context. Lát cắt hiện tại gồm Reload Information và navigation Devices/Database/Settings; command bị chặn khi window lock hoặc input đang focus. Save/View & Push chưa đăng ký vì thiếu dirty/capability contract chung.
- `RoutingProcessComboBox`, `RemoveIconButton`.

Quy ước icon cho action button:

- khai báo rõ `icon.source: AppAssets.resource(...)` ở consumer; không suy action từ text trong `StandardButton` vì label có thể đổi theo trạng thái;
- dùng `database-reload.svg` cho reload dữ liệu DB, `backup.svg` cho running-config backup, `push.svg` cho cả View & Push và thao tác Push cuối, `save.svg` cho Save;
- Add/New và button compact tương tự giữ text-only; không gắn `add.svg` khi label đã có dấu `+` hoặc không đủ không gian. Nút động Add/Save chỉ hiện `save.svg` ở trạng thái Save;
- Mọi action Cancel (`Cancel`, `Cancel Deletes`, `Cancel Changes`, kể cả state động Cancel/Close View) dùng `type: "Text"`, đứng đầu bên trái của action group khi có action xác nhận cùng hàng, không icon/nền/khung; label dùng font weight bình thường và gạch chân khi hover/focus. Không dùng `close.svg` cho rollback/cancel;
- `StandardButton type: "Icon"` dùng icon-only content neo `anchors.centerIn`; không dùng `checked/selected` nếu trạng thái không được phép lấy user accent (ví dụ DND trong Notification Center);
- inventory hiện tại là 52/171 `StandardButton` có icon binding; 119 nút không khai báo icon được ghi tại [beta/PENDING_CHANGES_UI_UX.md](beta/PENDING_CHANGES_UI_UX.md). Bảy nút mới của Logs/Tool Catalog giữ text-only vì chưa có asset chuyên biệt phù hợp; không tái dùng icon gần nghĩa. Hai nút điều hướng kết quả dùng chevron, hai nút Copy All dùng `clipboard-copy.svg`; ba điều khiển zoom giữ glyph/text trực tiếp. Nút xoá OSPF Network dùng `RemoveIconButton` nên không nằm trong mẫu số này.

Lưu ý quan trọng: `StandardNetworkField` **không tự validator IPv4**. Nó chỉ normalize shorthand. Form phải gọi `ValidationUtils.js` khi stage/save và backend vẫn phải validate lại trước khi ghi DB.

### `components/layout/`

- `SplitFormPane`, `StandardSplitHandle`;
- `SavedListPanel`, `SavedListHeader`, `SavedListRow`;
- `FormLayout`, `SectionTitle`;
- `SubBar`, `SegmentTab`;
- `ContextMenuItem`, `ContextMenuDivider`.

Các form F2 thông thường dùng 320 px preferred/240 px minimum cho pane trái. Interface và ACL cần breakpoint rộng hơn; đây không phải lỗi nếu có lý do nội dung. Nên lưu split size theo feature thay vì ép một ratio cho mọi family.

### External Tools master-detail

- pane trái là catalog có search, filter theo loại, section Configured/Detected và trạng thái enabled/default/source; pane phải là editor Basic → Executable → Launch preview/Arguments;
- dùng `SplitView` ngang từ 920 px, xếp dọc dưới breakpoint đó; footer Save/Cancel cố định, nội dung editor cuộn độc lập;
- detected candidate chỉ là đề xuất: hiển thị source/confidence/default association, yêu cầu review rồi mới `Add Tool`, không tự ghi DB hoặc thay default Windows;
- detected candidate chưa cấu hình dùng icon/text/badge trung tính `Theme.textSecondary`/`Theme.textDisabled`; Accent chỉ xuất hiện khi focus/selection để catalog không lấn át cấu hình đã lưu;
- executable phải đi qua native `FileDialog` và `validateExecutable`; discovery chỉ dùng App Paths, PATH/App Execution Alias, association liên quan và known locations, không scan toàn ổ;
- catalog SSH hiện nhận diện PuTTY, Xshell, MobaXterm, Tera Term và SecureCRT; fallback Installed Applications đọc `DisplayName`/`InstallLocation` theo allowlist executable, không duyệt cây filesystem;
- `{password}` không phải placeholder hợp lệ. Preview phải redact/block và bridge phải chặn cấu hình legacy trước khi tạo process.

### `components/base/`

- `ProcessCard`: base F4 đang được OSPF/EIGRP sử dụng.
- `IconButton`, `CloseButton`, `DialogTitleBar`, `ThemedIcon`.

`BaseCard` và `BaseButton` legacy đã được loại khỏi filesystem và `qmldir` ngày 2026-07-14 sau khi kiểm chứng không có consumer. Không tái tạo alias; process workspace dùng trực tiếp `ProcessCard`, action dùng `StandardButton` hoặc component chuyên biệt.

## 3. Theme và design tokens

`Theme.qml` expose token từ `ColorTokens`, `SizeTokens`, `TypographyTokens`, `MotionTokens`; state light/dark/accent nằm ở `ThemeState`. Tránh hard-code màu/kích thước bên ngoài token files.

`Theme.selectionBackground`/`selectionForeground` là contract chung cho text selection. Background theo accent ở light/dark và dùng cặp đen/trắng cố định ở high-contrast; foreground được chọn bằng WCAG relative-luminance để đạt contrast tối thiểu 4.5:1 kể cả custom accent. Hai token đã được áp dụng cho `StandardTextField`, `StandardPasswordField`, `StandardSpinBox`, Information/Route Info, View & Push và editor Database Browser. Consumer mới không dùng trực tiếp `accentColor`/`accentEmphasis` cho text selection.

## 4. Validation contract

```text
Input component
  → ký tự/normalize nhẹ
Form validateBeforeStage/Save
  → message theo field
Python slot/repository validate lại
  → transaction hoặc structured error
```

Không dùng RegExp duy nhất để khẳng định IPv4/mask hợp lệ. Regex có thể hạn chế ký tự, còn semantic validation phải kiểm tra octet, mask liên tục, prefix, quan hệ start/end và network/gateway.

Các khoảng trống hiện có:

- DHCP/NAT/Interface phần lớn chỉ kiểm tra field khác rỗng;
- backend thường trim/convert rồi ghi DB;
- credential input mới phải dùng `StandardPasswordField`; không khai báo `echoMode` rời rạc hoặc để password ở chế độ text thường.

## 5. Lifecycle và reload

`ContentArea` và các container Routing/DHCP/NAT/ACL lazy-load bất đồng bộ rồi cache view đã Ready. Incubation không còn active bị hủy để tránh tranh CPU; host switch được coalesce 16 ms và chỉ truyền host cuối xuống outer view/subtab active, nên view cache đang ẩn không query lại. `activeViewLoading` truyền qua Main tới Device Tabs: icon device của tab active được thay bằng `LoadingSpinner` màu Accent trong lúc outer/subtab loader, Information command/highlighter hoặc session đang mở. Component feature nên expose API nhất quán:

```qml
function reloadData(reason) { ... }
function canLeaveWithDirtyState() { ... }
```

Router gọi `reloadData("activated")` khi người dùng quay lại feature, nhưng phải tránh ghi đè form đang dirty. Có thể reload ngay khi clean, còn khi dirty hiển thị banner “dữ liệu nguồn đã đổi”.

## 6. Accessibility và thẩm mỹ

- Giữ hit target tối thiểu, focus indicator và tooltip cho icon-only button.
- Mọi `StandardButton` dùng `Qt.StrongFocus`; focus ring `Theme.accentColor` chỉ hiện qua `visualFocus` khi điều hướng bàn phím/Tab.
- Không chỉ dùng màu để biểu đạt success/error/pending.
- `ConfigTextViewer` đã thống nhất font monospace 13 px mặc định, toolbar dưới nội dung, search Enter/Shift+Enter, gutter `TextArea` đồng bộ baseline, ba nút zoom tới 40 px, Copy All ở header và syntax highlighting cho hai bề mặt cấu hình. 13 token màu riêng được export qua `ColorTokens`/`Theme`; runtime test khóa palette light/dark, rich-text selection, fallback file lớn và benchmark 10.000 dòng. `InformationView.reloadData(reason, force)` được ContentArea gọi khi activation và coalesce request trùng/command đang chạy.
- Text UI hiện chủ yếu là tiếng Anh; comment/tài liệu có thể tiếng Việt. Không trộn ngôn ngữ trong cùng workflow.
- Với `pragma ComponentBehavior: Bound`, delegate phải khai báo `required property`.

Danh sách UI/UX còn thiếu và trạng thái từng mục nằm tại [beta/PENDING_CHANGES_UI_UX.md](beta/PENDING_CHANGES_UI_UX.md).
