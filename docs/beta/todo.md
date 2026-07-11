# Kế hoạch UI beta thống nhất — NetworkTools

Ngày cập nhật: 2026-07-12

Baseline code: `refactor/frontend-beta` tại `f27ad97`.

Tài liệu này là nguồn sự thật duy nhất cho hiện trạng UI, nguyên tắc thiết kế, capability feature, backlog và roadmap. Báo cáo so sánh Git riêng nằm tại [change.md](change.md).

## 1. Mục tiêu và nguyên tắc điều hành

Mục tiêu là đưa UI beta từ trạng thái có nền tảng tốt hơn nhưng capability chưa đồng đều tới các vertical slice có thể đánh giá end-to-end. Ưu tiên theo thứ tự:

1. UI không được hứa một thao tác mà backend không hỗ trợ.
2. Sửa identity/navigation, validation và state contract trước khi mở rộng số lượng màn hình.
3. Đo hiệu năng trước khi kết luận lazy-load hoặc virtualization đã đủ tốt.
4. Pilot shared pattern trên feature đã có backend thật trước khi tạo abstraction lớn.
5. Chỉ mở feature phụ thuộc sau khi stable ID, reference integrity và capability contract đã sẵn sàng.

Quy tắc bắt buộc:

- Phân biệt rõ **có UI**, **local CRUD**, **preview** và **push end-to-end**.
- Save chỉ ghi local/draft; Preview không mutate; Push chỉ được enable khi có controller thật.
- Mỗi feature/subfeature mới phải có owner dữ liệu, capability, validation matrix, state model và test plan.
- Không dùng index mảng làm feature identity; không suy capability bằng sự tồn tại của method.
- Không tạo component chung khi chưa có ít nhất hai consumer thật; table/policy/process abstraction cần ba consumer hoặc một pilot chứng minh contract.
- Khi code làm một kết luận dưới đây sai, cập nhật tài liệu này trong cùng PR.

## 2. Hiện trạng đã xác minh

### Đã có trong nhánh hiện tại

| Hạng mục | Trạng thái | Bằng chứng |
|---|---|---|
| Lazy-load cấp feature | Hoàn thành | `ContentArea.qml` dùng `Loader` cho Routing, DHCP, ACL, NAT, Interface, Information, Settings và Database Browser. |
| Lazy-load tab nặng | Hoàn thành | Routing, DHCP và NAT load lần truy cập đầu tiên rồi cache instance đã mở. |
| Chuẩn hóa network input | Hoàn thành một phần | `StandardNetworkField` hỗ trợ `/24` cho subnet và `-/24` cho wildcard; đã dùng ở các form trọng yếu. |
| NAT bridge arity | Hoàn thành | Chữ ký 5 NAT stub khớp lời gọi QML và có test reflection. |
| Window persistence | Hoàn thành | `WindowSettings` dùng `QSettings` cho geometry/maximized/first launch. |
| A11y control nền | Hoàn thành một phần | `StandardButton` và `StandardTextField` có role/name/description cơ bản. |
| Smoke/contract test | Hoàn thành một phần | Có QML smoke, harness prefix, WindowSettings và NAT arity tests. |

### Rủi ro và giới hạn hiện tại

| Mức | Vấn đề | Hệ quả |
|---|---|---|
| P0 | `FeatureBar` index 4 là BGP còn `ContentArea` index 4 là VRF. | Navigation có thể dẫn đến feature sai. |
| P0 | ACL và toàn bộ write path NAT vẫn là `StubSlotsMixin`. | Form có thể trông hoàn chỉnh nhưng không có persistence/push. |
| P0 | Chưa có capability API theo feature/device. | UI chưa thể hiện unavailable/read-only/local-only nhất quán. |
| P0 | Validation submit chưa đầy đủ. | Invalid/cross-field input có thể đi tới backend. |
| P1 | Lazy-load/cache chưa có benchmark. | Chưa biết startup, first-open, RSS và phiên mở nhiều view cải thiện bao nhiêu. |
| P1 | Static Route, OSPF/EIGRP và Routing Info vẫn có collection lớn cần đánh giá virtualization. | Rủi ro jank/memory khi nhiều row. |
| P2 | Thiếu keyboard/focus, responsive/DPI, `qsTr()` và visual regression có hệ thống. | Khả dụng và chất lượng UI chưa đủ cho release rộng. |
| P2 | `SectionCard`, `StandardValidationDialog`, `StandardSideBar` và tên `BaseCard` chưa có migration hoàn chỉnh. | Taxonomy component còn khó hiểu và có nợ bảo trì. |

