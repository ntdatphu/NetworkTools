# Hệ thống pattern giao diện cho NetworkTools beta

Ngày cập nhật: 2026-07-10  
Trạng thái: đề xuất kiến trúc UI để pilot, chưa phải component API đã đóng băng

## 1. Quan điểm cốt lõi

NetworkTools không nên có một layout duy nhất cho mọi Feature. Sự giống nhau tuyệt đối không đồng nghĩa với nhất quán: một bảng route cần tối ưu scan/filter, một ACL cần tối ưu thứ tự rule, OSPF cần thể hiện process và section phụ thuộc, còn VPN cần dẫn người dùng qua nhiều bước có secret.

Hướng đề xuất là:

- **Thống nhất lớp hệ thống:** theme, header, context thiết bị, capability, request state, validation, dirty state, action semantics, responsive, keyboard và feedback.
- **Dùng nhiều họ giao diện:** mỗi họ phục vụ một mô hình công việc cụ thể.
- **Cho phép feature adapter:** adapter đặt tên miền, default và capability; không copy lại layout nền.
- **Tái sử dụng theo contract, không theo tên gần giống:** chỉ tạo component chung khi có consumer và hành vi chung thật.

## 2. Các lớp phải thống nhất trên mọi Feature

Mọi Feature/SubFeature, dù thuộc họ giao diện nào, phải có cùng các contract sau.

### 2.1. Feature identity và context

Header chuẩn cần công bố:

- Tên Feature và SubFeature hiện tại.
- Thiết bị/host đang thao tác, device type và connection state.
- Capability level: `unavailable`, `read-only`, `local-edit`, `preview`, `push`.
- Dirty/pending count và trạng thái dữ liệu: current/stale/loading/error.
- Action liên quan: Reload, Save local, Preview, Push; chỉ hiện action có nghĩa.

Không dùng label “Information” chung chung ở mọi nơi. Ví dụ: `DHCP / Pools`, `Routing / OSPF`, `Security / ACL / Extended`.

### 2.2. View state

Một state model chung nên có tối thiểu:

| State | Ý nghĩa | Hành vi UI |
|---|---|---|
| `unavailable` | Thiết bị/backend không hỗ trợ | Capability banner, giải thích lý do, khóa action ghi |
| `loading` | Đang đọc dữ liệu | Skeleton/progress, giữ layout ổn định |
| `empty` | Có capability nhưng chưa có dữ liệu | Empty state kèm primary action phù hợp |
| `ready` | Dữ liệu đã đồng bộ | Cho phép thao tác theo permission |
| `dirty` | Có thay đổi local chưa lưu | Dirty badge, cảnh báo khi đổi host/đóng tab |
| `saving` | Đang ghi local | Khóa submit trùng, hiển thị task progress |
| `pending-push` | Local DB khác trạng thái đã push | Hiện pending count và Preview/Push |
| `pushing` | Đang đẩy xuống thiết bị | Không đóng dialog im lặng; cho xem log/progress |
| `stale` | Dữ liệu có thể cũ | Banner nhẹ và action reload |
| `error` | Read/save/push thất bại | Message có source, retry và chi tiết kỹ thuật có thể mở rộng |

Empty không được dùng thay unavailable. Danh sách rỗng từ stub không được trình bày như “thiết bị chưa có cấu hình”.

### 2.3. Action semantics

- **Save:** ghi draft/local database, không ngầm push.
- **Preview:** dựng command/diff nhưng không thay đổi thiết bị.
- **Push:** thay đổi thiết bị sau bước preview/confirmation phù hợp.
- **Reload:** đọc lại source đã nêu rõ; nếu có dirty state phải hỏi trước khi ghi đè.
- **Reset form:** đưa field về default của form mới.
- **Revert changes:** trở về snapshot đã load, không đồng nghĩa xóa entity.
- **Delete:** phải nói rõ xóa local, tạo pending delete hay xóa trực tiếp trên thiết bị.

Các action cùng nghĩa phải dùng cùng label, icon, vị trí và feedback. Không dùng “Add”, “Save” và “Apply” lẫn lộn cho cùng một thao tác local CRUD.

### 2.4. Validation và secret

- Normalize nhẹ khi kết thúc nhập; validate đầy đủ trước backend.
- Lỗi gắn với field và có summary ở đầu form khi nhiều lỗi.
- Validation cross-field phải mô tả quan hệ, ví dụ start IP <= end IP, timer dead > hello, tunnel source != destination.
- Secret dùng control riêng: masked, reveal tạm thời, không đưa vào toast/log, không khôi phục plain text ngoài policy cho phép.
- Giá trị tham chiếu như interface, ACL, route-map, policy phải ưu tiên selector có search và trạng thái missing reference thay vì text tự do.

