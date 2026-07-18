# Kiểm nghiệm smart merge

## Baseline `frontend/test`

Baseline trước tích hợp có 84 test:

- 80 pass;
- OSPF và EIGRP fail vì gọi
  `t04_ospf_interface_settings`/`t04_eigrp_interface_settings`;
- đường lỗi giữ SQLite connection làm cleanup temp DB thất bại trên Windows.

Hai lỗi routing là lỗi có sẵn ở nền và được sửa trước khi nhận feature mới.

## Kiểm nghiệm nhánh nguồn

`origin/feature/tools-extension-nqv` được kiểm tra tách biệt. Quan sát:

- 111 test nhưng còn 5 failure logic/contract và một cleanup error;
- EIGRP vẫn lệch bảng canonical;
- UI inventory/semantic icon/loader contract lệch;
- import `core.nat_slots` còn phụ thuộc thứ tự và package không ổn định;
- Logs chưa có backpressure/retention/safety limit;
- installer và native SSH tạo thay đổi hệ thống/bảo mật ngoài contract nền.

Kết luận: không đạt điều kiện merge nguyên khối.

## Test bổ sung

### Routing

- OSPF/EIGRP save-load-repeat không duplicate interface.
- OSPF round-trip `priority` và `auth_key`.
- Resolve `iface_id` và đóng connection đúng.

### Switching

- Navigation chỉ mở feature thật và đúng role.
- VLAN/interface profile lưu transaction.
- Lỗi Port Security rollback mode change.
- Routed Port/SVI/IP routing bị chặn trên SW2.
- Module không expose push action chưa có worker.

### SFTP

- Chặn traversal/separator trong create/rename.
- Không xóa đệ quy local directory.
- Host lạ yêu cầu confirmation; fingerprint đổi bị từ chối.
- Known host chỉ ghi sau exact fingerprint match.
- Listing directory-first/name-sorted.
- Không dùng `AutoAddPolicy` hoặc `shutil.rmtree`.
- QML tải với worker pool tuần tự.

### Device Logs

- Parse TShark field output thành summary, không giữ raw payload trong model.
- Display filter chỉ chấp nhận protocol/IP/port allowlist.
- SQLite session round-trip và retention xóa session cũ.
- Model live cap hoạt động độc lập với DB.
- Controller khởi tạo/xem saved session khi không có TShark.
- Capture limit: 64 packet/batch, 100 ms, 1 giờ, 256 MiB, 250.000 packet.
- QML workspace tải không warning, không chạy probe trong fixture.

### External Tools/Tool Catalog

- Xshell/PuTTY/default association/Installed Applications detection.
- `{password}` bị chặn trước process creation.
- CLI mở SSH Client đang enable cho device active.
- Catalog URL đều HTTPS và thuộc allowlist tĩnh.
- Catalog query không gọi installer/process/package manager.
- Missing app dùng màu/opacity giảm nổi bật; QML tải không warning.

## Full suite cuối

Chạy từ `app/`:

```powershell
$env:QT_QPA_PLATFORM='offscreen'
python -m unittest discover -s tests -v
```

Kết quả ngày 2026-07-16:

- **128/128 test pass** (baseline 2026-07-18, bổ sung database bootstrap/schema parity, asset/QML export, SFTP asset/session log và Switch pre-merge compatibility);
- không QML warning trong smoke tests;
- bao phủ routing, dev worker, DHCP/ACL, NAT, External Tools, Tool Catalog,
  Device Logs, SFTP, Switching, UI contract và QML runtime.

Các gate bổ sung:

```powershell
python -m compileall -q backend core log_monitor sftp_client tests main.py
$env:UV_CACHE_DIR='R:\NetworkTools\.uv-cache'
uv lock --check
git diff --check
```

Kết quả:

- Python compile: pass;
- `uv lock --check`: pass, 56 package resolve;
- whitespace check: pass.

## Kiểm soát hiệu năng/bảo mật

- Logs không probe khi startup app; chỉ probe khi mở workspace.
- Probe/capture, ghi các batch packet vào SQLite và raw decode không chạy trên
  UI thread; thao tác metadata phiên ngắn vẫn được thực hiện đồng bộ.
- Signal packet được batch, model/DB/disk/session đều có giới hạn.
- SFTP I/O chạy ngoài UI thread và tuần tự hóa Paramiko client.
- Unknown SSH host không tự chấp nhận; fingerprint dùng SHA-256.
- Không nhận SHA-1 compatibility override từ nhánh nguồn.
- Tool Catalog không có `subprocess`, `winget`, download hoặc auto-select.
- Không nhận DB/capture/sample nhị phân từ nhánh nguồn.

## Giới hạn đã biết

- Switching là local desired-state; chưa push cấu hình L2 mới xuống thiết bị.
- SFTP chưa có integration environment với SSH/SFTP server thật trong suite.
- Device Logs chưa có lab matrix TShark/Npcap/quyền driver và benchmark traffic
  thật; safety/lifecycle được kiểm tra ở mức code/model/storage/QML.
- Logs hiện lưu packet summary theo device scope; chưa thay thế application event
  log cho connect/sync/View & Push.
- NetworkMonitor, Routing Info paging, database paging/redaction và dirty-state
  policy toàn cục vẫn là backlog.
- `backend cua kien/` và API cấp dự án không bị sửa trong smart merge này; các
  lỗi package/schema/integration của chúng vẫn được theo dõi ở `CODE_AUDIT.md`.
