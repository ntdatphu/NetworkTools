# Kế hoạch thiết kế UI theo Feature và SubFeature

Ngày cập nhật: 2026-07-10  
Baseline: `refactor/fronend-beta` tại `221eee0`

## 1. Phạm vi và cách đánh giá

Tài liệu này đánh giá UI hiện có trong `app/UI/`, lời gọi trực tiếp tới `DatabaseManager`, `TerminalHelper`, `ExternalToolsManager` và các Feature đang xuất hiện trong navigation. Mỗi feature được xem theo bốn mức riêng:

- **UI:** có màn hình/form thật hay chỉ placeholder/disabled.
- **Local data:** có read/CRUD local thật hay rơi vào stub.
- **Preview:** có dựng command/diff trước khi push.
- **Push:** có workflow end-to-end xuống thiết bị.

Pattern family tham chiếu [UI_PATTERN_SYSTEM.md](UI_PATTERN_SYSTEM.md): F1 Dashboard, F2 Master–Detail, F3 Policy Builder, F4 Process Workspace, F5 Topology, F6 Wizard, F7 Inspector và F8 Settings.

## 2. Vấn đề xuyên Feature cần xử lý trước

### 2.1. Navigation không có source of truth

`FeatureBar.qml` và `ContentArea.qml` duy trì hai mảng song song bằng index. Index 4 hiện là BGP ở `FeatureBar` nhưng là VRF ở `ContentArea`. Router chỉ được lọc còn Routing/DHCP/ACL/NAT; device type khác/không xác định lại thấy toàn bộ item disabled.

Đề xuất:

- Tạo `FeatureRegistry` dùng stable id, ví dụ `routing`, `routing.bgp`, `vrf`, `dhcp.pool`.
- Registry cung cấp label, order, route, parent, pattern family, implementation state, device constraints và capability key.
- `FeatureBar`, dropdown, `ContentArea` và deep-link cùng đọc registry; không dùng global index làm identity.
- BGP mặc định thuộc `routing.bgp`; VRF là top-level riêng. Nếu product chọn BGP top-level, phải loại tab BGP trong Routing.

### 2.2. Hình thức hoàn thiện vượt capability

- ACL và NAT có form đầy đủ nhưng backend vẫn là `StubSlotsMixin`.
- Interface có local CRUD thật qua `DhcpSlotsMixin`, không phải stub, nhưng chưa có preview/push riêng.
- DHCP và Routing có local CRUD + preview/push đáng kể.

Mỗi page phải có capability banner và action bar phản ánh đúng `read/local/preview/push`, không chỉ dựa vào host khác rỗng.

### 2.3. Header và state không thống nhất

DHCP đã có header mới; Information và Database có header riêng; Routing/ACL/NAT/Interface dùng cấu trúc khác. Cần `FeaturePageShell` dùng chung identity/context/state, nhưng body vẫn chọn pattern family riêng.

## 3. Ma trận hiện trạng