### 2.5. Responsive, keyboard và accessibility

- Breakpoint tham chiếu: compact `900x600`, standard `1280x720`, wide `1920x1080`; kiểm tra scale 100/150/200%.
- Split view chuyển thành stacked editor/list ở compact; không ép hai pane xuống dưới minimum width.
- Table dùng column metadata: minimum, weight, priority và hide/stack rule.
- Tab order đi theo workflow; Enter submit ở form đơn giản, không submit vô tình trong multiline/rule builder; Escape đóng dialog và trả focus.
- Tab/list/tree phải công bố current/selected/expanded state cho accessibility.

## 3. Tám họ giao diện

### F1 — Observe & Diagnose Dashboard

Phù hợp: Information, Routing Info, DHCP/NAT Info, Monitor, trạng thái Topology, overview của STP/BGP/VPN.

Cấu trúc:

1. Header + device/capability/freshness.
2. Summary cards có số liệu và severity.
3. Bộ lọc thời gian/protocol/VRF/interface.
4. Bảng hoặc biểu đồ chi tiết được virtualize.
5. Inspector/log/config liên quan ở pane phụ hoặc tab.

Contract dùng chung đề xuất:

- `FeaturePageShell`
- `FeatureHeader`
- `SummaryMetricGrid`
- `FilterBar`
- `DataTableView`
- `StatePanel`

Nguyên tắc: read-heavy, refresh rõ ràng, timestamp/freshness bắt buộc. Không đặt form cấu hình dài trong dashboard; action cấu hình nên mở đúng editor/subfeature.

### F2 — Entity Master–Detail Editor

Phù hợp: DHCP Pool/Excluded/Helper, Interface, NAT Static/Dynamic/Interfaces, VLAN database, NTP servers, SNMP targets, local users.

Cấu trúc standard/wide:

- Pane danh sách/search/filter bên trái hoặc phải.
- Pane editor cho entity đang chọn.
- Action bar cố định cho New, Save/Revert, Delete.
- Detail/reference/impact có thể là drawer thứ ba khi cần.

Cấu trúc compact:

- Danh sách trước; chọn entity chuyển sang editor và có breadcrumb/back.

Contract dùng chung đề xuất:

- `EntityWorkspace`
- `EntityListPanel`
- `EntityEditorPane`
- `EditorActionBar`
- `ReferencePicker`

Nguyên tắc: selection và dirty state tách biệt; đổi selection khi dirty phải xác nhận. Danh sách cần loading/empty/error và keyboard selection. Không dùng master–detail nếu dữ liệu chỉ có một global configuration object.

### F3 — Ordered Policy & Rule Builder

Phù hợp: ACL, Firewall policy, QoS class/policy, route-map, SNMP view, policy-based routing và một phần NAT.

Cấu trúc:

1. Policy list và scope/binding.
2. Rule table có sequence, action, match, consequence, enabled/status.
3. Rule editor theo type; field phụ xuất hiện theo protocol/action.
4. Reorder/duplicate/insert above/below và conflict diagnostics.
5. Policy preview/diff và binding impact trước push.

Contract dùng chung đề xuất:

- `PolicyWorkspace`
- `PolicyListPanel`
- `RuleTableView`
- `RuleEditorDrawer`
- `SequenceEditor`
- `ImpactPreview`

Nguyên tắc: thứ tự rule là dữ liệu hạng nhất; không chỉ hiển thị list có nút xóa. Phải phân biệt rule invalid, shadowed, redundant và reference missing. Với rule builder phức tạp, editor dạng drawer/dialog có cấu trúc tốt hơn nhồi tất cả field vào pane cố định.

### F4 — Process & Hierarchy Workspace

Phù hợp: OSPF, EIGRP, BGP, VRF, MPLS/LDP, AAA method hierarchy.

Cấu trúc:

- Process/instance navigator.
- Pinned context của process đang chọn.
- Section navigation theo domain: General, Networks, Neighbors, Areas, Interfaces, Redistribution, Policy, Advanced.
- Mỗi section dùng entity list hoặc compact rule table phù hợp.
- Global action bar: Add Process, Revert, Save local, Preview, Push.

Contract dùng chung đề xuất:

- `ProcessWorkspace`
- `ProcessNavigator`
- `ProcessContextHeader`
- `SectionNavigator`
- `ProcessActionBar`

Nguyên tắc: không render toàn bộ section dài cùng lúc. Context process phải luôn nhìn thấy để tránh sửa nhầm. Reference giữa process/area/interface/policy phải dùng picker theo scope.

