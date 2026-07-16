# Kiểm nghiệm merge

## Baseline trên `frontend/test`

Lệnh:

```powershell
$env:QT_QPA_PLATFORM='offscreen'
uv run python -m unittest discover -s tests -v
```

Kết quả trước tích hợp:

- 84 test;
- 2 failure logic:
  - OSPF gọi `t04_ospf_interface_settings`;
  - EIGRP gọi `t04_eigrp_interface_settings`;
- 2 cleanup error do SQLite connection chưa đóng làm khóa temporary DB trên
  Windows;
- 80 test khác pass.

Hai lỗi routing được xem là lỗi có sẵn của nhánh nền, không phải regression từ
nhánh tính năng.

## Kiểm nghiệm `origin/feature/tools-extension-nqv`

Nhánh được checkout ở một detached worktree riêng để không làm bẩn nhánh đích.

Kết quả quan sát:

- nhóm backend/module: 48 test, còn lỗi EIGRP canonical table và lỗi cleanup;
- nhóm QML/UI: 63 test, 4 failure contract:
  - inventory `StandardButton` lệch;
  - inventory Cancel lệch;
  - Save action thiếu semantic icon;
  - số async loader lệch;
- tổng cộng 111 test, có 5 failure logic/contract và một cleanup error.

Khi chạy cô lập riêng routing contract và UI contract, UI contract còn phụ
thuộc thứ tự import: `core.nat_slots` không import được `add_nat_acl` từ package
`network_code.nat`. Lỗi này không được cộng thêm vào thống kê full discovery
111 test ở trên, nhưng là thêm một lý do không xem nhánh nguồn như một khối có
thể merge an toàn.

Do đó nhánh này không đạt điều kiện merge nguyên khối.

## Test thêm cho smart merge

### Routing contract

- OSPF save/load/repeat không duplicate interface.
- OSPF round-trip `priority` và `auth_key`.
- EIGRP save/load/repeat không duplicate interface.
- Connection đóng đúng để temp DB được cleanup.

### Switching

- Navigation chỉ mở tính năng có implementation và đúng role.
- VLAN/interface profile lưu trong transaction.
- Lỗi Port Security trên trunk rollback mode change.
- Routed Port, SVI và IP routing bị chặn trên SW2.
- SVI unique theo `(host, vlan_id)`.
- Module mới không chứa View Push/network push token.

### SFTP

- Chặn path traversal/separator trong create/rename.
- Không xóa đệ quy local directory.
- Host lạ luôn yêu cầu confirmation.
- Fingerprint thay đổi bị từ chối.
- Key chỉ được ghi sau exact fingerprint match.
- Remote listing directory-first/name-sorted.
- Không dùng `AutoAddPolicy` hoặc `shutil.rmtree`.
- QML workspace tải thật với backend và worker pool một luồng.

## Kết quả từng checkpoint

| Checkpoint | Kết quả |
|---|---|
| Routing contract sau sửa | 2/2 pass |
| Routing + Switching | 7/7 pass |
| Routing + Switching + SFTP backend | 15/15 pass |
| QML smoke sau Switching | Runtime pass; chỉ còn inventory contract cũ |
| QML smoke sau SFTP | 22/22 pass |
| UI contract sau cập nhật inventory | 36/36 pass |

## Full-suite cuối

Lệnh:

```powershell
$env:QT_QPA_PLATFORM='offscreen'
$env:UV_CACHE_DIR='R:\NetworkTools\.uv-cache'
uv run python -m unittest discover -s tests -v
```

Kết quả:

- **98/98 test pass**;
- QML smoke: 22/22 pass, không có warning;
- UI contract: 36/36 pass;
- `uv lock --check`: pass, 56 package được resolve;
- `python -m compileall -q backend core sftp_client tests main.py`: pass;
- `git diff --check`: không có whitespace error.

Trong lần full-suite đầu tiên, một test scroll của `ConfigTextViewer` bị timing
do content height chưa layout xong sau khi thay text lớn. Test này pass khi chạy
cô lập; harness sau đó được gia cố để đợi `maximumScrollY` sẵn sàng trước khi
assert. Full-suite kế tiếp pass 98/98.

## Giới hạn đã biết

- Switching hiện là local desired-state workspace; chưa push cấu hình mới xuống
  thiết bị. Các view DHCP/ACL tái sử dụng vẫn giữ hành vi push vốn có của chúng.
- SFTP test không kết nối tới server thật trong CI/local suite; protocol service
  được kiểm tra ở mức policy, model, safety và QML lifecycle. Cần thêm một
  integration environment có SSH/SFTP server dùng key cố định nếu muốn chứng
  nhận transfer end-to-end trên mạng.
- Packet capture, system installer và backend API mới được hoãn có chủ đích,
  không phải phần chưa merge sót.