| Feature | SubFeature hiện có | Capability hiện tại | Pattern đích | Ưu tiên |
|---|---|---|---|---:|
| Device workspace | list, search, groups, tabs, add/batch/YANG | UI + local device CRUD + terminal session | F2 + F6 | P1 |
| Information | running-config live hoặc backup | Read | F1 + F7 | P1 |
| CLI | mở terminal ngoài | Action ngoài app, chưa có content view | F7 | P3 |
| Interface | L3/WAN/Tunnel/QoS reference + saved list | Local CRUD | F2 | P0/P1 |
| Routing Info | Overview/Routes/Config | Read | F1 + F7 | P1 |
| Static Routing | Default + route rows | Local CRUD + preview/push | F2 | P1 |
| OSPF | process + nhiều section | Local CRUD + preview/push | F4 | P1 |
| EIGRP | process + nhiều section | Local CRUD + preview/push | F4 | P1 |
| BGP | tab disabled | Chưa có | F4 + F1 + F3 | P2 |
| DHCP | Info disabled; Pool/Excluded/Helper | Local CRUD + preview/push | F2 + F1 | P1 |
| ACL | Standard/Extended/Dynamic/Reflexive/MAC | UI; persistence stub | F3 | P0/P1 |
| NAT | Info disabled; 6 form | UI; persistence stub | F2 + F3 + F1 | P0/P1 |
| VLAN/VRF/STP | chưa có | Chưa có | F2/F4/F5 | P2 |
| QoS | chưa có | Chưa có | F3 + F1 | P3 |
| SNMP/NTP/AAA | chưa có | Chưa có | F2/F4/F6 | P3 |
| MPLS/VPN/Firewall | chưa có | Chưa có | F4/F5/F6/F3 | P3 |
| Monitor | chưa có | Chưa có telemetry model | F1 | P2/P3 |
| Topology | activity item disabled | Chưa có topology model | F5 | P3 |
| Settings | Theme/External Tools; General/Advanced placeholder | Một phần thật | F8 | P1/P2 |
| Database Browser | table list, view/edit/reload | Read/edit local DB | F7 | P1 |
| Notification | toast + history panel | Có cơ bản | F1/F7 task-log | P2 |

## 4. Workspace thiết bị và shell

### Hiện trạng

- `DevicesPanel` chia thiết bị theo connected/waiting/disconnected, có search và context menu.
- `DeviceTabs` quản lý tab đang mở, history và close behavior.
- New Device, Batch New Device, device form và AddYangcfg là các flow riêng.
- FeatureBar trộn main icons Information/CLI/Interface với text features.

### Đề xuất

- Giữ DevicesPanel là inventory/navigation, không biến nó thành `StandardSideBar` generic.
- Mỗi device tab giữ một `DeviceWorkspaceContext`: host, type, capabilities, connection, pending count, last sync.
- New Device đơn dùng F6 ngắn: Identity -> Credentials/Transport -> Test -> Save.
- Batch Device dùng import grid có validation theo row, filter lỗi, retry row và dry-run; không dùng wizard tuyến tính cho hàng trăm row.
- AddYangcfg nên trở thành optional onboarding step/capability, không đứng như một form độc lập khó hiểu.
- Khi đổi/đóng device có dirty view, shell tổng hợp dirty state từ các feature loader và yêu cầu Save/Revert/Keep draft.

## 5. Information và CLI

### Information hiện có

`InformationView` tải `show running-config` từ active CLI session; nếu không có session thì đọc backup local. UI có Reload, loading, error và TextArea monospace.

### Chỉnh sửa đề xuất

- Chuyển sang F1 + F7 với subfeatures: Summary, Inventory, Running Config, Backups, Diff.
- Header phải nêu source `live session` hay `backup`, timestamp và stale state.
- Running Config thêm search, line number, copy/export, wrap toggle và diff với backup/last pushed.
- Summary chỉ hiển thị dữ liệu có backend thật: hostname, platform, uptime/session, interface/routing counts; không dựng card rỗng.
- Backup list dùng F2 nhỏ: timestamp/source/size/status; chọn bản backup mở DiffViewer.

### CLI hiện có

CLI chỉ gọi `cli.openTerminal()`; không có `ContentArea` view dù xuất hiện như main feature icon.

### Chỉnh sửa đề xuất

- Giai đoạn gần: đổi tooltip/action thành “Open Terminal” để phản ánh đúng hành vi.
- Giai đoạn sau: nếu cần CLI tích hợp, dùng F7 với session tabs, command palette/history, output virtualized, task state và explicit target host.
- Không tự động đưa password/secret vào history/log; command nguy hiểm cần policy/confirmation ngoài UI text matching đơn giản.

## 6. Interface

### Hiện trạng

`InterfaceView` là split master–detail tương đối đầy đủ:

- Chọn family/quick port và interface name.
- Nhóm L3: primary/secondary IP, mask, MTU, bandwidth, delay, speed/duplex, ARP và directed broadcast.
- Nhóm Tunnel: mode, source/destination, key, keepalive, IPsec profile.
- Nhóm WAN: encapsulation, PPP/PPPoE, credential, clock rate, LMI.
- Nhóm QoS reference: trust, policy in/out, shaping/policing.
- Pane Database reference hiển thị interface và các bảng detail liên quan.
- Local CRUD thật qua `DhcpSlotsMixin`; chưa có View/Push riêng.

### Hạn chế

- Pane form minimum 520/640 px khó dùng ở compact.
- Nhiều field nâng cao luôn nằm trong một file lớn; dependency theo kind chỉ được ẩn/hiện.
- Primary validation chủ yếu non-empty; tunnel source/destination, MTU, rate, secret và cross-field chưa đầy đủ.
- Label “DB detail” lộ kiến trúc lưu trữ thay vì khái niệm người dùng.
- Không rõ Save là draft cho DHCP/routing worker hay cấu hình interface độc lập.

### Thiết kế đích

Chọn F2 `EntityWorkspace`:

- List interface có filter theo state/type/VRF, operational badge và pending badge.
- Editor chia section: Identity, Addressing, Link, Encapsulation/Tunnel, Services/Policy, Advanced.
- “Interface type” thay “DB detail”; section hiện theo type/capability.
- ReferencePicker cho VRF, QoS policy, IPsec profile; hiển thị missing reference.
- Compact chuyển list -> detail route; wide có inspector trạng thái/live counters.
- Chốt owner push: nếu Interface có controller riêng, thêm Preview/Push; nếu chỉ là local source cho feature khác, banner phải nói rõ consumer và pending behavior.

## 7. Routing

### 7.1. Routing Info

Hiện có Overview, Routes và Config; filter Search/VRF/Protocol; bảng VRF, protocol, prefix, path, AD/metric, age, best; protocol distribution và running config backup.

Đề xuất F1 + F7:

- Tách summary metrics khỏi route table; route table dùng `DataTableView`, virtualized, sortable và column metadata.
- Filter bar giữ search/VRF/protocol, bổ sung best-only, connected/static/dynamic và clear-all.
- Chọn route mở inspector: next hops, source protocol, age, recursion và related config.
- Config dùng chung `DiffViewer` với Information thay vì một viewer thứ hai.
- Timestamp/freshness và live/backup source bắt buộc.

### 7.2. Static/Default Routing

Hiện có card Default Route, danh sách Static Routes, row inline edit và View & Push. Route collection vẫn có nguy cơ dùng Repeater khi lớn.

Đề xuất F2:

- Default route là pinned entity/special filter, không cần layout khác hoàn toàn với static route.
- List/table cột Destination, Next hop/interface, AD, VRF, track/name, pending status.
- Editor hỗ trợ next-hop type có điều kiện; validate destination/mask, AD, loop và duplicate.
- Bulk paste/import route và duplicate row là extension hợp lý; không render 1.000 inline editor cùng lúc.
- Preview chỉ show command của route pending và diff theo add/change/delete.

### 7.3. OSPF

Hiện có process card và các section: Networks, Areas/Ranges, Interface Settings, Passive Interfaces, Redistribute, Distance, Tuning; process header được pin; Add Process, Reload, Cancel Changes và View & Push.

Đề xuất F4:

- ProcessNavigator hiển thị process ID, router ID, dirty/error và area/network counts.
- SectionNavigator: General, Networks, Areas, Interfaces, Redistribution, Distance/Timers, Advanced.
- Networks/Areas/Interfaces chuyển collection lớn sang virtualized table + editor drawer.
- Area range editor phụ thuộc selected area phải nằm trong Area detail, không là form rời dễ mất context.
- Timer field dùng unit, preset và cross-validation; auth dùng secret/reference control.
- Diagnostics cảnh báo network overlap, area missing, passive conflict và reference route-map thiếu.
- Giữ process context luôn thấy trên màn hình compact bằng sticky breadcrumb/header.

### 7.4. EIGRP

