# Theo dõi capability và refactor beta

Ngày cập nhật: **2026-07-16**

Đây là capability matrix của **runtime desktop trong `app/`**, không phải inventory toàn dự án. Nguồn bằng chứng: code trong `app/`, schema desktop canonical, test trong `app/tests/` và [`../CODE_AUDIT.md`](../CODE_AUDIT.md). Trạng thái của `backend cua kien/` và `api_server.py` được theo dõi riêng trong audit cấp dự án.

## 1. Mức hoàn thành

| Mức | Ý nghĩa |
|---|---|
| L0 | Chưa có implementation usable. |
| L1 | Có schema canonical, build được. |
| L2-code | Có UI + local repository/CRUD. |
| L2-tested | Contract/persistence test đạt trên schema canonical. |
| L3 | Dev-mode preview/push được test, state pending đúng. |
| L4 | Test trên lab/device thật. |

“Có template”, “QML load” hoặc “có method” không đủ để nâng level.

## 2. Capability matrix đã kiểm chứng

| Feature | Schema | UI/local | Test hiện có | Mức tối đa có thể khẳng định |
|---|---|---|---|---|
| Device management/import/dev flag | Có | Có | UI/QSettings contract một phần | L2-code |
| Session/connect/sync | Có | Có | Chưa có integration test device | L2-code; L4 chưa chứng minh |
| Static Routing | Có | Có | Dev worker/dispatcher đạt | L3 |
| OSPF | Có | Canonical repository/CRUD | 2 routing round-trip/repeat contract đạt | L2-tested |
| EIGRP | Có | Canonical repository/CRUD | 2 routing round-trip/repeat contract đạt | L2-tested |
| Routing Info | Có trong info DB | Có | QML view load một phần | L2-code |
| DHCP Pool/Excluded/Helper | Có | Có | Dev worker/dispatcher đạt | L3, nhưng validation còn thiếu |
| DHCP Info | Có 5 bảng | Tab disabled/placeholder | Không | L1 |
| Interface L3/Tunnel/WAN/QoS | Có | Có local CRUD | Chưa có persistence test riêng | L2-code |
| ACL | Có | Có local CRUD | Chưa có persistence test riêng | L2-code |
| NAT | Có | Có 6 workflow local | 6 persistence tests đạt | L2-tested |
| NAT Info | Có 7 bảng | Tab disabled/placeholder | Không | L1 |
| VLAN/L2/Switch Ports | Có | Switching desired-state theo SW2/SW3 | 5 Switching contract đạt | L2-tested; chưa push |
| STP | Có | Chưa có module hoàn chỉnh | Không | L1 |
| VRF | Có | Chưa có | Không | L1 |
| BGP | Có template/VRF AF, thiếu feature schema/UI hoàn chỉnh | Disabled | Không | L0 |
| Settings Theme/Status Bar | QSettings | Có | Persistence test đạt | L2-tested |
| External Tools | DB riêng | CRUD + Windows discovery/Browse/preview + Device CLI launch có | Manager/QML/contract đạt | L2-tested |
| Tool Catalog | Allowlist code | Detect installed/configured/missing, mở vendor URL | Backend/QML/contract đạt | L2-tested |
| SFTP | Runtime/known_hosts | Local/remote workspace + queue | 8 backend + QML smoke đạt | L2-tested; lab transfer chưa chứng minh |
| Device Logs | SQLite runtime + pcapng | Capture/inspect/saved session | 6 backend + QML smoke đạt | L2-tested; driver/traffic lab chưa chứng minh |
| Database Browser | Dùng device DB | Có, 500 row | QML view load một phần | L2-code |

## 3. Việc nền tảng đã hoàn thành trong code

- Mapping Feature Bar ↔ Content Area cho BGP dùng global index 4 nhất quán.
- `SectionCard`, `StandardSideBar`, `StandardValidationDialog` không còn trong module.
- Consumer OSPF/EIGRP dùng `ProcessCard`.
- DHCP/NAT Info đã được bọc Loader, nhưng vẫn disabled/placeholder.
- Device context menu có Reconnect.
- Đóng DeviceTab gọi đóng session.
- DeviceSection ẩn khi rỗng; Connected/Waiting auto-expand, Disconnected không auto-expand.
- Settings navigator có Theme, External Tools và Tool Catalog.
- StandardSpinBox dùng left padding 12, đồng hàng với StandardTextField.
- External Tools dùng master-detail responsive, discovery Windows bounded có source/confidence/default association, native Browse/validation và preview redacted; candidate không tự lưu.
- `StandardPasswordField` che credential mặc định, có eye toggle; selection token dùng chung đạt contrast tối thiểu 4.5:1 qua runtime test.
- `ConfigTextViewer` dùng chung cho Information/Routing Config đã có search, zoom 9–40 px, gutter đồng bộ, Copy All và semantic highlighting theo chunk.
- Notification Center/DND/toast deduplication, Console Serial placeholder và workspace Logs/SFTP có QML contract/runtime test.
- Feature/subtab loader dùng incubation bất đồng bộ; Device Tab hiển thị spinner tại icon, rapid switch chỉ dựng view cuối và host switch được coalesce một frame.
- Full suite đạt 121/121 ngày 2026-07-17, gồm `UI/Main`, routing canonical, Switching/table family + responsive/cache/contextual inspector, bảng DHCP/NAT và routing networks, SFTP, Device Logs, Tool Catalog, loader lifecycle và Feature Bar CLI.

