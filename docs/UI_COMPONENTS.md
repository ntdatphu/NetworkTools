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
| F6 Operations/Inspector | Tool/browser/terminal/log/transfer | Database Browser, External Tools; Console Serial/Logs/SFTP mới là item coming-soon hiển thị mờ/disabled, chưa có view. |
| F7 Settings Catalog | Navigator + setting view | Theme/Status Bar/External Tools |

F8 Topology chưa có implementation. Feature mới phải chọn family trước khi tạo layout riêng.

## 2. Component chuẩn

### `components/standard/`

- `StandardButton`: Primary/Secondary/Danger/Ghost/Icon, icon + text, tooltip và accessible metadata.
- `StandardTextField`: wrapper có label, theme, padding và alias tới `TextField`.
- `StandardNetworkField`: normalize `/24` thành subnet mask và `-/24` thành wildcard khi editing finished.
- `StandardSpinBox`, `StandardComboBox`, `StandardDropdown`.
- `StandardCheckBox`, `StandardToggleButton`, `StandardBadge`, `StatusIcon`.
- `RoutingProcessComboBox`, `RemoveIconButton`.

Lưu ý quan trọng: `StandardNetworkField` **không tự validator IPv4**. Nó chỉ normalize shorthand. Form phải gọi `ValidationUtils.js` khi stage/save và backend vẫn phải validate lại trước khi ghi DB.

### `components/layout/`

- `SplitFormPane`, `StandardSplitHandle`;
- `SavedListPanel`, `SavedListHeader`, `SavedListRow`;
- `FormLayout`, `SectionTitle`;
- `SubBar`, `SegmentTab`;
- `ContextMenuItem`, `ContextMenuDivider`.

Các form F2 thông thường dùng 320 px preferred/240 px minimum cho pane trái. Interface và ACL cần breakpoint rộng hơn; đây không phải lỗi nếu có lý do nội dung. Nên lưu split size theo feature thay vì ép một ratio cho mọi family.

### `components/base/`

- `ProcessCard`: base F4 đang được OSPF/EIGRP sử dụng.
- `IconButton`, `CloseButton`, `DialogTitleBar`, `ThemedIcon`.
- `BaseCard`: deprecated, không có consumer và đang copy implementation của `ProcessCard`.
- `BaseButton`: không có consumer.

Không thêm consumer mới cho `BaseCard`/`BaseButton`; xoá chúng khỏi `qmldir` và filesystem sau khi migration/backward-compatibility được quyết định.

## 3. Theme và design tokens

`Theme.qml` expose token từ `ColorTokens`, `SizeTokens`, `TypographyTokens`, `MotionTokens`; state light/dark/accent nằm ở `ThemeState`. Tránh hard-code màu/kích thước bên ngoài token files.

Hiện chưa có `Theme.selectionBackground`/`selectionForeground`. Selection đang dùng:

- `Theme.accentColor` ở SpinBox, Information và Routing Info;
- `Theme.accentEmphasis` ở View/Push dialog;
- foreground khác nhau theo view.

Cần bổ sung hai token selection có contrast đạt yêu cầu, rồi áp dụng cho `StandardTextField`, `StandardSpinBox`, `TextArea` và editor DB.

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
- PPP password trong Interface chưa ẩn;
- eye icons có nhưng chưa có toggle dùng chung.

## 5. Lifecycle và reload

`ContentArea` và các container Routing/DHCP/NAT lazy-load rồi cache view. Component feature nên expose API nhất quán:

```qml
function reloadData(reason) { ... }
function canLeaveWithDirtyState() { ... }
```

Router gọi `reloadData("activated")` khi người dùng quay lại feature, nhưng phải tránh ghi đè form đang dirty. Có thể reload ngay khi clean, còn khi dirty hiển thị banner “dữ liệu nguồn đã đổi”.

## 6. Accessibility và thẩm mỹ

- Giữ hit target tối thiểu, focus indicator và tooltip cho icon-only button.
- Không chỉ dùng màu để biểu đạt success/error/pending.
- `TextArea` cấu hình dài cần font monospace, search, line number, zoom và copy-all.
- Text UI hiện chủ yếu là tiếng Anh; comment/tài liệu có thể tiếng Việt. Không trộn ngôn ngữ trong cùng workflow.
- Với `pragma ComponentBehavior: Bound`, delegate phải khai báo `required property`.

Danh sách UI/UX còn thiếu và trạng thái từng mục nằm tại [beta/PENDING_CHANGES_UI_UX.md](beta/PENDING_CHANGES_UI_UX.md).