Hiện có process card và các section: Networks, Passive Interfaces, Interface Settings, Redistribute, Distribute Lists, Offset Lists, Key Chains; process có auto-summary, passive default, BFD, stub, metric weights, distances, variance và maximum paths.

Đề xuất F4:

- Dùng cùng ProcessWorkspace với OSPF, nhưng section adapter riêng.
- General chia Identity/AS, Metric & Paths, Stub/Passive, Timers.
- Network/interface/distribute/offset collections dùng table + drawer, tránh hàng dài field `optional` không có help/unit.
- Key Chains dùng SecretField, lifetime picker và reference count; không hiển thị lại key string plain text.
- Validation variance/maximum paths, K-values, timers, BFD và interface summary.
- Distribute/offset list dùng ReferencePicker tới ACL/prefix-list thay text tự do.

### 7.5. BGP

Hiện chỉ là tab disabled. Đề xuất owner mặc định `routing.bgp`, phối hợp F4 + F1 + F3:

- Processes/AFI-SAFI: local AS, router ID, address families.
- Neighbors: peer/group, remote AS, source, timers, auth, capabilities.
- Networks/Aggregates và Redistribution.
- Policy: prefix-list/route-map import/export qua F3/ReferencePicker.
- Status: session state, prefixes, flap/last error; Routes: RIB-in/RIB-out/best path qua F1.
- Triển khai IPv4 unicast pilot trước; không mở EVPN/VPNv4 nếu VRF/MPLS model chưa ổn định.

## 8. DHCP

### Hiện trạng

- Info disabled.
- Pool: name, network/mask, default router, DNS, lease; local save/edit/delete; View & Push cấp DHCP.
- Excluded: start/end range.
- Helper: interface + helper IP.
- Các form dùng split form/list và lưu local trước khi push.

### Đề xuất

Chọn F2 làm pattern pilot đầu tiên:

- Dùng chung `EntityWorkspace`, `EditorActionBar`, dirty guard và state panel cho ba subfeature.
- Pool có section Addressing, Options, Lease; DNS hỗ trợ list nhiều server thay text đơn.
- Excluded range hiển thị conflict/overlap với pool; start <= end và cùng subnet nếu policy yêu cầu.
- Helper dùng ReferencePicker interface, cho nhiều helper trên interface và duplicate detection.
- Info dùng F1: pool utilization, leases nếu backend có dữ liệu thật, excluded count, helper bindings và pending changes. Không mở tab Info chỉ với card tĩnh.
- Header hiện tại giữ được title/host nhưng chuyển vào `FeaturePageShell`; pending count và last push result cần nằm cùng context.

## 9. ACL

### Hiện trạng

Một `AclForm` dùng chung năm tab Standard, Extended, Dynamic, Reflexive và MAC. Form có:

- ACL identity/description, binding interface + direction.
- Sequence/action và type-specific rule input.
- Saved ACL list và pending/selected rule list.
- Local model, dirty signature và Save flow, nhưng backend `saveAcl/deleteAcl/getAcls` vẫn là stub.

### Đánh giá theo SubFeature

- **Standard:** source network/wildcard; phù hợp pilot F3 đơn giản.
- **Extended:** protocol, source/destination, wildcard và ports; cần conditional field/port operator rõ.
- **Dynamic:** extended rule + dynamic name/timeout; cần giải thích capability/vendor.
- **Reflexive:** reflect/evaluate semantics và timeout; cần dependency giữa rule pairs.
- **MAC:** source/destination MAC/mask và ethertype; không nên dùng label/IP validation chung.

### Thiết kế đích

Chọn F3 `PolicyWorkspace`:

- ACL list -> ordered RuleTable -> RuleEditor drawer.
- Rule row hiển thị sequence, permit/deny, normalized match summary, binding/diagnostic.
- Hỗ trợ insert above/below, duplicate, reorder có kiểm soát, renumber và bulk paste.
- Binding tách khỏi rule editor, cho nhiều interface/direction nếu backend model hỗ trợ.
- Diagnostics: duplicate sequence, shadowed/redundant rule, invalid network/port, missing interface.
- ACL chưa có backend phải hiện `unavailable/local-disabled`; không cho người dùng nhập dài rồi Save thất bại.
- Backend milestone đầu tiên: Standard + Extended local CRUD; Dynamic/Reflexive/MAC chỉ mở khi contract và device support được xác nhận.

