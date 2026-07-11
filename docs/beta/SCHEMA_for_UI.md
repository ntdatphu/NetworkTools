# SCHEMA for UI — NetworkTools

> Tài liệu gốc để theo dõi công việc UI/UX và logic giao diện trong `app/UI/`.
> Cập nhật lần đầu: 2026-07-10. Mọi thay đổi UI mới phải liên kết với một mã công việc bên dưới.

## 1. Mục tiêu và nguyên tắc

- Giữ `app/UI/qmldir` là hợp đồng công khai của module QML `UI`.
- Tách **design primitive**, **component tái sử dụng**, **feature adapter** và **feature screen**; không hợp nhất chỉ vì tên gần giống nhau.
- Chỉ đánh dấu hoàn thành khi có bằng chứng: QML load được, test liên quan đạt, và trạng thái tài liệu được cập nhật.
- Ưu tiên lỗi làm thao tác người dùng thất bại hoặc mất dữ liệu hơn refactor thẩm mỹ.
- Không xóa adapter mỏng như `RoutingSubBar.qml`/`RoutingPushDialog.qml` nếu adapter đang cung cấp tên miền, default hoặc API ổn định.
- Dùng token trong `Theme`; literal màu chỉ được đặt trong theme state/token hoặc dữ liệu palette.
- Form chưa có backend thật phải báo rõ “chưa hỗ trợ”, không được im lặng hoặc ném lỗi QML.

## 2. Kiến trúc đích

```text
app/UI/
├── theme/                 # token và state; không chứa business logic
├── components/
│   ├── base/              # primitive thực sự, không gắn protocol
│   ├── standard/          # control chuẩn có theme/a11y/validation contract
│   ├── layout/            # layout/card/list/table shell dùng lại
│   └── utils/             # hàm thuần; chia theo domain khi vượt ngưỡng
└── qml/
    ├── app|content|layout # application shell và navigation/lazy loading
    ├── shared/            # adapter dùng chéo feature
    └── <feature>/         # view, feature adapter và form theo domain
```

Luồng chuẩn:

```text
Navigation state -> lazy Loader -> feature View -> standard control
                                      |                  |
                                      v                  v
                               Python context API <- normalized/validated input
                                      |
                                      v
                              toast/status/notification
```

## 3. Quy ước trạng thái

| Ký hiệu | Ý nghĩa |
|---|---|
| `[ ]` | Chưa bắt đầu |
| `[-]` | Đang làm hoặc mới hoàn thành một phần |
| `[x]` | Đã thực hiện và có kiểm chứng |
| `[!]` | Bị chặn bởi backend/quyết định sản phẩm |

Mức ưu tiên: **P0** lỗi thao tác/runtime hoặc nguy cơ mất dữ liệu; **P1** hiệu năng và tính nhất quán lớn; **P2** khả dụng/bảo trì; **P3** nghiên cứu dài hạn.

## 4. Baseline đã xác minh

- 128 file QML, khoảng 19.309 dòng; 1 thư viện JavaScript dùng chung.
- QML smoke load offscreen: `ROOT_OBJECTS=1`, không có warning lúc khởi tạo mặc định.
- Test Python baseline: 5 test, 4 lỗi do console Windows CP1252 không in được Unicode trong DHCP worker; đây là lỗi có sẵn ngoài phạm vi UI.
- `ContentArea.qml` tạo đồng thời Routing, DHCP, ACL, NAT, Interface, Information, Settings và Database view dù phần lớn đang ẩn.
- Các danh sách ACL/NAT/DHCP chủ yếu đã dùng `ListView`; nhận định “tất cả row thủ công không có virtualization” trong báo cáo đầu vào là không chính xác.
- Các `*SubBar.qml` là adapter cấu hình mỏng trên `SubBar`, không phải bốn bản layout bị copy.
- `RoutingPushDialog.qml` là adapter mỏng trên `ViewPushDialog`, không phải dialog trùng lặp.
- Component không có consumer nội bộ: `BaseButton`, `SectionCard` (hiện rỗng), `StandardSideBar`, `StandardValidationDialog`.

Chi tiết bằng chứng và đánh giá nằm tại [UI_AUDIT_REPORT.md](UI_AUDIT_REPORT.md). Hệ thống pattern, đánh giá từng Feature/SubFeature và thứ tự triển khai tiếp theo lần lượt nằm tại [UI_PATTERN_SYSTEM.md](UI_PATTERN_SYSTEM.md), [FEATURE_UI_DESIGN_PLAN.md](FEATURE_UI_DESIGN_PLAN.md) và [CONTINUATION_ROADMAP.md](CONTINUATION_ROADMAP.md).

