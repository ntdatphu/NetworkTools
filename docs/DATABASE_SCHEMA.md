# Kiến trúc cơ sở dữ liệu toàn dự án

Ngày đối chiếu: **2026-07-14**.

NetworkTools hiện không có một schema duy nhất đã được mọi thành phần sử dụng nhất quán. Có ít nhất hai họ schema: runtime desktop trong `app/` và schema của backend dự án trong `backend cua kien/`. Tài liệu phải giữ ranh giới này cho tới khi có migration/integration test chứng minh chúng đã hợp nhất.

## 1. Ma trận nguồn dữ liệu

| Database/nguồn | Authority hiện tại | Vai trò | Trạng thái |
|---|---|---|---|
| `app/device_network.db` | `app/database/schema/*.sql` | Device và cấu hình desktop cần quản lý/push. | Runtime desktop đã dùng; 72 bảng. |
| `app/info_collected.db` | `app/database/info_collected/*.sql` | Dữ liệu read-only do collector cung cấp. | Runtime desktop đã đọc một phần; 18 bảng. |
| `app/external_tools.db` | `ExternalToolsManager` tự tạo | Danh mục terminal/SSH/DB tools. | Runtime desktop. |
| `backend cua kien/PyCode/share/database/device_network.db` | Dự kiến từ `backend cua kien/sql/*.sql` | DB cho backend dispatcher/worker. | File chưa tồn tại trong repository; build/path/schema đang lệch. |
| `backend cua kien/sql/main.sql` | Ghép từ `01_...07_*.sql` | SQL tổng hợp backend. | Có 74 bảng không prefix `tNN_`. |

## 2. Schema runtime desktop (`app/`)

### 2.1 Build và startup

```text
app/database/schema/*.sql          ─┐
                                    ├─ build_databases.py
app/database/info_collected/*.sql ─┘     ├─ *.sql tổng hợp
                                          └─ app/*.db runtime
```

Builder tạo DB tạm, bật foreign key, chạy `integrity_check`/`foreign_key_check`, đóng connection rồi replace. `app/main.py` chỉ build database còn thiếu; database đã tồn tại được giữ nguyên. Hiện chưa có migration/versioning cho DB người dùng cũ.

### 2.2 `device_network.db` — 72 bảng

| Nhóm | Nội dung chính |
|---|---|
| t01 | `t01_devices`, YANG credential/config và cờ `dev`. |
| t02 | Tên interface và L3/subinterface/tunnel/WAN/QoS theo `iface_id`. |
| t03 | DHCP pool, excluded range, helper. |
| t04 | Static, OSPF, EIGRP và binding interface. |
| t05 | ACL, NAT ACL, NAT, Route Map và interface binding. |
| t06 | VLAN/L2/STP/port security/QoS/EtherChannel/DHCP trust/SVI. |
| t07 | VRF, route target, interface và routing binding. |

Tên canonical của binding routing interface là:

- `t04_router_iface_ospf`;
- `t04_router_iface_eigrp`.

Repository trong `app/backend/route` đã dùng hai bảng canonical, resolve `interface_name` sang `iface_id` và JOIN để load tên trở lại. Map trong backend dự án `backend cua kien/` vẫn dùng `t04_ospf_interface_settings`/`t04_eigrp_interface_settings`; đây là sai lệch riêng của backend dự án, không còn là lỗi repository desktop.

### 2.3 `info_collected.db` — 18 bảng

| Nhóm | Bảng/chức năng | Trạng thái UI desktop |
|---|---|---|
| t08 Routing | routing table | Đọc theo host; chưa page/virtualize. |
| t09 DHCP | pool, binding, conflict, statistics, database | Tab disabled/placeholder. |
| t10 ACL | ACL/rules/MAC/interface/collection | Chưa có dashboard. |
| t11 NAT | pool/static/dynamic/translation/statistics/collection | Tab disabled/placeholder. |

Dữ liệu collected cần timestamp/snapshot/retention riêng; không dùng `success`/`action_Cfg` như hàng cấu hình chờ push.

### 2.4 Trạng thái desktop

- `success = -1`: chờ xóa;
- `success = 0`: chờ thêm/cập nhật;
- `success = 1`: đã áp dụng/đồng bộ;
- `action_Cfg`: bit string/bitmask cho một số nhóm;
- `t01_devices.dev = 1`: worker desktop Routing/DHCP mô phỏng thay vì mở session thật.

Đây là contract của runtime desktop đã đọc/test, không tự động áp dụng cho mọi script backend nếu chúng dùng schema khác.