## 10. NAT

### Hiện trạng

Info disabled. Sáu form Static, Dynamic, PAT, Interfaces, ACL, Route Map đều có add/list/delete nhưng đọc/ghi rơi vào stub. Refactor đã sửa arity để fail có kiểm soát, chưa triển khai persistence.

### Đề xuất theo SubFeature

- **Info (F1):** translation counts, inside/outside bindings, pool usage, hits/errors và pending config; chỉ làm khi có telemetry/read backend.
- **Static (F2):** entity editor cho inside local/global, protocol và port mapping; phát hiện duplicate/overlap.
- **Dynamic Pools (F2):** pool range + netmask; ACL phải là ReferencePicker, có utilization/overlap diagnostic.
- **PAT (F2/F3 nhỏ):** source ACL + interface/pool + overload; hiển thị dependency tới NAT ACL/pool.
- **Interfaces (F2):** chọn từ Interface registry, gán inside/outside; tránh text tự do và báo interface đã gán/conflict.
- **NAT ACL (F3):** không tạo rule model cạnh tranh với Feature ACL. Quyết định dùng ACL reference chung hoặc scope-specific policy rõ ràng.
- **Route Map (F3):** ordered sequences và match conditions; nên dùng PolicyWorkspace/ReferencePicker thay form list độc lập.

Thứ tự triển khai: capability/read-only banner -> data schema -> Static + Interfaces pilot -> Dynamic/PAT -> shared ACL/Route Map -> Info/telemetry -> preview/push.

## 11. Switching và segmentation

### VLAN

Đề xuất F2:

- VLAN database: ID, name, state, purpose/site.
- Port membership: access VLAN, voice VLAN, trunk native/allowed list.
- SVI chỉ là reference/deep-link sang Interface, không copy L3 interface form.
- Bulk assignment và range editor cần preview conflict; switch capability quyết định field.

### VRF

Đề xuất F4 + F2:

- VRF instances: name, RD, address families, description.
- Interface bindings dùng reference table.
- Route targets/import/export và route leaking dùng F3 nhỏ vì có policy/order/dependency.
- Liên kết trực tiếp tới BGP/MPLS status; stable VRF id dùng xuyên route table/filter.

### STP

Đề xuất F1 + F5 + F2:

- Overview root/bridge state, topology change và blocked ports.
- Global mode/settings; VLAN/MST instances.
- Port guard settings: portfast, BPDU guard/filter, root/loop guard, cost/priority.
- Graph là optional overlay; luôn có table fallback. Cảnh báo thay đổi có thể gây loop trước push.

## 12. Policy, services và security

### QoS

F3 cho Class Map/Policy Map/Service Policy; F1 cho counters/drop/queue. Editor phải thể hiện graph Class -> Match -> Action -> Binding, có unit cho rate/burst và ReferencePicker tới ACL/interface.

### SNMP

F2 cho communities/users/targets; F3 cho views/access; F6 cho SNMPv3 onboarding. Secret/auth/privacy protocol phải dùng SecretField. Info/status chỉ hiển thị khi có polling/trap backend.

### NTP

F2 cho server/peer list, source interface, prefer, VRF và authentication key reference; F1 cho sync state, stratum, offset và reachability. Đây là candidate tốt cho data-driven form pilot vì entity nhỏ và ít custom interaction.

### AAA

F4 cho server groups và method lists; F2 cho servers/local users; F6 cho onboarding. Phải chặn lockout bằng review/fallback local policy và secret handling.

### Firewall

F3 là trung tâm: objects/groups, zones, ordered policies, services và logging. NAT ownership phải chốt để không có hai NAT editors. Có shadow/redundancy diagnostics và impact preview trước push.

