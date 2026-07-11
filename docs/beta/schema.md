# Schema.md — Theo dõi tiến độ refactor `refactor/frontend-beta`

Ngày tạo: 2026-07-12
Phạm vi: nhánh `refactor/frontend-beta` (từ `frontend/beta`)
Vai trò: đây là tài liệu theo dõi tiến độ + đặc tả công việc, thay thế phần "Capability matrix / roadmap" sai lệch trong `docs/beta/UI_BETA_PLAN.md`.

---

## 0. Nguyên tắc cốt lõi của dự án (ghi đè `UI_BETA_PLAN.md`)

Dự án này là đồ án nghiên cứu khoa học, **chưa có** — và **không bắt buộc phải có** — thiết bị mạng thật hay controller push thật cho từng feature. Quy trình làm việc đúng là:

1. **Thiết kế Database trước** (schema SQL, đã có sẵn phần lớn trong `app/UI/main_numbered_tables.sql` và `app/network_code/sql/*.sql`).
2. **Thiết kế Frontend (QML) trước**, dựa theo họ giao diện thống nhất (xem mục 2), gắn với local CRUD trên DB qua repository Python (`backend/*`, `core/*_slots.py`).
3. **Kiểm nghiệm hoạt động Frontend ↔ Database** bằng cơ chế **`dev` flag** có sẵn (`t01_devices.dev`) và hai nút **`Up (Dev)` / `Down (Dev)`** trong `DeviceContextMenu.qml` → `DevicesPanel.handleUpDevDevice/handleDownDevDevice` → `dbManager.setDeviceDevState()`.
   - Người thiết kế thêm một thiết bị "giả" (`dev = 1`) không cần định tuyến/kết nối thật.
   - Khi push (nếu feature có preview/push), worker (`worker_routing.py`, `worker_dhcp.py`, …) phát hiện `dev = 1` → **bỏ qua login/CLI thật**, trả về report `success` giả lập → dispatcher vẫn cập nhật đúng `success = 0 → 1` hoặc xoá row `success = -1`.
   - Đây là cách duy nhất bắt buộc để coi một feature là "đã kiểm nghiệm", **không** cần chờ có controller push thật.
4. Vì vậy, **capability không được gate theo "có controller thật hay không"**. Capability đúng của dự án chỉ có 2 trục độc lập:
   - **Trục A — Frontend + DB local**: có form nhập liệu, có bảng DB, có CRUD (save/load/delete) hoạt động đúng.
   - **Trục B — Dev-mode verified**: round-trip CRUD + (nếu áp dụng) luồng preview/push đã được test qua `dev=1`, xác nhận state `success`/`action_Cfg` đúng vòng đời.
   - Việc có controller thật (SSH/RESTCONF push xuống switch/router thật) là **giai đoạn sau cùng, không bắt buộc** để feature được xem là "hoàn thành" trong phạm vi đồ án.

### Mức hoàn thành chuẩn hoá (dùng thay cho bảng capability cũ)

| Mức | Tên | Định nghĩa |
|---|---|---|
| L0 | Chưa có | Không có schema, không có UI |
| L1 | Có Schema | Bảng SQL đã thiết kế trong `main_numbered_tables.sql` / `network_code/sql` |
| L2 | Có Frontend + Local CRUD | Có QML form theo đúng họ giao diện; có repository Python đọc/ghi DB thật (không phải `StubSlotsMixin`); Save/Load/Delete hoạt động, `success` chuyển trạng thái đúng |
| L3 | Dev-verified | Đã test bằng thiết bị `dev=1` qua `Up(Dev)`; nếu feature có preview/push, worker mô phỏng đúng và dispatcher cập nhật DB đúng (test tự động nên có trong `app/tests/`) |
| L4 | Push thật (tuỳ chọn, không bắt buộc) | Có controller thật test trên thiết bị/lab thật |

**Định nghĩa "Done" của dự án = đạt L3.** L4 là mở rộng tương lai, không nằm trong scope bắt buộc.

---

## 1. Mục tiêu của nhánh `refactor/frontend-beta`