## 5. Backlog thực thi

### P0 — Correctness và contract UI/backend

- [x] **UI-P0-01 — Đồng bộ chữ ký NAT bridge**
  - Phạm vi: `app/core/database_stubs.py` và lời gọi trong `qml/nat/*Form.qml`.
  - Sửa 5 contract add: Static, Dynamic, PAT, ACL, Route Map.
  - Tiêu chí: lời gọi QML khớp số lượng/kiểu tham số; backend stub trả `false` và phát warning thay vì lỗi TypeError.

- [x] **UI-P0-02 — Lưu trạng thái cửa sổ thật sự**
  - Phạm vi: `qml/app/StatefulWindow.qml`.
  - Thay state `QtObject` chỉ sống trong RAM bằng Python `WindowSettings` dùng `QSettings`; cách này tương thích PyQt wheel hiện tại vốn thiếu dependency của QtCore QML plugin.
  - Tiêu chí: geometry/maximized/first-launch tồn tại qua hai lần chạy.

- [x] **UI-P0-03 — Chuẩn hóa nhập prefix chung**
  - Phạm vi: `ValidationUtils.js`, `StandardNetworkField.qml`, các form network/mask/wildcard trọng yếu.
  - `/24` -> `255.255.255.0`; `-/24` -> `0.0.0.255` khi hoàn tất nhập.
  - Không thay đổi text nếu input không phải shorthand hợp lệ.

- [ ] **UI-P0-04 — Validation trước mọi thao tác ghi cấu hình**
  - Bổ sung IPv4, subnet, wildcard, port, sequence/AD validation cho DHCP, ACL, NAT, Interface, Static Route.
  - Thông báo lỗi phải chỉ ra field và không gọi backend.
  - Tiêu chí: ma trận valid/invalid được test; không chỉ kiểm tra “khác rỗng”.

- [!] **UI-P0-05 — Tính năng đang mở nhưng backend là stub**
  - ACL và toàn bộ NAT cần backend thật hoặc phải chuyển màn hình sang read-only/“planned”.
  - Interface có local CRUD thật qua `DhcpSlotsMixin`, nhưng chưa có capability contract và workflow preview/push riêng; không được gộp trạng thái này với stub hoàn toàn.
  - Bị chặn bởi quyết định sản phẩm, ownership dữ liệu và implementation backend ACL/NAT.

- [ ] **UI-P0-06 — Đồng bộ registry Feature/navigation**
  - `FeatureBar.qml` ánh xạ `globalIndex: 4` thành BGP, trong khi `ContentArea.qml` ánh xạ index 4 thành VRF.
  - Tạo một feature registry duy nhất có `id`, label, device capability, route, implementation state và subfeature owner; không dùng index song song ở nhiều file.
  - Tiêu chí: không còn mapping lệch BGP/VRF; deep-link và đổi device type luôn chọn đúng feature hoặc fallback có giải thích.

### P1 — Hiệu năng và vòng đời component

- [x] **UI-P1-01 — Lazy-load màn hình cấp feature**
  - `ContentArea` chỉ tạo view khi được truy cập lần đầu, sau đó cache để không mất form đang nhập.
  - Settings và Database cũng chỉ tạo sau khi app mode tương ứng được mở.
  - Tiêu chí: startup không tạo Routing/DHCP/ACL/NAT/Interface/Information/Settings/Database trước khi truy cập.

- [x] **UI-P1-02 — Lazy-load tab con nặng**
  - Routing: Static/OSPF/EIGRP; DHCP: Pool/Excluded/Helper; NAT: 6 form.
  - Dùng “load once, preserve state”; không unload form có thay đổi chưa lưu.
  - Tiêu chí: tab chưa từng mở không gọi API reload và không tạo model/delegate.

- [ ] **UI-P1-03 — Virtualization cho collection không giới hạn**
  - Thay `Repeater` ở static routes, OSPF/EIGRP network/area/interface và routing-info bằng `ListView`/`TableView` khi dữ liệu có thể lớn.
  - Giữ `Repeater` cho tập nhỏ, hữu hạn (tab, palette, icon).
  - Tiêu chí: 1.000 row cuộn ổn định, không tạo 1.000 delegate đồng thời.