## 3. Contract UI bắt buộc

### Identity, capability và action

Mỗi page phải công bố feature/subfeature, host, device type, connection state, capability, freshness và dirty/pending count. Capability dùng các mức:

| Mức | Hành vi |
|---|---|
| `unavailable` | Hiện lý do; không cho thao tác ghi. |
| `read-only` | Hiện dữ liệu; khóa local write/preview/push. |
| `local-only` | Cho local CRUD; nói rõ chưa có preview/push. |
| `preview` | Cho Save local và Preview; không cho Push. |
| `push` | Cho toàn bộ action theo permission và confirmation. |

View state chung: `unavailable`, `loading`, `empty`, `ready`, `dirty`, `saving`, `pending-push`, `pushing`, `stale`, `error`. Empty không được dùng để che một backend stub.

### Validation, secret và reference

- Normalize nhẹ khi kết thúc nhập; validate đầy đủ trước backend.
- Lỗi gắn với field và có summary khi nhiều lỗi; invalid submit không gọi backend.
- Phải có validation IPv4/subnet/wildcard/port/range/sequence và cross-field phù hợp domain.
- Secret phải masked, reveal tạm thời, không vào toast/log/history.
- Interface, ACL, route-map, policy và VRF dùng selector stable ID có missing-reference state, không dùng text tự do khi có model.

### Responsive, keyboard và accessibility

- Kiểm tra compact `900x600`, standard `1280x720`, wide `1920x1080` ở scale 100/150/200%.
- Split view chuyển stacked khi compact; table có `minimum`, `weight`, `priority` và quy tắc hide/stack.
- Tab order theo workflow; Enter/Escape có ngữ nghĩa an toàn; dialog restore focus; list/tab công bố selected/current.

## 4. Pattern family và phạm vi dùng

| Pattern | Dùng cho | Contract chính |
|---|---|---|
| F1 Observe & Diagnose | Information, Routing/NAT/DHCP Info, Monitor | Header, freshness, filter, metrics, virtualized table/inspector. |
| F2 Entity Workspace | DHCP, Interface, NAT Static/Pool | List/detail, selection, dirty guard, editor action bar. |
| F3 Policy Workspace | ACL, Firewall, QoS, NAT ACL/Route Map | Ordered rule table, rule editor, sequence/diagnostics/reference. |
| F4 Process Workspace | OSPF, EIGRP, BGP, VRF | Process context, section navigation, stable process identity. |
| F5 Relationship/Topology | Topology, STP, MPLS, VPN relationship | List/table fallback trước graph/canvas. |
| F6 Guided Setup | New Device, VPN/AAA/SNMP onboarding | Step validation, resume/review, safe defaults. |
| F7 Inspector/Operations | CLI, Database, task/log, config diff | Search/filter, source/timestamp, copy/export, permission. |
| F8 Settings Catalog | Theme, General, Advanced, External Tools | Category navigation, search, live preview/reset, scope/restart state. |

Không ép các feature vào một layout chung. Sự thống nhất nằm ở header, capability, state, validation, action semantics, responsive, accessibility và feedback; body chọn pattern theo workflow.

## 5. Capability matrix hiện tại