1. **Tối ưu hiệu năng & khắc phục nhược điểm hiện có** của `frontend/beta`.
2. **Thiết kế logic + giao diện hợp lý, thống nhất theo họ giao diện (interface families)** — mỗi feature mới chọn 1 họ phù hợp thay vì tự vẽ lại từ đầu.
3. **Dọn dẹp component**: loại bỏ component tồn tại nhưng không dùng/gây lãng phí, bổ sung component dùng chung còn thiếu, thống nhất taxonomy (Base* vs Standard*).
4. **Sửa lỗi tồn đọng** về UX/UI, logic, hiển thị lỗi, hiệu năng, hành vi sai.

---

## 2. Họ giao diện (Interface Families) — nguồn sự thật cho thiết kế mới

Giữ nguyên concept từ `UI_BETA_PLAN.md` mục 4 (hợp lý), nhưng bỏ phần gate theo capability. Mỗi feature mới **phải** khai báo rõ mình dùng họ nào trước khi code.

| Họ | Dùng cho | Trạng thái hiện tại |
|---|---|---|
| **F1 — Observe/Info Dashboard** | Routing Info, DHCP Info, NAT Info, Monitor | Routing Info đã có (`info_routing.qml`) làm mẫu tốt; DHCP/NAT Info còn là "Not yet implemented" |
| **F2 — Entity Workspace** (list + form + saved-list panel) | DHCP Pool/Excluded/Helper, Interface, NAT Static/Interfaces/PAT/Dynamic | Đã có pattern `SplitFormPane + SavedListPanel + SavedListHeader + SavedListRow`, dùng khá nhất quán |
| **F3 — Policy/Rule Workspace** (rule table có thứ tự + rule editor theo loại) | ACL (Standard/Extended/Dynamic/Reflexive/MAC), NAT ACL, Route Map | Đã có `AclRuleInput*.qml` tái sử dụng tốt; còn thiếu backend thật (xem mục 5) |
| **F4 — Process Workspace** (process card + section tab + pinned header) | OSPF, EIGRP, (tương lai: BGP) | Đã có `BaseCard` (tên gây hiểu lầm) + `*PinnedHeader` + `*Section.qml`; đây là pattern tốt nhất hiện tại, nên nhân rộng |
| **F5 — Guided Setup** | New Device, Batch New Device | Đã có, ổn |
| **F6 — Operations/Inspector** | CLI, Database Browser, notification/task log | Có Database Browser + ToastManager; CLI chỉ mở terminal ngoài |
| **F7 — Settings Catalog** | Theme, External Tools, General, Advanced | Theme + External Tools đã thật; General/Advanced còn placeholder |
| **F8 — Relationship/Topology** (dự phòng) | VLAN/VRF/STP/Topology tương lai | Chưa có bất kỳ implementation nào |

> Quy tắc: khi thiết kế VLAN/VRF/STP/BGP/QoS/... (chưa có UI), **chọn 1 trong các họ trên trước**, không tự sáng tạo layout mới trừ khi thật sự không có họ nào phù hợp — nếu vậy, bổ sung họ mới vào bảng này trước khi code.

---

## 3. Kiểm kê component — vấn đề cần xử lý

### 3.1 Component có vấn đề (cần quyết định: sửa / đổi tên / xoá)

