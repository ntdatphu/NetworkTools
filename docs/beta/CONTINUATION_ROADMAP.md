# Roadmap tiếp tục hoàn thiện UI beta

Ngày cập nhật: 2026-07-10  
Nguồn đầu vào: [changes.md](changes.md), [UI_AUDIT_REPORT.md](UI_AUDIT_REPORT.md), [UI_PATTERN_SYSTEM.md](UI_PATTERN_SYSTEM.md), [FEATURE_UI_DESIGN_PLAN.md](FEATURE_UI_DESIGN_PLAN.md)

## 1. Mục tiêu

Roadmap này đưa nhánh refactor từ trạng thái “nền tảng tốt hơn nhưng capability và UX chưa đồng đều” tới một beta có thể đánh giá end-to-end. Thứ tự ưu tiên:

1. Không cho navigation hoặc UI hứa sai capability.
2. Hoàn thiện contract/state/validation và đo hiệu suất trước khi mở rộng feature.
3. Pilot các họ giao diện trên feature đang có backend thật.
4. Hoàn thiện ACL/NAT backend trước khi trình bày form như chức năng hoạt động.
5. Chỉ sau đó mở rộng BGP/VLAN/VRF/STP và các feature phụ thuộc.

Roadmap không gắn deadline lịch cứng. Mỗi phase chỉ qua gate khi tiêu chí nghiệm thu đạt; estimate cần được lập sau khi backend owner và phạm vi device/vendor được chốt.

## 2. Nguyên tắc thực thi

- Làm vertical slice nhỏ có read/local/preview/push/test rõ hơn là tạo hàng loạt màn hình placeholder.
- Giữ feature adapter khi nó cung cấp domain name/default/API ổn định.
- Không refactor visual đồng thời với thay đổi backend lớn nếu không có test seam.
- Mọi benchmark ghi cả baseline và môi trường; không dùng cảm giác “mượt hơn”.
- Một feature chưa có backend được phép có design prototype, nhưng production UI phải capability-gated.
- Mọi phase cập nhật `SCHEMA_for_UI.md` và nhật ký kiểm chứng trong cùng PR.

## 3. Phase 0 — Sửa sự thật hệ thống và khóa quyết định nền

### Mục tiêu

Loại lỗi navigation/capability và chốt ownership trước khi xây component mới.

### Work items

- **R0-01 Feature Registry:** thay mảng/index song song ở FeatureBar/ContentArea bằng stable ids.
- **R0-02 BGP/VRF decision:** BGP mặc định dưới Routing; VRF top-level. Nếu product chọn khác, ghi ADR và loại entry trùng.
- **R0-03 Capability API:** backend trả read/write level + reason theo feature id/device.
- **R0-04 Capability UI:** ACL/NAT hiện unavailable/read-only/local-only đúng thực tế; Interface hiện local CRUD, không giả có push.
- **R0-05 Backend inventory:** lập bảng method -> implementation owner -> storage -> preview -> push -> test cho mọi feature hiện có.
- **R0-06 Action vocabulary:** chuẩn hóa Save local, Preview, Push, Reload, Revert, Delete semantics.

### Acceptance gate

- Không còn index BGP/VRF lệch.
- Mọi item navigation có stable id, implementation state và device rule.
- ACL/NAT không cho nhập/Save như backend thật khi capability là none.
- QML không suy capability bằng `typeof method` cho feature-level decision.
- Có test route/registry cho router, switch và unknown device.

## 4. Phase 1 — UI foundation và quality baseline

### Mục tiêu

Xây contract xuyên feature và đo baseline trước migration lớn.

### Work items

- **R1-01 FeaturePageShell:** header, host/context, capability, freshness, dirty/pending và action slots.
- **R1-02 View state:** loading/empty/error/unavailable/read-only/stale/dirty/saving/pushing.
- **R1-03 Validation:** field error + summary; IPv4/mask/wildcard/port/range/timer/sequence và cross-field.
- **R1-04 Dirty guard:** đổi host/tab/selection/close khi có draft.
- **R1-05 Async task feedback:** progress/result/log cho preview/push; chống submit trùng.
- **R1-06 Responsive policy:** compact/standard/wide + DPI; split-to-stack contract.
- **R1-07 A11y/i18n:** keyboard/focus/selected semantics; `qsTr()` foundation và glossary.
- **R1-08 DataTableView pilot:** virtualization, column metadata, selection, empty/loading/error.
- **R1-09 Benchmark baseline:** startup, QML object count, peak RSS, first-open latency, 100/1.000 rows, FPS/scroll jank.
- **R1-10 Component cleanup:** quyết định SectionCard, StandardSideBar, StandardValidationDialog; migration/deprecation có test.