- [ ] **UI-P1-04 — Đo hiệu năng thay vì ước lượng**
  - Ghi startup time, số object QML, peak RSS, thời gian chuyển feature, FPS khi 100/1.000 row.
  - Thiết lập baseline và ngưỡng regression trong tài liệu benchmark.

### P1 — Component system và consistency

- [x] **UI-P1-05 — Xác lập contract component**
  - `StandardButton` là button chuẩn; `BaseButton` được đánh dấu legacy/deprecated.
  - `BaseCard` thực chất là process-card dùng chung OSPF/EIGRP; cần đổi tên ở hạng mục riêng, không hợp nhất với card layout mù quáng.
  - `SubBar` và `ViewPushDialog` là implementation; `*SubBar`/`RoutingPushDialog` là feature adapter hợp lệ.

- [ ] **UI-P1-06 — Dọn component chết có migration window**
  - `SectionCard` đang rỗng: hoặc triển khai contract card chuẩn, hoặc bỏ khỏi `qmldir` và xóa sau một release.
  - `StandardSideBar` trùng trách nhiệm `DevicesPanel` nhưng không được dùng: xác nhận không có consumer ngoài module rồi loại bỏ.
  - `StandardValidationDialog`: đưa vào form validation hoặc loại bỏ.
  - Tiêu chí: không còn component đăng ký nhưng rỗng/không có owner.

- [ ] **UI-P1-07 — Table/list contract chuẩn**
  - Mở rộng `SavedListPanel`/`SavedListHeader`/`SavedListRow` thành contract có empty/loading/error, keyboard selection, column metadata và delegate virtualization.
  - Không tạo `StandardTableView` chỉ để đổi tên; phải có ít nhất ACL, NAT và routing làm consumer thật.

- [ ] **UI-P1-08 — Dialog contract**
  - Giữ dialog theo use case; dùng chung shell/header/footer/focus trap.
  - Phân biệt validation dialog, confirm dialog và long-running preview/push dialog.

### P2 — UX, accessibility, responsive design

- [x] **UI-P2-01 — A11y tối thiểu cho standard control**
  - `StandardButton` có role/name/description.
  - `StandardTextField` có accessible name từ label hoặc placeholder.

- [ ] **UI-P2-02 — Keyboard và focus**
  - Tab order, Enter submit, Escape close, focus đầu tiên khi mở dialog, restore focus khi đóng.
  - Bổ sung selected/current semantics cho tab và list row.

- [ ] **UI-P2-03 — Responsive layout**
  - Loại các bảng dùng width cứng 80/110/120/140 khi cửa sổ nhỏ.
  - Thêm breakpoint: split -> stacked form/list; horizontal scroll chỉ khi dữ liệu bảng bắt buộc.
  - Kiểm tra ở 900x600, 1280x720 và 1920x1080, scale 100/150/200%.

- [ ] **UI-P2-04 — Empty/loading/error/success state đồng nhất**
  - Mọi view gọi backend phải có 4 state; nút ghi bị khóa khi request đang chạy.
  - Stub feature phải có banner rõ ràng, không giả dạng form hoạt động.

- [ ] **UI-P2-05 — Ngôn ngữ và chuỗi UI**
  - Chọn một ngôn ngữ mặc định; chuyển literal sang `qsTr()`; loại trộn Anh/Việt trong cùng workflow.
  - Tạo glossary cho thuật ngữ network không nên dịch.

- [ ] **UI-P2-06 — Visual regression và theme QA**
  - Snapshot light/dark/high-contrast cho shell, form, dialog, list/table và notification.
  - Kiểm tra contrast, disabled, hover, focus, selected, error.

### P2 — Maintainability và testability

- [ ] **UI-P2-07 — Tách file quá lớn theo trách nhiệm**
  - Ưu tiên `AclForm` (763), `SettingsView` (723), `info_routing` (646), `BatchNewDevice` (616), OSPF/EIGRP form.
  - Tách controller functions/model adapter khỏi layout; mục tiêu tham khảo < 350 dòng/file, không cắt file máy móc.

- [ ] **UI-P2-08 — Module hóa validation theo ngưỡng**
  - Hiện `ValidationUtils.js` nhỏ và chưa phải bottleneck; trước hết tăng coverage và adoption.
  - Khi vượt khoảng 250 dòng hoặc có owner tách biệt: `IpValidation.js`, `RoutingValidation.js`, `FormValidation.js`.

