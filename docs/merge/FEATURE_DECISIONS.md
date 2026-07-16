# Quyết định theo tính năng

## Ma trận quyết định

| Tính năng | Nguồn tham chiếu | Quyết định | Cách tích hợp |
|---|---|---|---|
| OSPF interface persistence | `feature/tools-extension-nqv` | Nhận có chỉnh sửa | Chuyển toàn bộ load/compare/save/archive sang bảng chuẩn và bổ sung test priority/auth key. |
| EIGRP interface persistence | Lỗi baseline + schema hiện tại | Sửa đồng bộ | Áp dụng cùng hợp đồng canonical như OSPF, resolve `iface_id`, đóng connection đúng cách. |
| Switching workspace | `feature/tools-extension-nqv` | Viết lại có chọn lọc | Tách backend repository, role-aware navigation, local SQLite transaction, QML dùng token/component hiện tại. |
| SFTP client | `origin/sftp`, `feature/tools-extension-nqv` | Viết lại và gia cố | Package đúng tên `sftp_client`, UI độc lập, host-key confirmation, I/O worker, không dùng bộ icon riêng hàng chục file. |
| Packet capture / Log | `feature/tools-extension-nqv` | Viết lại | Tách `log_monitor`, probe/capture/decode bất đồng bộ, batching, safety limit và retention. |
| CLI native OpenSSH/Telnet | `feature/tools-extension-nqv` | Loại | Làm mất cấu hình External Tools và hạ bảo mật bằng thuật toán SHA-1. |
| Auto installer `winget` | `feature/tools-extension-nqv` | Thay bằng workflow an toàn | Tool Catalog chỉ detect và mở allowlist vendor URL sau click; không tự cài. |
| DHCP/API backend mới | `origin/main` | Hoãn | Package path, schema và kết quả task nền chưa đúng hợp đồng hiện tại. |
| Interface/OSPF sync | `backup-main-before-merge` | Loại | Import sai và dùng tên bảng legacy. |
| Backend folder rename | `main`, `Chong_cua_Miku` | Loại | Không phải lát cắt tính năng và gây đứt import hiện có. |

## 1. OSPF và EIGRP canonical persistence

### Vấn đề

Baseline gọi hai bảng không tồn tại:

- `t04_ospf_interface_settings`
- `t04_eigrp_interface_settings`

Schema chuẩn đang dùng:

- `t04_router_iface_ospf`
- `t04_router_iface_eigrp`

Hai bảng chuẩn liên kết interface bằng `iface_id`, không lưu trực tiếp tên
interface. Vì vậy chỉ đổi chuỗi tên bảng là chưa đủ.

### Cách sửa

- Join `t02_interface_name` khi load/compare để trả lại `interface_name` cho QML.
- Resolve `iface_id` theo cùng host/process khi insert.
- Archive/reset child rows trên đúng bảng chuẩn.
- OSPF lưu thêm `priority` và `auth_key`, dùng đúng cột
  `interface_name` ở passive-interface.
- Dùng `contextlib.closing` để connection luôn được đóng trên Windows, kể cả
  đường exception.

## 2. Switching workspace

### Phạm vi được mở

SW2:

- Switch Ports;
- VLAN;
- Port Security, Storm Control;
- Port Counters, MAC Table.

SW3 kế thừa SW2 và có thêm:

- Routed Ports;
- SVI và cờ IP routing;
- DHCP Server/Relay bằng view DHCP hiện có;
- ACL bằng view ACL hiện có.

### Phạm vi không mở

STP, EtherChannel, DHCP Snooping và DAI không xuất hiện trong menu vì nhánh
nguồn chỉ có placeholder hoặc chưa có worker/push/test end-to-end. Các trường
loop-protection có persistence trong inspector port, nhưng không được quảng bá
thành một module STP hoàn chỉnh.

### Bảo toàn kiến trúc

- `app/backend/switching/`: repository/validation SQLite.
- `app/core/switch_slots.py`: bridge QML.
- `app/UI/qml/switch/`: presentation.
- Không thêm View Push hay gọi network worker.
- Mỗi lần lưu interface cùng access/trunk/security/storm profile nằm trong một
  transaction; lỗi validation rollback toàn bộ.
- Routed Port, SVI và IP routing bị chặn nếu role không phải `sw3`.
- `getDevices()` ưu tiên role `sw2`/`sw3` để Feature Bar và Content Area dùng
  cùng một nguồn phân loại.

## 3. SFTP workspace

### Khác biệt so với nhánh nguồn