### Acceptance gate

- Shell pilot chạy trên ít nhất DHCP và Routing Info.
- Validation invalid input không gọi backend; có matrix test.
- Compact 900x600 và scale 200% không che primary action.
- Keyboard đi được header -> content -> action; focus trở lại sau dialog.
- Benchmark report có baseline trước/sau, không chỉ nhận định.
- Toàn bộ unittest/QML smoke đạt; thêm visual snapshot tối thiểu light/dark.

## 5. Phase 2 — Pilot ba họ giao diện trên feature hiện có

### 5.1. F2 Entity Workspace: DHCP + Interface

Thứ tự:

1. DHCP Pool pilot `EntityWorkspace`.
2. Mở rộng Excluded/Helper bằng cùng list/editor/state contract.
3. Chuyển Interface sang list/detail responsive và section theo kind.

Acceptance:

- Selection/dirty guard đúng; New/Edit/Delete không lẫn state.
- DHCP Save local -> pending -> Preview -> Push có task feedback.
- Interface capability nói rõ local-only hoặc có controller nếu backend được bổ sung.
- 1.000 entity test không tạo 1.000 editor delegate.

### 5.2. F4 Process Workspace: OSPF + EIGRP

Thứ tự:

1. Rút `ProcessNavigator`, context header và action bar từ code hiện có.
2. OSPF pilot section navigation; chuyển Networks/Areas/Interfaces sang table + drawer.
3. EIGRP adapter dùng cùng shell, giữ domain section riêng.

Acceptance:

- Không mất state process khi chuyển section.
- Context process luôn nhìn thấy; không sửa nhầm process.
- Reference picker và validation cho route-map/interface/key chain.
- Preview diff nhận diện add/change/delete theo process.

### 5.3. F3 Policy Workspace: ACL prototype

Chỉ pilot Standard + Extended sau khi backend local CRUD milestone sẵn sàng. UI prototype có thể làm trước sau capability gate.

Acceptance:

- Rule ordering, insert/duplicate/reorder/renumber rõ ràng.
- Sequence và rule validation đầy đủ.
- Saved policy, pending rule và binding không bị trộn.
- Dynamic/Reflexive/MAC vẫn disabled có lý do nếu backend/device chưa hỗ trợ.

## 6. Phase 3 — Hoàn thiện core feature end-to-end

### ACL

- Local schema/CRUD Standard + Extended.
- Binding interface/direction và reference integrity.
- Preview/push controller + result reporting.
- Sau pilot mới mở Dynamic/Reflexive/MAC theo capability.

### NAT

- Chốt ownership ACL/route-map dùng chung hay NAT-specific.
- Local schema/CRUD theo thứ tự Static -> Interfaces -> Dynamic/PAT -> ACL/Route Map.
- Capability banner trong suốt quá trình rollout.
- Preview/push và Info read/telemetry sau khi write path ổn định.

### Interface

- Chốt standalone controller hay local source cho workflow khác.
- Validation L3/WAN/Tunnel/QoS và secret handling.
- Reference integrity cho VRF/QoS/IPsec.

### Acceptance gate

- Không còn form “hoạt động bề ngoài” nhưng mọi write trả false.
- Mỗi core feature có ít nhất read/local/preview rõ; push chỉ enable khi controller thật.
- Add/edit/delete/pending/preview/push failure path có test.
- Capability regression test ngăn UI mở action vượt backend level.

## 7. Phase 4 — Network foundation mở rộng

Triển khai theo dependency, không theo thứ tự item trên FeatureBar.

### 4A. VLAN

- VLAN database + access/trunk membership.
- Link tới Interface/SVI, bulk assignment và conflict preview.
- Pilot switch capability registry.

