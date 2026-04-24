# LOGIN BACKEND PLAN (VI)

## 1. Mục tiêu
- Xây dựng luồng login cho thiết bị dựa trên bảng `devices` trong SQL.
- Hỗ trợ 4 giao thức: SSH, TELNET, RESTCONF, NETCONF.
- Cập nhật trạng thái cột `success`:
  - `1`: login thành công
  - `-1`: login thất bại
  - `0`: chờ xử lý (mặc định trước khi chạy kiểm tra)
  - `3`: bản ghi hệ thống/ẩn (không xử lý)
- Chạy được trên cả Windows và Linux.

## 2. Bảng dữ liệu sử dụng
Bảng chính: `devices`

Các cột dùng cho login:
- `host` (TEXT, PK)
- `device_name` (TEXT)
- `method` (TEXT): SSH | TELNET | RESTCONF | NETCONF
- `portnumber` (INTEGER)
- `username` (TEXT)
- `password` (TEXT)
- `os` (TEXT)
- `role` (TEXT)
- `success` (INTEGER)

## 3. Bản ghi cụ thể (ví dụ)
```sql
INSERT INTO devices
(host, device_name, method, portnumber, username, password, os, role, success)
VALUES
('192.168.10.1', 'R1', 'SSH', 22, 'admin', 'admin123', 'IOS-XE', 'edge', 0);
```

Kết quả sau khi chạy login:
```sql
-- Thành công
UPDATE devices SET success = 1 WHERE host = '192.168.10.1';

-- Thất bại
UPDATE devices SET success = -1 WHERE host = '192.168.10.1';
```

## 4. Cấu trúc file đề xuất
```text
script/
  login/
    login_new.py
    db_client.py
    config.py
    models.py
    requirements.txt
    protocols/
      ssh_adapter.py
      telnet_adapter.py
      restconf_adapter.py
      netconf_adapter.py
```

## 5. Luồng xử lý trong login_new.py
1. Mở SQLite DB (`device_network.db`).
2. Đọc tất cả thiết bị hợp lệ:
   - `success != 3`
   - `host` không rỗng
   - `method` thuộc tập hỗ trợ.
3. Chuẩn hóa method về uppercase.
4. Chọn adapter theo method.
5. Thực hiện login theo timeout cấu hình.
6. Nếu login thành công thì lấy thêm thông tin `os` và `role`.
7. Cập nhật `success`:
   - thành công => `1`
   - thất bại => `-1`
8. Ghi log kết quả theo từng host.

## 6. SQL truy vấn chuẩn
### 6.1 Lấy dữ liệu đầy đủ theo cấu trúc SQL
```sql
SELECT
  host,
  device_name,
  method,
  portnumber,
  username,
  password,
  os,
  role,
  success
FROM devices
WHERE success != 3
  AND host IS NOT NULL
  AND TRIM(host) != '';
```

### 6.2 Cập nhật trạng thái
```sql
UPDATE devices
SET success = ?
WHERE host = ?;
```

### 6.3 Cập nhật đồng thời success, os, role
```sql
UPDATE devices
SET success = ?,
    os = COALESCE(?, os),
    role = COALESCE(?, role)
WHERE host = ?;
```

## 7. Mapping giao thức và cổng mặc định
- SSH -> 22
- TELNET -> 23
- NETCONF -> 830
- RESTCONF -> 443

Gợi ý fallback:
- Nếu `portnumber` NULL thì dùng cổng mặc định theo giao thức.

## 8. Chi tiết adapter
### 8.1 SSH (Paramiko)
- Thử kết nối TCP + auth username/password.
- Timeout riêng cho connect/auth.
- Thành công nếu mở session được.

### 8.2 TELNET (telnetlib / telnetlib3)
- Kết nối đến host:port.
- Gửi username/password theo prompt.
- Thành công khi nhận prompt shell (`>`, `#`, hoặc pattern cấu hình).

### 8.3 RESTCONF (requests)
- Dùng HTTPS với Basic Auth.
- Endpoint kiểm tra nhanh:
  - `/restconf/data`
  - hoặc endpoint health do thiết bị hỗ trợ.
- Mã HTTP 200/204 xem là thành công.

### 8.4 NETCONF (ncclient)
- Kết nối `manager.connect(...)`.
- Dùng cổng 830 mặc định.
- Thành công khi mở được session NETCONF.

## 9. Bổ sung: lấy `os` và `role` sau khi login thành công
Mục tiêu: không chỉ kiểm tra đăng nhập mà còn xác định loại thiết bị để phục vụ UI và xử lý backend tiếp theo.

### 9.1 Quy tắc nhận diện role theo yêu cầu
- `rou`: login xong chạy lệnh `show ip route` (hoặc `show route` tùy OS). Nếu có output route table hợp lệ thì đánh dấu role router.
- `sw2`: login xong chạy lệnh `show vlan`. Nếu có output VLAN table và không có route table thì đánh dấu switch layer 2.
- `sw3`: nếu đồng thời có dấu hiệu router (`show ip route`) và switch (`show vlan`) thì đánh dấu switch layer 3.