## 13. MPLS, VPN và Topology

### MPLS

F4 cho global/LDP/label policy, F5 cho LSP/path, F1 cho neighbors/labels/status. Phụ thuộc Interface, Routing, VRF và BGP; không nên triển khai UI trước các stable ids/reference contracts này.

### VPN

F6 cho tạo site-to-site/remote access, F2 cho tunnel profiles, F5 cho relationship/path và F1 cho health/SA. Subfeatures: IKE proposal/policy, IPsec transform/profile, peer/tunnel, routing/interesting traffic, status/log. Secret và certificate lifecycle là gate.

### Topology

F5 với node/link canvas, layer device/interface/VLAN/VRF/routing/VPN, search, inspector và path trace. Cần list fallback và không cho graph tự suy đoán relationship không có source/confidence.

## 14. Monitor và notification/task

### Monitor

Đề xuất F1 theo scope Device -> Feature -> Metric:

- Health summary, reachability, CPU/RAM nếu có nguồn.
- Interface status/counters/errors.
- Routing neighbors/routes, DHCP utilization, NAT sessions, VPN health.
- Event timeline và filter device/severity/source/time.

Không xây chart trước telemetry contract, sampling interval, retention và stale policy. Chart phải có table/value fallback.

### Notification/task

Giữ toast cho sự kiện ngắn. Mở rộng NotificationPanel thành task/log console F7 có severity, source, device, operation, progress, timestamp, result, retry/copy/export và retention. Preview/push chạy nền phải tạo task item thay vì chỉ toast.

## 15. Settings và Database

### Settings

Theme/Accent/Status Bar đã khá chi tiết; External Tools có view riêng; General và Advanced còn placeholder.

Đề xuất F8:

- Tách file lớn thành category components.
- Theme: live preview + reset section + high contrast/system option.
- General: language, startup, default feature, confirm destructive action, autosave policy.
- Advanced: logging level, dev mode, diagnostics/export, experimental flags; cảnh báo scope/restart.
- Search trả về setting row cụ thể, không chỉ category.

### Database Browser

Hiện có table sidebar, View/Edit/Reload, column Repeater và virtualized row list; edit cell trực tiếp khi table có rowid.

Đề xuất F7:

- Xác định đây là admin/dev tool; ẩn khỏi user thường nếu không có permission.
- Table schema metadata quyết định editable column/type; không cho sửa mọi cell string chỉ vì có rowid.
- Search/filter/sort, row detail, copy/export và pagination/virtualization.
- Edit cần diff, validation, transaction result và audit/backup policy; khóa PK/foreign-key nhạy cảm.

## 16. Quy tắc dùng chung nhưng không đồng dạng hóa

- DHCP/Interface/NAT Static dùng chung F2 shell, nhưng field và inspector khác nhau.
- ACL/Firewall/QoS dùng chung F3 ordering/diagnostics, nhưng rule editor domain-specific.
- OSPF/EIGRP/BGP dùng chung F4 process/section/action bar, nhưng không dùng một universal process card chứa mọi field.
- Routing Info/Monitor/NAT Info dùng chung F1 state/filter/table, nhưng metric/card chỉ xuất hiện khi có dữ liệu thật.
- VPN onboarding dùng F6, nhưng vận hành hàng ngày dùng F1/F2/F5; không ép người dùng chạy wizard để chỉnh một tunnel.

## 17. Dependency sản phẩm

```text
FeatureRegistry + Capability + ViewState
    -> Interface stable ids
        -> VLAN / VRF binding / STP port / QoS binding / NAT interface
    -> ACL/Policy model
        -> NAT ACL / Route Map / QoS / Firewall / BGP policy
    -> Routing process/reference model
        -> BGP / VRF route leaking / MPLS / VPN routing
    -> Telemetry + task model
        -> Monitor / Info tabs / Topology overlays / push history
```

Thứ tự triển khai và quality gate chi tiết nằm trong [CONTINUATION_ROADMAP.md](CONTINUATION_ROADMAP.md).