### 4B. VRF

- Instance + interface binding.
- Route targets/address family; route leaking sau policy model.
- Tích hợp filter/identity xuyên Routing Info/BGP/MPLS.

### 4C. STP

- Read/status trước, global/port settings sau.
- Table fallback trước graph overlay.
- Loop-risk confirmation và device-mode capability.

### 4D. BGP IPv4 unicast

- Process/AFI-SAFI + neighbors + networks.
- Policy reference sau ACL/prefix/route-map contract.
- Session/routes dashboard sau read backend.

### Gate

- Stable ids/reference integrity giữa Interface, VLAN, VRF và BGP.
- Không duplicate interface/policy editor trong từng feature.
- Mỗi feature có một vertical slice thật trên device/vendor mục tiêu.

## 8. Phase 5 — Services, policy và security

Ưu tiên dựa trên nhu cầu sản phẩm và backend readiness:

1. NTP: candidate data-driven form pilot nhỏ.
2. SNMP: communities/users/targets, sau đó views/traps.
3. AAA: server/group/method list với lockout protection.
4. QoS: class/policy/binding + counters.
5. Firewall: object/zone/policy; chốt NAT ownership.
6. VPN: wizard create + daily operation workspace.
7. MPLS: sau VRF/BGP/Interface stable.

Gate chung:

- Secret policy, audit/log redaction và permission model.
- Reference picker dùng stable ids.
- Không mở subfeature nâng cao nếu device/backend capability chưa có.

## 9. Phase 6 — Observability, CLI và Topology

### Telemetry/task foundation

- Metric/event/task schema có source, device, timestamp, freshness, severity và retention.
- Background preview/push cùng xuất hiện trong task console.

### Monitor

- Health/interface/routing vertical slice trước chart mở rộng.
- Filter thời gian/device/source; table/value fallback.

### CLI workspace

- Chỉ xây nếu in-app terminal mang lợi ích hơn action mở terminal hiện tại.
- Session isolation, output virtualization, history/secret policy.

### Topology

- Inventory/link model và confidence/source trước canvas.
- Node/link inspector + list fallback, sau đó layer/path/overlay.

Gate:

- Không hiển thị metric không có timestamp/stale policy.
- Topology action không sửa trực tiếp config nếu không qua editor/preview tương ứng.
- 10.000 log/event row vẫn cuộn/filter trong ngưỡng benchmark.

## 10. Backlog ưu tiên tổng hợp

| ID | Hạng mục | Priority | Phụ thuộc | Deliverable |
|---|---|---:|---|---|
| R0-01 | Feature Registry | P0 | Không | Navigation source of truth |
| R0-03 | Capability API/UI | P0 | Backend inventory | UI không hứa sai |
| R1-03 | Submit validation | P0 | Field contracts | Không gửi invalid payload |
| R1-09 | Performance baseline | P1 | Test harness | Số đo trước/sau |
| R1-01/02 | Page shell + state | P1 | Capability | Header/state thống nhất |
| R2-F2 | DHCP/Interface pilot | P1 | Foundation | Entity pattern validated |
| R2-F4 | OSPF/EIGRP pilot | P1 | Foundation | Process pattern validated |
| R3-ACL | ACL backend + policy pilot | P1 | Capability + policy model | Standard/Extended end-to-end |
| R3-NAT | NAT backend | P1 | ACL/reference decisions | NAT vertical slices |
| R4 | VLAN/VRF/STP/BGP | P2 | Interface/policy/process | Network foundation mở rộng |
| R5 | Services/security | P3 | Secret/reference/capability | Feature vertical slices |
| R6 | Monitor/CLI/Topology | P2/P3 | Telemetry/task/topology data | Observability workspace |

## 11. Test strategy

### Mỗi shared component

- Instantiate QML offscreen, không warning.
- Property/state transition test.
- Keyboard/focus and accessible name/role.
- Compact/standard/wide visual snapshot.

### Mỗi form/editor

- Valid/invalid boundary matrix.
- Cross-field/reference/secret tests.
- Backend không được gọi khi invalid/unavailable.
- Dirty/revert/selection/host-change test.

### Mỗi backend bridge