| Component | Vấn đề | Việc cần làm |
|---|---|---|
| `components/base/BaseCard.qml` | Tên gợi ý "card nền tảng chung" nhưng thực chất là process-card riêng cho OSPF/EIGRP (đã có comment `UI-P1-05` ghi nhận) | ☐ Đổi tên thành `ProcessCard.qml` (hoặc tương tự) qua migration có kiểm tra toàn bộ import; không merge với `SectionCard` |
| `components/base/SectionCard.qml` | File rỗng (`Item {}`), không ai dùng | ☐ Quyết định: xoá hẳn, hoặc định nghĩa vai trò thật (ví dụ: card tiêu đề section dùng chung cho F1/F2) rồi implement |
| `components/standard/StandardSideBar.qml` | Bản sao logic gần như 100% của `DevicesPanel.qml`, không có consumer nào (ghi rõ trong comment `UI-P1-06`) | ☐ Xoá sau khi grep xác nhận 0 import trong toàn bộ `UI/qmldir` và các `.qml` khác |
| `components/standard/StandardValidationDialog.qml` | Cần rà soát consumer thực tế (không thấy import trong các file đã cung cấp) | ☐ Kiểm tra usage thật; nếu không dùng, gộp vào `CustomAlert.qml` hoặc xoá |
| `RoutingSubBar` / `DhcpSubBar` / `AclSubBar` / `NatSubBar` | Đều chỉ là `SubBar` với `tabs` khác nhau — ổn, nhưng `SubBar.displayTabText()` hard-code switch-case tên hiển thị cho **tất cả** feature trong 1 file dùng chung | ☐ Cân nhắc đổi label qua property thay vì switch-case tập trung, để feature mới không phải sửa `SubBar.qml` |
| `RoutingProcessComboBox.qml` | Dùng chung tốt cho OSPF/EIGRP — giữ nguyên, dùng làm mẫu khi thêm BGP |

### 3.2 Component còn thiếu (cần bổ sung)

| Thiếu | Lý do cần | Feature sẽ dùng |
|---|---|---|
| **Generic Process Navigator** (tách phần chung của `OspfPinnedHeader`/`EigrpPinnedHeader` + `OspfRoutingForm`/`EigrpRoutingForm`) | 2 implementation gần như song song (đếm process, đếm network, section tab, dirty flag) → dễ lệch khi sửa 1 bên quên bên kia | OSPF, EIGRP, tương lai BGP (F4) |
| **Generic Rule Table component cho F3** | ACL đã có `AclRuleRow.qml` khá tốt, nhưng NAT ACL / Route Map lại tự vẽ bảng riêng trong `NatAclForm.qml`/`NatRouteMapForm.qml` | NAT ACL, Route Map nên tái dùng `AclRuleRow`-style |
| **Capability/Empty/Error state chuẩn cho F1** | Routing Info tự implement loading/error riêng; DHCP/NAT Info chỉ là `Text "Not yet implemented"` — không nhất quán | DHCP Info, NAT Info khi triển khai |
| **Confirm-delete dialog dùng chung** | Hiện `CustomAlert` được tái dùng thủ công làm confirm-dialog (`DevicesPanel.qml`), copy logic `targetIp` mỗi nơi cần confirm | ACL/NAT delete actions (hiện chưa có confirm trước khi xoá rule) |

---

## 4. Lỗi tồn đọng cần khắc phục (bugs)

| # | Lỗi | File liên quan | Mức độ |
|---|---|---|---|
| 1 | `FeatureBar.qml` khai báo `globalIndex: 4` là `bgp`, nhưng `ContentArea.textFeatureNames[4]` là `"BGP"` — **cần xác nhận lại**: `allTextFeatures` trong `FeatureBar.qml` index 4 = `bgp`, còn `ContentArea.textFeatureNames` index 4 = `"BGP"` — thực ra khớp; nhưng đã ghi nhận trong `changes.md` là có lệch (VRF vs BGP) — **cần verify lại thực tế trong code, vì có thể đã tự sửa hoặc tài liệu cũ sai** | `qml/feature/FeatureBar.qml`, `qml/content/ContentArea.qml` | P0 — verify trước |
| 2 | ACL/NAT: `saveAcl`/`addNat*` gọi thật `dbManager.*` nhưng backend là `StubSlotsMixin` → UI báo "ACL đã lưu" (`statusBar.showMessage(...)`) dù **không ghi gì vào DB** | `core/database_stubs.py`, `AclForm.qml`, `Nat*.qml` | P0 — sai lệch UI/thực tế nghiêm trọng nhất |
| 3 | `NatView.qml` tab "Info" không load qua `Loader` như các tab khác, chỉ là `Text` tĩnh — không đồng bộ pattern lazy-load đã áp dụng cho các tab khác | `qml/nat/NatView.qml` | P2 |
| 4 | `DhcpView.qml` tab "Info" tương tự — static text, không theo pattern `Loader` | `qml/dhcp/DhcpView.qml` | P2 |
| 5 | Toàn bộ form OSPF/EIGRP `validate()` đã tốt (dùng `ValidationUtils.js`), nhưng ACL/NAT **chưa có validate trước khi gọi backend** — do đang là stub nên chưa lộ, nhưng khi lên L2 cần thêm | `AclForm.qml`, `Nat*.qml` | P1 — cần làm cùng lúc với việc thêm backend thật |
| 6 | `docs/beta/*.md` có trailing whitespace (theo `changes.md` mục 6) — nợ format nhỏ | `docs/beta/*.md` | P3 |