### 9.2 Chuỗi kiểm tra đề xuất (SSH/TELNET)
1. Chạy `show version` để lấy dấu hiệu OS.
2. Chạy `show ip route` (hoặc fallback `show route`).
3. Chạy `show vlan`.
4. Suy luận role:
   - route = true, vlan = false => `rou`
   - route = false, vlan = true => `sw2`
   - route = true, vlan = true => `sw3`
   - còn lại => `unknown`

### 9.3 Cách lấy os
- Ưu tiên parse output từ `show version`.
- Ví dụ map nhanh theo keyword:
  - có `IOS XE` / `Cisco IOS` => `IOS` hoặc `IOS-XE`
  - có `NX-OS` => `NX-OS`
  - có `Junos` => `Junos`
  - không nhận diện được => `unknown`

### 9.4 Với RESTCONF/NETCONF
- Không có CLI trực tiếp như SSH/TELNET, nên lấy role theo capability hoặc endpoint data model.
- Nếu chưa parse được model đủ sâu, giữ `role = unknown` và chỉ cập nhật `success = 1`.
- `os` có thể suy ra từ server header/capability nếu có, nếu không thì để `unknown`.

### 9.5 Bổ sung: lấy input cho ROUTING_DB và ACL_DB
Mục tiêu: sau khi login thành công, thu thập dữ liệu cấu hình định tuyến và ACL để ghi đúng bảng cha và bảng con.

#### 9.5.1 Input cho ROUTING_DB
- Bảng cha: `ROUTING_DB(route_type, host, description)`.
- Bảng con liên quan:
  - static/default: `static_routes`, `static_default_routes`
  - ospf: `ospf_processes`, `ospf_networks`
  - eigrp: `eigrp_processes`, `eigrp_networks`

Nguồn lấy input:
1. SSH/TELNET:
   - chạy `show running-config` (ưu tiên)
   - fallback theo lệnh hẹp: `show ip route`, `show ip protocols`, `show run | section router ospf`, `show run | section router eigrp`
2. NETCONF:
   - lấy config từ RPC get-config, parse các khối routing.
3. RESTCONF:
   - lấy data model routing qua endpoint tương ứng nếu thiết bị hỗ trợ.

Payload chuẩn đề xuất trong code (trước khi insert DB):
```json
{
  "host": "192.168.10.1",
  "routes": [
    {
      "route_type": "static",
      "description": "from running-config",
      "static": [
        {"network": "10.10.10.0", "subnet_mask": "255.255.255.0", "next_hop": "192.168.1.1", "ad": 1}
      ],
      "defaults": [
        {"next_hop_ip": "192.168.1.254"}
      ]
    },
    {
      "route_type": "ospf",
      "description": "process 1",
      "ospf": {
        "process_id": 1,
        "router_id": "1.1.1.1",
        "ad": 110,
        "default_info": 0,
        "auto_summary": 0,
        "networks": [
          {"network": "10.0.0.0", "wildcard": "0.0.0.255", "area": "0"}
        ]
      }
    }
  ]
}
```

Luồng ghi DB:
1. Insert 1 dòng vào `ROUTING_DB` theo từng process/nhóm route.
2. Lấy `routing_id` vừa insert.
3. Insert vào bảng con tương ứng với `routing_id`.
4. Dùng transaction cho toàn bộ host để tránh dữ liệu dở dang.

Validate tối thiểu:
- `host` phải tồn tại trong `devices`.
- `route_type` chỉ nhận: `static`, `default`, `ospf`, `eigrp`.
- IP/mask/wildcard đúng định dạng.

#### 9.5.2 Input cho ACL_DB
- Bảng cha: `ACL_DB(acl_name, acl_type, host, description)`.
- Bảng con theo loại ACL:
  - `standard_acl_rules`
  - `extended_acl_rules`
  - `dynamic_acl_rules`
  - `reflexive_acl_rules`
  - `mac_acl_rules`

Nguồn lấy input:
1. SSH/TELNET:
   - chạy `show running-config | section access-list`
   - hoặc parse block `ip access-list standard/extended ...`
2. NETCONF/RESTCONF:
   - parse ACL từ model nếu thiết bị expose đầy đủ.

Payload chuẩn đề xuất:
```json
{
  "host": "192.168.10.1",
  "acls": [
    {
      "acl_name": "SACL_IN",
      "acl_type": "standard",
      "description": "from running-config",
      "rules": [
        {"sequence": 10, "action": "permit", "source": "10.0.0.0", "wildcard": "0.0.0.255"},
        {"sequence": 20, "action": "deny", "source": "any", "wildcard": null}
      ]
    }
  ]
}
```