- Đổi package sai chính tả `sftpCient` thành `sftp_client`.
- Không sửa `backend.py` thành namespace package chỉ để né xung đột tên.
- Không nhập khoảng 47 icon riêng; dùng component, token và asset chung.
- Không dùng `shutil.rmtree`; UI chỉ xóa được file hoặc thư mục rỗng.
- Tên create/rename chặn rỗng, `.`, `..`, `/` và `\`.
- Không dùng `AutoAddPolicy`; host lạ phải hiện key type và SHA-256 fingerprint.
- Chỉ ghi `known_hosts` sau khi người dùng chấp nhận đúng fingerprint đã hiển thị.
- Password chỉ tồn tại trong form và `ConnectionOptions` trong bộ nhớ, không có
  persistence.
- Paramiko SFTP được chạy trong `QThreadPool` có `maxThreadCount = 1` vì client
  không thread-safe.
- Shutdown có timeout hữu hạn; transfer được đánh dấu cancel và SSH transport
  được đóng để phá thao tác mạng bị treo.
- Local/remote panels đổi từ hai cột sang một cột khi cửa sổ hẹp.

### Hành vi

- Kết nối bằng password hoặc private key.
- Duyệt path, đi lên, refresh, double-click thư mục.
- Upload/download file hoặc thư mục.
- Theo dõi queue/progress và cancel.
- Tạo thư mục, đổi tên, xóa có xác nhận.

## 4. Device Logs được viết lại

### Vấn đề ở nhánh nguồn

- `tshark -D` và raw decode có đường chạy đồng bộ.
- Phát signal từng packet, dễ làm nghẽn event loop khi traffic cao.
- Model live 10.000 packet nhưng capture/DB/disk không có giới hạn hữu hạn.
- Không có retention, session ownership hoặc xóa capture an toàn.
- Phụ thuộc `psutil` không có trong môi trường chuẩn.
- QML dùng module/component riêng và chưa có contract test đủ sâu.

### Thiết kế trên nhánh đích

- `InterfaceProbeWorker` chạy discovery ở `QThread`; chỉ khởi tạo khi mở Logs.
- `CaptureWorker` gom tối đa 64 packet hoặc 100 ms mỗi signal.
- TShark capture bị giới hạn đồng thời:
  - 3.600 giây;
  - 262.144 KiB;
  - 250.000 packet.
- Controller gom lô 500 ms/128 packet và giao SQLite write cho worker pool tuần
  tự riêng; UI thread chỉ cập nhật model/trạng thái.
- Model live tối đa 5.000 dòng; DB giữ summary để mở lại.
- Giữ 20 session mới nhất; chỉ xóa capture file đã resolve bên dưới capture
  root, không xóa đệ quy.
- Raw packet detail/bytes được decode trong `QThreadPool` một luồng.
- Display filter là parser allowlist nhỏ, không chuyển biểu thức tùy ý vào SQL.
- Nếu không có TShark, saved session vẫn xem được; app không crash và không cần
  `psutil`.
- Logs dùng Activity Bar workspace độc lập; Console Serial vẫn visible/disabled.

### Giới hạn có chủ đích

Capture mới vẫn cần TShark/Wireshark và capture driver/quyền tương ứng trên máy
người dùng. Bộ test không giả lập driver thật; nó kiểm tra parser, storage,
retention, limit, model và QML lifecycle.

## 5. CLI/SSH bị loại, Tool Catalog thay installer

Thay CLI bằng native OpenSSH/Telnet làm mất lựa chọn client do người dùng cấu
hình trong External Tools. Việc ép các thuật toán SHA-1 cũng là hạ cấp bảo mật,
không phải compatibility fix an toàn.

Installer `winget` nguyên bản bị loại vì có thể cài nhiều công cụ hệ thống,
preselect app thiếu và chưa có cancel/lifecycle đủ rõ.

Ý tưởng “giúp người dùng tìm công cụ còn thiếu” được giữ bằng Tool Catalog:

- allowlist tĩnh gồm PuTTY, Xshell, MobaXterm, Tera Term, SecureCRT, Windows
  Terminal, DB Browser for SQLite, WinSCP và Wireshark;
- nhận diện bounded bằng Windows App Paths, PATH/App Execution Alias, uninstall
  registry và known install location;
- trạng thái Configured/Installed/Not installed;
- app chưa cài dùng `Theme.textDisabled` và opacity thấp;
- nút chỉ mở HTTPS URL chính thức sau thao tác người dùng;
- không gọi `subprocess`, `winget`, download hoặc thay default app.

CLI trên Feature Bar tiếp tục gọi SSH Client được enable trong External Tools.
Điều này bảo toàn Xshell/PuTTY/MobaXterm/Tera Term/SecureCRT và không quay lại
Terminal chung.