---

## 5. Kế hoạch theo giai đoạn (Roadmap thực tế, thay thế roadmap cũ)

### Phase A — Xác minh & sửa nền tảng (P0)
- [ ] Verify lại thực tế mapping `FeatureBar` ↔ `ContentArea` (index BGP/VRF) bằng cách chạy app, không tin tài liệu cũ
- [ ] Quyết định số phận `SectionCard.qml`, `StandardSideBar.qml`, `StandardValidationDialog.qml`
- [ ] Đổi tên `BaseCard.qml` → tên phản ánh đúng vai trò (process card), cập nhật `qmldir` + mọi import

### Phase B — ACL: nâng lên L2 rồi L3
Schema đã có sẵn (`ACL_DB`, `standard_acl_rules`, `extended_acl_rules`, `dynamic_acl_rules`, `reflexive_acl_rules`, `mac_acl_rules`, `router_iface_acl` trong `main_numbered_tables.sql`).
- [ ] Tạo `app/backend/acl/` (mirror cấu trúc `app/backend/dhcp/` hoặc `app/backend/route/`): `common.py`, `acl_db.py` (CRUD `ACL_DB` + rule con theo từng loại), `__init__.py`
- [ ] Tạo `AclSlotsMixin` (giống `DhcpSlotsMixin`) trong `core/acl_slots.py`, expose `getAcls`, `saveAcl`, `deleteAcl` thật
- [ ] Sửa `core/database.py`: `class DatabaseManager(DhcpSlotsMixin, AclSlotsMixin, StubSlotsMixin, QObject)` (thứ tự mixin quan trọng — Python MRO ưu tiên trái sang phải, mixin thật phải đứng trước `StubSlotsMixin`)
- [ ] Thêm validate trước khi gọi backend trong `AclForm.qml` (network/wildcard/port dùng `ValidationUtils.js` sẵn có)
- [ ] **Kiểm nghiệm L3**: thêm 1 thiết bị `dev=1` qua UI (`Ctrl+N` → chưa cần bật `dev`, dùng `Up (Dev)` sau khi thêm), tạo ACL, xác nhận round-trip Save→Reload đúng
- [ ] (Tuỳ chọn L4 sau này) worker push ACL thật — không bắt buộc trong scope hiện tại

### Phase C — NAT: nâng lên L2 rồi L3
Schema đã có sẵn đầy đủ (`NAT_DB`, `NAT_ACL_DB`, `nat_interfaces`, `nat_pools`, `nat_static_mappings`, `nat_dynamic_rules`, `nat_overload_interface_rules`, `nat_exempt_rules`, `route_map_db`, `route_map_entries`).
- [ ] Tạo `app/backend/nat/` tương tự Phase B
- [ ] `NatSlotsMixin` cho `getNatStaticEntries/addNatStaticEntry/...`, tương tự cho Interfaces/Dynamic/PAT/ACL/RouteMap
- [ ] Sửa thứ tự mixin trong `DatabaseManager`
- [ ] Kiểm nghiệm L3 qua `dev=1` giống Phase B

### Phase D — Thống nhất Component (song song, không phụ thuộc Phase B/C)
- [ ] Xử lý mục 3.1 (BaseCard rename, SectionCard, StandardSideBar, StandardValidationDialog)
- [ ] Tách Generic Process Navigator dùng chung cho OSPF/EIGRP (giảm trùng lặp `OspfRoutingForm.qml` / `EigrpRoutingForm.qml`)
- [ ] Chuẩn hoá F1 (Observe/Info) empty/loading/error state, áp dụng khi làm DHCP Info / NAT Info thật