| Feature | Capability thực tế | Pattern đích | Ưu tiên |
|---|---|---|---:|
| Device workspace | Local device CRUD + terminal session | F2 + F6 | P1 |
| Information | Read từ live session hoặc backup | F1 + F7 | P1 |
| CLI | Mở terminal ngoài app | F7 | P3 |
| Interface | Local CRUD qua `DhcpSlotsMixin`; chưa có push owner | F2 | P0/P1 |
| Routing Info | Read | F1 + F7 | P1 |
| Static Routing | Local CRUD + preview/push | F2 | P1 |
| OSPF / EIGRP | Local CRUD + preview/push | F4 | P1 |
| BGP | Tab disabled | F4 + F1 + F3 | P2 |
| DHCP Pool / Excluded / Helper | Local CRUD + preview/push | F2 | P1 |
| DHCP Info | Disabled | F1 | P2 |
| ACL | UI; persistence stub | F3 | P0/P1 |
| NAT | UI; persistence stub | F2 + F3 + F1 | P0/P1 |
| VLAN / VRF / STP | Chưa có vertical slice | F2/F4/F5 | P2 |
| QoS / SNMP / NTP / AAA | Chưa có vertical slice | F2/F3/F4/F6 | P3 |
| MPLS / VPN / Firewall | Chưa có vertical slice | F3/F4/F5/F6 | P3 |
| Monitor / Topology | Chưa có telemetry/topology model | F1/F5 | P2/P3 |
| Settings | Theme/External Tools có phần thật; nhóm khác placeholder | F8 | P1/P2 |
| Database Browser | Read/edit local DB | F7 | P1 |
| Notification | Toast + history cơ bản | F1/F7 task-log | P2 |

## 6. Backlog và roadmap

### Phase A — Sửa sự thật hệ thống (P0)

1. **UI-P0-06 / R0-01:** Tạo Feature Registry có stable ID; bỏ mapping index song song; chốt BGP dưới Routing và VRF top-level hoặc ghi ADR nếu chọn khác.
2. **R0-03/04/05:** Lập backend inventory và Capability API theo feature/device; ACL/NAT phải unavailable/read-only/local-only đúng thực tế; Interface nói rõ local-only hay có controller.
3. **UI-P0-04 / R1-03:** Hoàn thiện validation matrix và chặn mọi invalid submit.
4. **R0-06:** Chuẩn hóa vocabulary Save local, Preview, Push, Reload, Revert, Delete.

**Gate:** không còn BGP/VRF lệch; không form nào hứa write/push ngoài capability; registry/capability test có router, switch và unknown device.

### Phase B — UI foundation và chất lượng (P1)

1. **R1-01/02:** `FeaturePageShell`, header/context/capability/freshness, và state model chung.
2. **R1-04/05:** dirty guard khi đổi host/tab/selection/close; task feedback, chống submit trùng cho Preview/Push.
3. **UI-P1-04 / R1-09:** benchmark startup, first/repeat open, QML object count, RSS, 100/1.000 row và scroll jank.
4. **UI-P1-03 / R1-08:** virtualize collection lớn theo số đo; không thay mọi `ListView` bằng `TableView` máy móc.
5. **UI-P1-06/07/08:** migration component chết, table/list contract và dialog shell/focus contract.
6. **UI-P2-02..06:** keyboard/focus, responsive/DPI, state, `qsTr()`, visual regression/theme QA.

**Gate:** DHCP và Routing Info chạy qua shell/state chung; invalid input không gọi backend; QA compact + 200% DPI; benchmark có baseline; smoke/unit/visual tối thiểu đạt.

### Phase C — Pilot theo workflow (P1)

1. **F2:** DHCP Pool -> Excluded/Helper -> Interface list/detail responsive.
2. **F4:** Trích `ProcessNavigator`; pilot OSPF rồi EIGRP bằng table/drawer cho collection lớn.
3. **F3:** ACL Standard/Extended chỉ sau local CRUD/capability milestone.

