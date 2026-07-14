# Theo dõi capability và refactor beta

Ngày cập nhật: **2026-07-14**

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
| OSPF | Có | Có, interface CRUD dùng canonical `iface_id` | Routing contract đạt | L2-tested; chưa chứng minh L3/L4 |
| EIGRP | Có | Có, interface CRUD dùng canonical `iface_id` | Routing contract đạt | L2-tested; chưa chứng minh L3/L4 |
| Routing Info | Có trong info DB | Có | QML view load một phần | L2-code |
| DHCP Pool/Excluded/Helper | Có | Có | Dev worker/dispatcher đạt | L3, nhưng validation còn thiếu |
| DHCP Info | Có 5 bảng | Tab disabled/placeholder | Không | L1 |
| Interface L3/Tunnel/WAN/QoS | Có | Có local CRUD | Chưa có persistence test riêng | L2-code |
| ACL | Có | Có local CRUD | Chưa có persistence test riêng | L2-code |
| NAT | Có | Có 6 workflow local | 6 persistence tests đạt | L2-tested |
| NAT Info | Có 7 bảng | Tab disabled/placeholder | Không | L1 |
| VLAN/L2/STP | Có | Chưa có | Không | L1 |
| VRF | Có | Chưa có | Không | L1 |
| BGP | Có template/VRF AF, thiếu feature schema/UI hoàn chỉnh | Disabled | Không | L0 |
| Settings Theme/Status Bar | QSettings | Có | Persistence test đạt | L2-tested |
| External Tools | DB riêng | CRUD có | Chưa có UI/backend test | L2-code |
| Database Browser | Dùng device DB | Có, 500 row | QML view load một phần | L2-code |

## 3. Việc nền tảng đã hoàn thành trong code

- Mapping Feature Bar ↔ Content Area cho BGP dùng global index 4 nhất quán.
- `SectionCard`, `StandardSideBar`, `StandardValidationDialog` không còn trong module.
- Consumer OSPF/EIGRP dùng `ProcessCard`.
- DHCP/NAT Info đã được bọc Loader, nhưng vẫn disabled/placeholder.
- Device context menu có Reconnect.
- Đóng DeviceTab gọi đóng session.
- DeviceSection ẩn khi rỗng; Connected/Waiting auto-expand, Disconnected không auto-expand.
- Settings navigator chỉ còn Theme và External Tools.
- StandardSpinBox dùng left padding 12, đồng hàng với StandardTextField.
- OSPF/EIGRP interface loader/writer/comparator dùng `t04_router_iface_*`, resolve `(host, interface_name)` sang `iface_id`; 4 routing contract test đạt.

## 4. Việc tài liệu cũ đánh dấu sai/chưa hoàn tất

- `BaseCard` chưa được loại bỏ; nó vẫn export và copy gần toàn bộ `ProcessCard`.
- OSPF/EIGRP đã đạt local persistence contract nhưng chưa đạt L3/L4 vì chưa có test push riêng cho hai protocol hoặc bằng chứng thiết bị thật.
- ACL local CRUD có code nhưng chưa được “dev verified”; ACL không có push worker.
- Interface không còn là stub, nhưng chưa có validation/test/push.
- Routing Info có Routes/Config, song chưa auto-reload theo feature activation và không tối ưu cho bảng lớn.
- External Tools CRUD tồn tại, nhưng auto-detect/Browse/argument template chưa có.

## 5. Roadmap ưu tiên

### Phase A — correctness gate

- [x] Sửa toàn bộ OSPF/EIGRP loader/writer/comparator dùng `t04_router_iface_*` + `iface_id`.
- [x] Đảm bảo connection đóng khi repository fail; 19 test non-QML đạt sạch.
- [ ] Sửa QML `UI/Main` smoke fixture để build temp DB, dọn window/timer và trả kết quả ổn định.
- [ ] Thêm backend semantic validation cho host/IP/mask/wildcard/port/range.

### Phase B — UI lifecycle và hiệu năng

- [ ] Command/shortcut registry + reload activation contract.
- [ ] Chuyển NetworkMonitor probe khỏi UI thread.
- [ ] Routing Info: SQL filter/paging + `ListView`, không duplicate ListModel.
- [ ] Dirty-state guard khi reload/chuyển host/đóng tab.

### Phase C — UI/UX cơ bản

- [ ] Password reveal component + selection token.
- [ ] Information search/zoom/line/copy/highlighting.
- [x] Notification History copy từng mục bằng component chung; toast nổi không có Copy. Center có toolbar SVG-only, chiều cao động, severity color cố định và DND/unread QML contract test.
- [x] Activity Bar: Database nằm trên Settings; Console Serial/Logs/SFTP đã hiển thị mờ + disabled như Topology và có QML contract test, chưa tạo Content Area.
- [ ] Database table grouping.
- [ ] External Tools auto-detect/Browse/templates.

### Phase D — feature completeness

- [ ] DHCP Info dashboard từ t09.
- [ ] NAT/ACL Info dashboard từ t10/t11.
- [ ] ACL persistence tests; quyết định View & Push.
- [ ] Interface persistence tests và View & Push scope.
- [ ] Chọn family rồi mới triển khai VLAN/STP/VRF/BGP.

### Phase E — security/production readiness

- [ ] Secret storage/redaction; bỏ `{password}` trong argv.
- [ ] Migration/versioning và backup/restore test.
- [ ] Vendor/lab matrix cho L4.
- [ ] Packaging, CI và supported-OS matrix.

## 6. Quy tắc duy trì

- PR thay capability phải cập nhật bảng mục 2 và thêm/chỉnh test.
- Không hạ lỗi test thành “known limitation” rồi vẫn giữ level cũ.
- Chỉ module SQL canonical quyết định tên bảng.
- Backlog UI/UX chi tiết nằm ở [`PENDING_CHANGES_UI_UX.md`](PENDING_CHANGES_UI_UX.md); issue kỹ thuật ở [`CHANGES_PENDING.md`](CHANGES_PENDING.md).