### Phase E — Feature mới (VLAN/VRF/STP/BGP/...) — chỉ bắt đầu sau khi Phase A xong
Với mỗi feature mới, thứ tự bắt buộc:
1. Khai báo họ giao diện dùng (mục 2)
2. Viết/khẳng định schema SQL (nếu đã có sẵn trong `sql/06_l2_switching.sql`, `sql/07_vrf.sql` thì audit lại cho khớp yêu cầu)
3. Viết QML form theo họ đã chọn + repository Python CRUD thật (L2)
4. Kiểm nghiệm bằng `dev=1` (L3)
5. Ghi nhận vào bảng tiến độ mục 6

---

## 6. Bảng tiến độ theo Feature (cập nhật liên tục — nguồn sự thật duy nhất)

| Feature | Mức hiện tại | Họ giao diện | Ghi chú |
|---|---|---|---|
| Device management (list/add/edit/delete/Up-Down Dev) | L3 | F5 + F2 | Đã hoạt động, là cơ chế kiểm nghiệm cho toàn bộ dự án |
| Static Routing | L3 | F2 | Có preview/push, đã test dev-mode (`test_dev_mode_workers.py`) |
| OSPF | L3 | F4 | Tương tự |
| EIGRP | L3 | F4 | Tương tự |
| Routing Info | L2 | F1 | Đọc dữ liệu thu thập, chưa có test dev-mode riêng (không cần vì read-only) |
| DHCP Pool/Excluded/Helper | L3 | F2 | Có preview/push, đã test |
| DHCP Info | L0 | F1 | Chưa implement, còn placeholder |
| Interface (Router L3/WAN/Tunnel/QoS) | L2 | F2 | Local CRUD thật (`backend/dhcp/interfaces.py`), **chưa** có preview/push — chưa cần L3 vì chưa có luồng push riêng |
| ACL (Standard/Extended/Dynamic/Reflexive/MAC) | L1 (schema có) | F3 | UI có, backend là stub → **ưu tiên Phase B** |
| NAT (Static/Dynamic/PAT/Interfaces/ACL/RouteMap) | L1 (schema có) | F2 + F3 | UI có, backend là stub → **ưu tiên Phase C** |
| VLAN | L1 (schema có, `vlan_db`, `interface_l2`, ...) | Chưa chọn (đề xuất F2) | Chưa có QML |
| VRF | L1 (schema có, `vrf_db`, ...) | Chưa chọn (đề xuất F4 nếu coi VRF như "process" gắn OSPF/EIGRP/BGP; hoặc F2 nếu coi là entity độc lập) | Chưa có QML |
| STP | L1 (`stp_config`) | Chưa chọn | Chưa có QML |
| BGP | L0 (chưa có bảng BGP trong schema hiện tại) | F4 (dự kiến) | Tab hiện đang disabled trong `RoutingSubBar` |
| QoS/SNMP/NTP/AAA/MPLS/VPN/Firewall/Monitor | L0 | Chưa chọn | Chưa có gì |
| Settings (Theme, External Tools) | L3 (đã dùng thật, có QSettings) | F7 | Ổn |
| Settings (General, Advanced) | L0 | F7 | Placeholder |
| Database Browser | L3 | F6 | Đã hoạt động, có test |

---

## 7. Quy tắc duy trì tài liệu này

- Mỗi PR thay đổi mức hoàn thành của 1 feature (L1→L2, L2→L3, ...) **phải** cập nhật bảng mục 6 trong cùng PR.
- Không đánh dấu L3 nếu chưa thực sự chạy qua `dev=1` (không suy luận từ "code trông đầy đủ").
- Không đưa lại giả định "chưa có backend thật = chưa merge/chưa evaluate được" — đó là quan điểm sai đã bị loại bỏ ở mục 0.
- Khi thêm họ giao diện mới, bổ sung vào bảng mục 2 kèm ít nhất 1 feature ví dụ.