## 4. Việc tài liệu cũ đánh dấu sai/chưa hoàn tất

- ~~`BaseCard` chưa được loại bỏ~~ — đã xóa cùng `BaseButton` khỏi filesystem/`qmldir` ngày 2026-07-14 sau khi xác nhận không có consumer; OSPF/EIGRP dùng `ProcessCard`.
- ~~OSPF/EIGRP dùng bảng interface legacy~~ — đã chuyển sang schema canonical, resolve `iface_id`, round-trip priority/auth key và đóng connection đúng.
- ACL local CRUD có code nhưng chưa được “dev verified”; ACL không có push worker.
- Interface không còn là stub, nhưng chưa có validation/test/push.
- Routing Info có Routes/Config, song chưa auto-reload theo feature activation và không tối ưu cho bảng lớn.
- External Tools đã có discovery/Browse/template/preview; còn visual regression theme/DPI, accessibility audit đầy đủ và component split.

## 5. Roadmap ưu tiên

### Phase A — correctness gate

- [x] OSPF/EIGRP loader/writer/comparator dùng `t04_router_iface_*` + `iface_id`.
- [x] Connection backend đóng đúng khi repository fail; routing cleanup test đạt.
- [x] QML `UI/Main` smoke tải thành công trong fixture offscreen; full suite đạt 121/121 ngày 2026-07-17.
- [ ] Thêm backend semantic validation cho host/IP/mask/wildcard/port/range.

### Phase B — UI lifecycle và hiệu năng

- [ ] Command/shortcut registry + reload activation contract — PARTIAL: đã có `Ctrl+R` cho Information và `Ctrl+1/2/3` cho Devices/Database/Settings; Save/View & Push/dirty contract còn TODO.
- [ ] Async feature lifecycle — PARTIAL: outer/subtab loader, rapid-switch cancellation, host coalescing và Device Tab spinner đã có; memory budget/dirty-aware eviction/startup + peak-RAM benchmark còn TODO.
- [ ] Chuyển NetworkMonitor probe khỏi UI thread.
- [ ] Routing Info: SQL filter/paging + `ListView`, không duplicate ListModel.
- [ ] Dirty-state guard khi reload/chuyển host/đóng tab.

### Phase C — UI/UX cơ bản

- [x] Password reveal component + selection token; runtime test bao phủ mask/reveal, focus/cursor và contrast theme/accent.
- [x] Information search/zoom/line/copy/highlighting; dùng `ConfigTextViewer` chung và có benchmark 10.000 dòng.
- [x] Notification History copy từng mục bằng component chung; toast nổi không có Copy. Center có toolbar SVG-only, chiều cao động, severity color cố định và DND/unread QML contract test.
- [x] Activity Bar: Database nằm trên Settings; Console Serial hiển thị mờ/disabled; Logs và SFTP đã có workspace active và QML contract.
- [ ] Database table grouping.
- [x] External Tools auto-detect/Browse/templates/preview redacted; còn QA theme/DPI/accessibility tự động.

### Phase D — feature completeness

- [ ] DHCP Info dashboard từ t09.
- [ ] NAT/ACL Info dashboard từ t10/t11.
- [ ] ACL persistence tests; quyết định View & Push.
- [ ] Interface persistence tests và View & Push scope.
- [x] VLAN/Switch Ports đã triển khai theo family Switching và role SW2/SW3.
- [ ] Chọn family rồi mới triển khai STP/VRF/BGP.

### Phase E — security/production readiness

- [ ] Secret storage/redaction toàn dự án; riêng External Tools đã block `{password}` ở Save/launch và không đưa password vào argv.
- [ ] Migration/versioning và backup/restore test.
- [ ] Vendor/lab matrix cho L4.
- [ ] Packaging, CI và supported-OS matrix.

## 6. Quy tắc duy trì

- PR thay capability phải cập nhật bảng mục 2 và thêm/chỉnh test.
- Không hạ lỗi test thành “known limitation” rồi vẫn giữ level cũ.
- Chỉ module SQL canonical quyết định tên bảng.
- Backlog UI/UX chi tiết nằm ở [`PENDING_CHANGES_UI_UX.md`](PENDING_CHANGES_UI_UX.md); issue kỹ thuật ở [`CHANGES_PENDING.md`](CHANGES_PENDING.md).