### F5 — Relationship & Topology Workspace

Phù hợp: Topology, STP, VPN tunnels, MPLS paths, interface/link relationships, VRF route leaking.

Cấu trúc:

- Canvas/graph hoặc matrix quan hệ ở trung tâm.
- Search/filter/layer controls.
- Inspector cho node/link/path đang chọn.
- List/table fallback cho accessibility và dữ liệu lớn.
- Overlay trạng thái, lỗi và pending change; cấu hình mở trong editor phù hợp, không chỉnh mọi thứ trực tiếp trên canvas.

Contract dùng chung đề xuất:

- `TopologyWorkspace`
- `GraphViewport`
- `LayerFilterBar`
- `SelectionInspector`
- `PathTracePanel`

Nguyên tắc: graph là một cách quan sát, không phải source duy nhất. Mọi thông tin/action quan trọng phải truy cập được qua list/keyboard. Không xây canvas trước khi có topology data model và stable identifiers.

### F6 — Guided Setup Wizard

Phù hợp: New/Batch Device, site-to-site VPN, AAA onboarding, SNMPv3, first-run setup, import migration.

Cấu trúc:

- Steps có mục tiêu rõ: Target -> Parameters -> References/Secrets -> Validate -> Preview -> Apply.
- Cho phép quay lại mà không mất state.
- Validation từng bước và toàn cục.
- Review cuối hiển thị diff/commands, không chỉ summary text.
- Có save draft nếu workflow dài.

Contract dùng chung đề xuất:

- `WizardShell`
- `WizardStepRail`
- `ReviewSummary`
- `SecretField`
- `ValidationSummary`

Nguyên tắc: wizard dành cho flow có phụ thuộc và quyết định tuần tự; CRUD lặp lại hàng ngày nên dùng F2/F3 để nhanh hơn.

### F7 — Inspector, Console & Data Tool

Phù hợp: running-config, CLI workspace, Database Browser, logs/tasks, raw command output, template preview.

Cấu trúc:

- Toolbar với source, search/filter, copy/export, refresh và mode.
- Vùng nội dung monospace/table, virtualized khi dữ liệu lớn.
- Side inspector cho metadata, task, error hoặc diff.
- Read/write mode tách rõ; edit cần transaction/diff/undo khi rủi ro cao.

Contract dùng chung đề xuất:

- `InspectorShell`
- `ConsoleView`
- `DiffViewer`
- `TaskLogView`
- `DataTableView`

Nguyên tắc: dữ liệu thô phải có source/timestamp; không cho edit database rộng chỉ vì rowid tồn tại mà thiếu validation/backup/audit policy.

### F8 — Settings Catalog

Phù hợp: Theme, Status Bar, External Tools, General, Advanced và future per-workspace preferences.

Cấu trúc:

- Searchable category navigation.
- Section cards có title, description và scope.
- Control thay đổi trực tiếp khi an toàn; action Save/Restart khi cần.
- Reset theo control/section/category; hiển thị default và source policy.

Contract dùng chung đề xuất:

- `SettingsCatalog`
- `SettingsSection`
- `SettingRow`
- `ResetAction`

Nguyên tắc: Settings không dùng form CRUD/list giống network configuration. Mỗi setting phải nêu scope, persistence và restart requirement.

## 4. Ma trận chọn họ giao diện

| Câu hỏi chính của người dùng | Họ ưu tiên | Ví dụ |
|---|---|---|
| “Thiết bị đang ở trạng thái nào?” | F1 | Monitor, Routing Info |
| “Tôi cần tạo/sửa một đối tượng trong danh sách” | F2 | DHCP Pool, Interface |
| “Thứ tự và điều kiện của các rule là quan trọng” | F3 | ACL, Firewall, QoS |
| “Cấu hình có instance/process và nhiều section phụ thuộc” | F4 | OSPF, EIGRP, BGP |
| “Tôi cần hiểu node/link/path và quan hệ” | F5 | Topology, STP, VPN |
| “Thiết lập phức tạp nên đi theo bước” | F6 | VPN, Add Device |
| “Tôi cần xem raw data/log/config hoặc công cụ kỹ thuật” | F7 | CLI, DB, config |
| “Tôi đang thay đổi preference của ứng dụng” | F8 | Theme, General |

Một feature có thể phối hợp nhiều họ. Ví dụ BGP dùng F1 cho status/routes, F4 cho process/neighbors và F3 cho policy. VPN dùng F5 cho tunnels, F6 cho tạo tunnel mới và F1 cho health.

## 5. Component contract đề xuất

### 5.1. Nên xây sớm