- Arity và type contract.
- Success/error/timeout/cancel.
- Capability level khớp implementation.
- Preview không mutate; Push có report/audit.

### Mỗi collection

- Empty/loading/error.
- 100 và 1.000 rows; 10.000 cho log/route khi cần.
- Selection/reorder/filter/sort và keyboard.

### Mỗi release gate

- `python -B -m unittest discover -s tests -v` với UTF-8/offscreen.
- QML lint/smoke toàn module.
- Visual regression light/dark/high-contrast.
- Benchmark regression so baseline.
- Manual QA trên ít nhất một device/capability profile mục tiêu.

## 12. Performance budget đề xuất

Giá trị chính xác phải được chốt sau baseline, nhưng report phải theo dõi:

- Startup tới root visible và interactive.
- QML object count trước/đến first feature/đến all visited.
- Peak RSS startup, one-feature và all-feature session.
- First-open và repeat-open latency của feature/tab.
- Scroll frame time ở 100/1.000 rows.
- Preview/push UI responsiveness khi background task chạy.

Không đặt mục tiêu “mọi view unload khi ẩn”; cache state là yêu cầu UX. Tối ưu dựa trên measured memory/latency và dirty-state safety.

## 13. Risk register

| Rủi ro | Tác động | Giảm thiểu |
|---|---|---|
| Universal component quá nhiều flag | Khó bảo trì, mất affordance domain | Pattern family + adapter; abstraction gate |
| UI đi trước backend | Người dùng nhập rồi thất bại | Capability contract + disabled/read-only banner |
| Refactor và backend đổi cùng lúc | Khó cô lập regression | Vertical slice, contract test, PR nhỏ |
| Lazy-load che lỗi tới lần mở đầu | Lỗi production muộn | Smoke mở mọi feature/subfeature |
| Cache view tăng memory | Phiên dài nặng | Benchmark all-visited; unload chỉ khi safe |
| Text tự do cho reference | Orphan/conflict | Stable ids + ReferencePicker + integrity test |
| Secret lộ log/history | Rủi ro bảo mật | SecretField, redaction, audit policy |
| Graph/chart không accessible | Mất khả dụng | Table/list fallback và keyboard inspector |
| Database edit gây hỏng dữ liệu | Mất integrity | Admin gate, schema metadata, transaction/diff/backup |

## 14. Decision log cần có

Trước Phase 2/3, tạo ADR hoặc mục quyết định được duyệt cho:

- BGP/VRF navigation ownership.
- Interface save/push ownership.
- ACL/prefix-list/route-map ownership dùng chung giữa Routing/NAT/Firewall/QoS.
- Feature capability schema và device/vendor granularity.
- Secret storage/redaction.
- Database Browser audience/permission.
- Default language và thuật ngữ không dịch.

## 15. Definition of Ready

Một Feature/SubFeature sẵn sàng để code khi có:

- User workflow và pattern family.
- Backend owner/capability level/data contract.
- Stable ids và reference rules.
- State diagram, validation matrix và action semantics.
- Compact/standard/wide wireframe hoặc layout spec.
- Test plan và performance risk.

## 16. Definition of Done

- Read/local/preview/push đúng capability và có failure state.
- Loading/empty/error/unavailable/read-only/dirty/pending được xử lý.
- Validation và reference integrity chạy trước backend.
- Keyboard, focus, accessibility và responsive QA đạt.
- Collection lớn được virtualize và benchmark trong ngưỡng đã chốt.
- Test/visual snapshot/benchmark đạt; không có QML warning.
- Docs Feature plan, schema/backlog và capability inventory được cập nhật.

## 17. Bước bắt đầu đề xuất

Sprint/iteration đầu tiên nên chỉ gồm:

1. Sửa Feature Registry và mismatch BGP/VRF.
2. Lập capability inventory và hiển thị banner đúng cho ACL/NAT/Interface.
3. Đo baseline startup/RSS/object count/first-open.
4. Pilot `FeaturePageShell` + state contract trên DHCP.
5. Hoàn thiện validation DHCP Pool làm mẫu, kèm test invalid không gọi backend.

Năm bước này tạo nền kiểm chứng cho mọi thiết kế tiếp theo mà chưa mở rộng scope sang feature mới.