**Gate:** selection/draft không mất khi đổi context; không tạo hàng loạt editor delegate; Preview diff nhận diện add/change/delete; có valid/invalid/failure test.

### Phase D — Hoàn thiện end-to-end và mở rộng (P1/P2)

1. ACL Standard/Extended: persistence, binding, diagnostics, preview/push; chỉ mở Dynamic/Reflexive/MAC theo capability.
2. NAT: chốt ownership ACL/route-map; triển khai Static -> Interfaces -> Dynamic/PAT -> shared policy -> Info/telemetry.
3. Interface: chốt push owner và integrity với VRF/QoS/IPsec.
4. Mở rộng theo dependency: VLAN -> VRF -> STP -> BGP IPv4 unicast; services/security và observability chỉ sau khi contract nền sẵn sàng.

**Gate:** mỗi feature công bố capability chính xác; push chỉ enable khi controller thật; failure path có test; stable IDs được dùng xuyên feature liên quan.

## 7. Trạng thái backlog ngắn

| ID | Trạng thái | Nội dung |
|---|---|---|
| UI-P0-01 | Done | NAT bridge arity khớp QML; vẫn cần backend NAT thật. |
| UI-P0-02 | Done | WindowSettings persistence qua `QSettings`; cần QA multi-monitor/DPI. |
| UI-P0-03 | Done một phần | Normalize `/24` và `-/24`; validation submit còn mở. |
| UI-P0-04 | Open | Validation trước write/cross-field. |
| UI-P0-05 | Blocked | ACL/NAT stub; cần quyết định owner và backend. |
| UI-P0-06 | Open | Feature Registry và BGP/VRF mapping. |
| UI-P1-01/02 | Done | Lazy-load feature/tab và cache state. |
| UI-P1-03/04 | Open | Virtualization có chọn lọc và performance benchmark. |
| UI-P1-05 | Done | Contract/deprecation component cơ bản. |
| UI-P1-06/07/08 | Open | Component cleanup, table/list và dialog contract. |
| UI-P2-01 | Done một phần | A11y metadata standard control. |
| UI-P2-02..10 | Open | Focus, responsive, state, i18n, visual QA, refactor/testability. |
| UI-P3-01..03 | Blocked/Open | Feature dài hạn, data-driven pilot, task/log console. |

## 8. Kiểm chứng và Definition of Done

Mỗi shared component: QML offscreen instantiate, state/property transition, keyboard/a11y và snapshot compact/standard/wide.

Mỗi form: valid/invalid boundary, cross-field/reference/secret, unavailable path, dirty/revert/selection/host-change.

Mỗi backend bridge: arity/type contract, success/error/timeout/cancel, preview không mutate và push có report/audit.

Mỗi collection: empty/loading/error, 100/1.000 row (10.000 khi là log/route), selection/filter/sort/keyboard.

Release gate: QML smoke/lint, unit test, visual regression light/dark/high-contrast, benchmark so baseline và manual QA trên ít nhất một profile device mục tiêu.

Kết quả đã ghi nhận khi lập baseline: smoke QML, prefix harness, WindowSettings và NAT contract đều pass trong môi trường dự án. Lần xác minh ngày 2026-07-12 trong runtime đi kèm không thể chạy đủ suite vì thiếu `requests`, `jinja2` và `PyQt6`; không được dùng kết quả đó để suy ra regression code.

## 9. Quy tắc duy trì tài liệu

- Cập nhật capability matrix và backlog trong cùng PR thay đổi code.
- Thêm benchmark/test evidence cùng item được đánh dấu Done.
- Đặt ADR trước quyết định BGP/VRF, owner Interface push, ownership ACL/prefix-list/route-map, capability schema, secret policy và Database Browser permission.
- Không tạo lại báo cáo audit/roadmap/backlog tách rời; bổ sung trực tiếp vào các mục tương ứng của tài liệu này.