Luồng ghi DB:
1. Insert ACL vào `ACL_DB`.
2. Lấy `Acl_id`.
3. Tùy `acl_type` insert rule vào bảng con tương ứng.
4. Ghi theo transaction cho từng ACL hoặc từng host.

Validate tối thiểu:
- `acl_type` chỉ nhận: `standard`, `extended`, `dynamic`, `reflexive`, `mac`.
- `action` chỉ nhận: `permit`, `deny`.
- Với extended/dynamic/reflexive: cần `protocol`, `source`, `destination`.

#### 9.5.3 File code cần bổ sung để lấy input ROUTING/ACL
- `script/login/parser/routing_parser.py`
  - parse raw output sang payload routing chuẩn.
- `script/login/parser/acl_parser.py`
  - parse raw output sang payload acl chuẩn.
- `script/login/services/routing_service.py`
  - validate + insert `ROUTING_DB` và bảng con.
- `script/login/services/acl_service.py`
  - validate + insert `ACL_DB` và bảng con.
- `script/login/db_client.py`
  - thêm hàm insert cha/con và helper transaction.

## 10. Kế hoạch triển khai
### Giai đoạn 1: Nền tảng
- Tạo `db_client.py` (connect, query, update).
- Tạo `models.py` cho object Device.
- Tạo `config.py` cho timeout/retry.

### Giai đoạn 2: Giao thức
- Viết 4 adapter tách biệt.
- Thống nhất output adapter: `(ok: bool, message: str)`.

### Giai đoạn 3: Điều phối
- Viết `login_new.py` gọi adapter theo method.
- Cập nhật `success` vào DB.
- In tổng kết cuối cùng (total/success/fail).

### Giai đoạn 4: Tích hợp app
- App gọi script bằng `QProcess`.
- Sau khi script kết thúc, reload danh sách thiết bị.

## 11. Chạy trên Windows và Linux

## 11.1 Yêu cầu chung
- Python 3.10+ (khuyến nghị 3.11)
- Có thể truy cập mạng tới thiết bị đích.

## 11.2 requirements.txt
```text
paramiko>=3.4.0
requests>=2.31.0
ncclient>=0.6.15
tenacity>=8.2.3
```

## 11.3 Windows
```powershell
# Tại thư mục script/login
python -m venv .venv
.\.venv\Scripts\activate
pip install -r requirements.txt
python login_new.py --db "..\..\device_network.db"
```

## 11.4 Linux
```bash
# Tại thư mục script/login
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python3 login_new.py --db ../../device_network.db
```

## 11.5 Chế độ chạy batch định kỳ (tùy chọn)
- Windows: Task Scheduler chạy mỗi N phút.
- Linux: cron/systemd timer chạy mỗi N phút.

## 12. Nếu mở thêm bảng dữ liệu mới thì nên thay code nào

### 12.1 Các file cần sửa chắc chắn
- `script/login/db_client.py`
  - Thêm hàm query/insert/update cho bảng mới.
  - Quản lý transaction khi ghi nhiều bảng liên quan.
- `script/login/models.py`
  - Bổ sung model/DTO cho dữ liệu mới.
- `script/login/login_new.py`
  - Thêm bước gọi service ghi dữ liệu mới sau khi login thành công.
- `script/login/config.py`
  - Thêm cờ bật/tắt thu thập dữ liệu mới, timeout riêng nếu cần.

### 12.2 Các file có thể cần sửa thêm
- `script/login/protocols/*.py`
  - Nếu dữ liệu mới cần lấy bằng lệnh/endpoint mới.
- `src/database/DatabaseManager.h` và `src/database/DatabaseManager.cpp`
  - Nếu muốn app C++ đọc/ghi bảng mới qua QML bridge.
- Repository mới trong `src/database/`
  - Ví dụ tạo `NewFeatureRepository.h/.cpp` theo pattern hiện có.
- `data.sql`
  - Thêm `CREATE TABLE` mới và `FOREIGN KEY` phù hợp.

### 12.3 Nguyên tắc mở rộng an toàn
1. Không sửa logic login cũ nếu không cần.
2. Thêm module mới theo hướng độc lập (service/repository mới).
3. Mọi ghi nhiều bảng dùng transaction.
4. Có fallback khi không lấy được dữ liệu mới: vẫn giữ kết quả login và cập nhật `success`.

## 13. Quy ước log và mã lỗi
- Mỗi host ghi 1 dòng log gồm: `timestamp`, `host`, `method`, `result`, `reason`.
- Nhóm lỗi thất bại:
  - timeout
  - authentication failed
  - connection refused
  - ssl/tls error
  - protocol not supported

## 14. Tiêu chí hoàn thành
- Login được theo đúng 4 method.
- Cập nhật `success` đúng: `1` hoặc `-1`.
- Cập nhật `os` và `role` khi thu thập được thông tin.
- Không làm thay đổi schema SQL hiện tại.
- Chạy ổn định trên Windows và Linux.
- Có log đủ để debug theo host.
- không phá vỡ cấu trúc code hiện tại.
