# Kiến trúc Cơ sở Dữ liệu (Database Schema)

Hệ thống NetworkTools lưu trữ thông tin nội bộ thông qua **SQLite**. Toàn bộ thiết kế Schema được lưu mặc định trong file `app/UI/main_numbered_tables.sql`.

Khi khởi động ứng dụng lần đầu, hệ thống sẽ sử dụng schema này để tạo tệp runtime `device_network.db`.

## 1. Bảng Trọng Tâm (Thiết bị)

Tất cả các tính năng cấu hình khác đều phụ thuộc (tham chiếu) vào bảng Thiết bị.

```sql
CREATE TABLE t01_devices (
    id INTEGER PRIMARY KEY,
    ip TEXT UNIQUE,            -- Địa chỉ IP (đóng vai trò như ID chuỗi)
    name TEXT,                 -- Tên thiết bị
    device_type TEXT,          -- router, switch, firewall...
    status TEXT,               -- connected, waiting, disconnected
    dev INTEGER DEFAULT 0      -- 0: Thiết bị thật, 1: Giả lập (Dev-mode)
);
```
**Quy tắc:** Khóa ngoại ở các bảng cấu hình sẽ luôn tham chiếu `host TEXT` với giá trị là `t01_devices.ip`.

## 2. Bảng Theo Tính Năng

### 2.1 DHCP
- `dhcp_pools`: Lưu danh sách các IP Pool.
- `dhcp_excluded`: Lưu danh sách các dải IP bị loại trừ.
- `dhcp_helpers`: Lưu địa chỉ helper-address cho từng Interface.

### 2.2 Routing
- `static_routes_db`: Lưu danh sách các định tuyến tĩnh.
- `default_route_db`: Lưu default route.
- `ospf_process` / `ospf_network`: Lưu cấu hình OSPF process ID, Router ID, và các dải mạng được quảng bá.
- `eigrp_process` / `eigrp_network`: Lưu cấu hình hệ thống tự trị (AS) EIGRP.

### 2.3 ACL (Access Control List)
Sử dụng mô hình Parent-Child:
- `ACL_DB`: Bảng Header, lưu ID, Tên, Loại (Standard/Extended), Host và cờ `success`.
- `standard_acl_rules` / `extended_acl_rules`: Bảng chi tiết lưu các sequence (permit/deny) liên kết bằng `acl_id`.

### 2.4 NAT (Network Address Translation)
- `NAT_DB`: Lưu thiết lập NAT chung.
- Bảng phụ: `nat_static_mappings`, `nat_pools`, `nat_interfaces`, `nat_dynamic_rules`.
- `route_map_db` / `route_map_entries`: Bảng lưu Route Map có thể dùng cho NAT.

## 3. Cờ Trạng Thái Dev-Mode (`dev=1`)

Dự án này là đề tài nghiên cứu nên không yêu cầu luôn có thiết bị vật lý.
- Khi người dùng đánh dấu thiết bị là thiết bị giả lập (`dev = 1` thông qua giao diện hoặc Up Dev), mọi quá trình thao tác lưu/xoá trên DB vẫn diễn ra bình thường.
- Tuy nhiên, khi gửi lệnh Push, các backend Workers sẽ bỏ qua quá trình mở SSH thật mà trực tiếp trả về `Success`.
- Đây là cơ chế cốt lõi để test (dev-verified) giao diện và luồng hoạt động DB.

## 4. Quản lý Kết nối Database trong Python

Tại `app/core/database.py`, mọi quá trình truy vấn SQLite phải gọi:
```python
with self._get_connection() as conn:
    # SQL query goes here
    # conn.execute(...)
```
Điều này đảm bảo connection được đóng mở an toàn và tự động commit theo ngữ cảnh context manager (thread-safe).