## 3. Schema backend dự án (`backend cua kien/`)

### 3.1 Nguồn SQL

`backend cua kien/sql/01_...07_*.sql` tạo **74 bảng** với tên không prefix, ví dụ:

- `devices`, `yangcfg`;
- `interface_name`, `router_iface_l3`;
- `dhcp_pool`, `excluded_address`, `router_iface_helper`;
- `ospf_processes`, `ospf_interface_settings`, `router_iface_ospf`;
- `eigrp_processes`, `eigrp_interface_settings`, `router_iface_eigrp`;
- `acl_db`, `nat_db`, bảng L2 và VRF.

Khác biệt đáng chú ý: schema backend chứa đồng thời bảng `*_interface_settings` và `router_iface_*`, trong khi schema desktop đã chuẩn hóa quanh `t04_router_iface_*`.

### 3.2 Hai đường build backend

- `controllers/database/init_db.py --sql <dir|file> --db <path>`: nếu nhận thư mục, chạy các file `.sql` theo thứ tự và bỏ `main.sql`. Đây là implementation có path do caller cung cấp.
- `build_db.py`: xóa DB cũ rồi đọc `backend cua kien/main.sql`; file này **không tồn tại**, vì SQL tổng hợp nằm trong `backend cua kien/sql/main.sql`. Script cũng in “27 bảng” dù schema kiểm đếm được 74 bảng.

Không chạy `build_db.py` trên dữ liệu cần giữ: script chủ động xóa DB cũ trước khi đọc/build.

### 3.3 `DB_TABLES` không khớp schema backend

`backend cua kien/PyCode/share/config.py` map 42 tên dạng `t01_...`/`t04_...`/`t05_...`. Kết quả đối chiếu:

```text
Tên trong DB_TABLES:                 42
Tên tồn tại trong backend/sql:        0
Tên gần tương ứng trong app schema:  40
Tên legacy không có ở app schema:     2
```

Hai tên legacy là `t04_ospf_interface_settings` và `t04_eigrp_interface_settings`. Điều này cho thấy code backend gần với quy ước bảng desktop hơn SQL backend, nhưng vẫn không khớp hoàn toàn với bên nào.

### 3.4 Đường dẫn DB không khớp tên thư mục

Config backend yêu cầu `.env` ở gốc và mặc định:

```text
DB_RELATIVE_PATH=backend/PyCode/share/database/device_network.db
```

Repository thật dùng `backend cua kien/`, `.env` không được commit và DB mặc định chưa tồn tại. SQLite có thể âm thầm tạo file rỗng nếu caller mở path sai; mọi entry point phải kiểm tra schema/version trước khi thực thi query.

## 4. Snapshot và fixture khác

Các nguồn sau không phải authority chung của toàn dự án:

- `app/UI/main.sql`, `app/UI/main_numbered_tables.sql`;
- `app/network_code/sql/*.sql`;
- `app/database/main_numbered_tables new.sql`;
- `mock/data.sql` (đang rỗng);
- `mock/nqv/build_sql.*` (thiếu thư mục nguồn tại vị trí hiện tại).

Chúng vẫn là file của dự án, nhưng chỉ nên dùng làm snapshot/fixture sau khi ghi rõ version và consumer.

## 5. Contract hợp nhất cần có

Trước khi desktop, API và backend cùng dùng một DB:

1. chọn schema authority và quy ước tên bảng duy nhất;
2. thêm `schema_version` và migration có rollback/backup;
3. bỏ mọi path phụ thuộc current working directory;
4. inject DB path qua config/CLI, xác minh file tồn tại và đúng schema;
5. chạy foreign key/integrity check;
6. tạo integration test cho API → dispatcher → DB fixture → worker giả;
7. quy định owner của trạng thái `success`, `action_Cfg`, collector timestamp và transaction;
8. không để hai tiến trình ghi cùng DB mà thiếu busy timeout/WAL/retry/concurrency policy.

## 6. Bảo mật và vận hành

- Password thiết bị/YANG/PPP hiện còn plaintext trong schema/code.
- Database Browser desktop có thể lộ/sửa cột nhạy cảm.
- Backend tạo inventory chứa password và nhiều request tắt TLS/host-key verification.
- Backup/running-config và fixture có thể chứa secret.

Cần chuyển secret sang OS keyring/secret store, DB chỉ lưu reference; redact khi export/log/API; đặt retention/permission cho backup. Xem [CODE_AUDIT.md](CODE_AUDIT.md).