- [ ] **UI-P2-09 — QML lint và component tests**
  - Thêm smoke test load module, instantiate standard controls và feature views.
  - Thêm test contract QML/Python slot để phát hiện sai arity/type như NAT.

- [ ] **UI-P2-10 — Chuẩn comment trong code**
  - Comment giải thích invariant, lifecycle, backend contract; bỏ comment kể lại cú pháp hoặc lịch sử “đã sửa”.
  - Mọi TODO phải có mã `UI-Px-yy`.

### P3 — Sản phẩm và kiến trúc dài hạn

- [!] **UI-P3-01 — Hoàn thiện feature thiếu**
  - Chưa có UI thật: VLAN, VRF, STP, QoS, SNMP, NTP, AAA, MPLS, VPN, Firewall, Monitor; BGP; DHCP/NAT Info; một số Settings group; Topology.
  - CLI hiện là action mở terminal ngoài, chưa phải workspace command/console tích hợp trong `ContentArea`.
  - Cần product priority và backend contract trước khi thiết kế form.

- [ ] **UI-P3-02 — Data-driven form pilot**
  - Chỉ pilot một form ít rủi ro; schema phải mô tả type, validation, help, capability, default, secret handling và version.
  - Không chuyển toàn bộ form protocol sang JSON khi chưa chứng minh lợi ích và type safety.

- [ ] **UI-P3-03 — Notification/log console có cấu trúc**
  - Giữ `ToastManager` + `NotificationPanel` cho sự kiện ngắn.
  - Thêm task/log model có severity, source, device, timestamp, progress, copy/export và giới hạn retention.

## 6. Thứ tự triển khai chuẩn

1. Chọn item cao nhất không bị chặn.
2. Ghi `[-]`, xác định file/contract/test chịu ảnh hưởng.
3. Thay đổi nhỏ nhất giữ tương thích API.
4. Chạy QML offscreen smoke + test liên quan.
5. Kiểm tra diff và trạng thái dirty tree.
6. Cập nhật item `[x]`, bằng chứng trong mục 7 và báo cáo audit nếu kết luận thay đổi.

## 7. Nhật ký kiểm chứng

| Ngày | Hạng mục | Bằng chứng | Kết quả |
|---|---|---|---|
| 2026-07-10 | Baseline | Offscreen `engine.loadFromModule("UI", "Main")` | Pass, 1 root object |
| 2026-07-10 | Baseline test | `python -B -m unittest discover -s tests -v` | 1 pass, 4 lỗi Unicode console có sẵn |
| 2026-07-10 | UI-P0-01/02/03, UI-P1-01/02, UI-P2-01 | Offscreen smoke qua 8 view chính + 13 tab con + prefix harness | Pass, không warning |
| 2026-07-10 | Python/QML regression sau sửa | `PYTHONUTF8=1`, `QT_QPA_PLATFORM=offscreen`, compileall + unittest discover | 11/11 pass |

## 8. Definition of Done cho một feature UI

- Có owner/backend capability rõ ràng; không gọi stub như chức năng thật.
- Có loading, empty, error, success và dirty/unsaved behavior.
- Input được normalize và validate trước backend; lỗi gắn với field.
- Dùng standard control/theme token; keyboard và accessible name hoạt động.
- Collection lớn dùng virtualized view.
- Chuyển host/tab không rò state hoặc mất dữ liệu ngoài ý muốn.
- Light/dark/high-contrast và ba kích thước cửa sổ đã được kiểm tra.
- QML smoke/lint/test pass; docs và `qmldir` đồng bộ.

## 9. Tài liệu triển khai tiếp theo

- [README.md](README.md): mục lục và quy tắc duy trì bộ tài liệu beta.
- [UI_PATTERN_SYSTEM.md](UI_PATTERN_SYSTEM.md): các họ giao diện dùng chung và contract xuyên feature.
- [FEATURE_UI_DESIGN_PLAN.md](FEATURE_UI_DESIGN_PLAN.md): hiện trạng và đề xuất chi tiết cho từng Feature/SubFeature.
- [CONTINUATION_ROADMAP.md](CONTINUATION_ROADMAP.md): thứ tự triển khai, dependency, quality gate và tiêu chí nghiệm thu.
- [changes.md](changes.md): diff giữa `frontend-beta` và nhánh refactor; dùng làm baseline thay đổi, không thay cho roadmap.