| Component/contract | Trách nhiệm | Consumer pilot |
|---|---|---|
| `FeatureRegistry` | Source of truth cho id, route, label, device/capability và subfeature | FeatureBar + ContentArea |
| `FeaturePageShell` | Header, capability, state, content và action slot | DHCP + Routing Info |
| `CapabilityBanner` | Giải thích unavailable/read-only/local-only | ACL + NAT + Interface |
| `ViewStatePanel` | Loading/empty/error/stale | DHCP + Information + Database |
| `EditorActionBar` | New/Save/Revert/Delete và dirty guard | DHCP + Interface |
| `ValidationSummary` | Tập hợp lỗi và focus field | DHCP Pool + ACL |
| `DataTableView` | Virtualized rows, column metadata, selection, empty/loading/error | Routing Info + Database + ACL rules |
| `TaskProgressPanel` | Async preview/push/log/result | Routing + DHCP |

### 5.2. Pilot trước khi chuẩn hóa

- `EntityWorkspace`: pilot DHCP Pool và Interface.
- `PolicyWorkspace`: pilot ACL Standard/Extended; chưa chuẩn hóa cho Firewall/QoS trước khi có domain model.
- `ProcessWorkspace`: rút contract từ OSPF/EIGRP trước khi thêm BGP.
- `TopologyWorkspace`: chỉ bắt đầu khi topology schema và interaction requirement được chốt.

### 5.3. Không nên làm

- Không tạo một `UniversalFeatureView.qml` có hàng chục flag để mô phỏng tám workflow.
- Không biến mọi form thành JSON/data-driven trước khi chứng minh type safety, secret handling và custom interaction.
- Không thay mọi `ListView` bằng `TableView`; chọn theo row count, column behavior và interaction.
- Không hợp nhất dialog validation, confirmation và long-running preview/push chỉ vì cùng có header/footer.
- Không đưa protocol business logic vào base visual component.

## 6. Capability contract đề xuất

Backend nên trả capability theo stable feature id, không để QML suy ra từ method existence:

```text
featureId: routing.ospf
deviceSupported: true
readLevel: live | local | none
writeLevel: push | preview | local | none
reasonCode: optional stable code
reasonText: localized/user-facing description
backendVersion: contract version
```

UI dùng contract này để:

- Ẩn feature không liên quan đến device type khi chắc chắn.
- Hiện disabled item kèm lý do khi người dùng cần biết feature tồn tại.
- Chọn read-only/local-edit/preview/push state chính xác.
- Tránh tình trạng form trông hoạt động nhưng mọi write đều trả `false`.

## 7. Data và navigation contract

- Dùng stable string id như `routing.ospf.networks`; index chỉ là presentation order.
- Registry chứa parent/child, route, pattern family, capability key, icon, implementation state và device constraints.
- Deep-link phải resolve bằng id; khi feature unavailable, giữ route và hiển thị reason thay vì nhảy âm thầm.
- BGP nên có một owner rõ: đề xuất đặt dưới `routing.bgp`; nếu sản phẩm muốn BGP là workspace độc lập, phải bỏ tab BGP dưới Routing để không có hai entry cạnh tranh.
- VRF là feature riêng có quan hệ với Interface, Routing/BGP và MPLS; không dùng chung index với BGP.

## 8. Quality gate cho một pattern/component

Một pattern chỉ được coi là reusable khi:

1. Có ít nhất hai consumer thật; abstraction table/policy/process nên có ba hoặc một pilot được review.
2. Có tài liệu property/signal/state và example tối thiểu.
3. Chạy ở compact/standard/wide và scale 150/200%.
4. Có keyboard/focus/accessibility test cơ bản.
5. Có empty/loading/error/dirty/read-only state.
6. Không chứa tên protocol hoặc gọi thẳng backend domain-specific.
7. Consumer cũ không mất feature-specific affordance để đổi lấy vẻ ngoài giống nhau.

## 9. Quyết định cần chốt trước implementation lớn

- BGP thuộc Routing hay là top-level feature?
- VRF có phải top-level feature và device types nào hỗ trợ?
- Interface Save là local draft cho workflow push nào, hay là cấu hình trực tiếp độc lập?
- ACL/NAT sẽ có backend local CRUD trước hay bị khóa read-only cho tới khi có end-to-end push?
- Database Browser là công cụ dev/admin hay feature cho mọi người dùng; mức edit/audit nào được phép?
- Ngôn ngữ mặc định và phạm vi dịch thuật của thuật ngữ network.

Các quyết định này là gate trong [CONTINUATION_ROADMAP.md](CONTINUATION_ROADMAP.md), không nên được quyết định ngầm trong QML của từng form.
