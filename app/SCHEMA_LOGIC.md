# SCHEMA_LOGIC — Quy ước đồng bộ DB, trạng thái push và cờ `dev`

> Tài liệu này mô tả nguyên lý xử lý dữ liệu giữa UI/C++ repository, DB SQLite và backend Python worker.
> Khi thay đổi schema SQL, repository hoặc worker, cần cập nhật file này cùng lúc để tránh lệch logic giữa DB và mã nguồn.

---

## 1. Mục đích tài liệu

File này dùng để thống nhất các quy ước sau:

- Ý nghĩa cột `success` trong các bảng cấu hình.
- Ý nghĩa và phạm vi sử dụng cột `dev` trong bảng `t01_devices`.
- Cách dùng `action` và `action_Cfg` cho các bảng có hỗ trợ cập nhật một phần.
- Nguyên tắc xử lý thêm, sửa, xóa cấu hình trước khi worker push lên thiết bị mạng.
- Những điểm cần lưu ý khi backend đọc/ghi các field dạng bitmask.

---

## 2. Cột `success` — trạng thái đồng bộ cấu hình

`success` là cột trạng thái dùng để xác định một row cấu hình đang ở giai đoạn nào trong luồng đồng bộ.

| Giá trị | Tên trạng thái | Ý nghĩa | Thành phần ghi chính |
| ------: | -------------- | ------- | -------------------- |
| `0` | Pending write | Row vừa được tạo hoặc sửa, đang chờ push lên thiết bị. | UI/C++ repository/service import |
| `1` | Done | Row đã được worker push thành công hoặc đã được xác nhận thành công trong luồng dev/test. | Python worker/dispatcher |
| `-1` | Pending delete | Row cần được gỡ khỏi thiết bị bằng lệnh `no ...`, sau đó xóa khỏi DB. | UI/C++ repository/service sửa-xóa |
| `3` | Skip | Trạng thái đặc biệt, chỉ dùng khi backend có quy ước riêng. | Backend |

### 2.1. Vòng đời dữ liệu chuẩn

```text
INSERT cấu hình mới       -> success = 0
Push CLI thành công       -> success = 1
Đánh dấu cần xóa/thay thế -> success = -1
Worker đọc success = -1   -> gửi lệnh no ... -> DELETE row khỏi DB
```

### 2.2. Nguyên tắc xử lý chung

- Với bảng chỉ có `success`, thao tác sửa thường nên xử lý theo kiểu **replace**:
  - row cũ được đánh dấu `success = -1`;
  - row mới được insert với `success = 0`.
- Với bảng có thêm `action` hoặc `action_Cfg`, một số field có thể được cập nhật trực tiếp mà không cần xóa toàn bộ đối tượng cấu hình cũ.
- Không tự suy diễn trạng thái ngoài các giá trị đã thống nhất nếu backend chưa hỗ trợ.

---

## 3. Cột `dev` trong bảng `t01_devices`

`dev` là cờ nghiệp vụ dùng để xác định thiết bị có chạy theo luồng dev/test hay không.

```sql
dev INTEGER DEFAULT 0
```

| Giá trị | Ý nghĩa |
| ------: | ------- |
| `0` | Thiết bị chạy theo luồng thật: worker đăng nhập vào thiết bị thật và push cấu hình thật. |
| `1` | Thiết bị chạy theo luồng dev/test: worker bỏ qua đăng nhập và push thật, nhưng vẫn trả kết quả thành công giả lập để tiếp tục luồng đồng bộ DB. |

### 3.1. Phạm vi sử dụng

`dev` hiện được dùng trong các worker push cấu hình Routing và DHCP.

Khi một host có `dev = 1`:

- worker xem host đó là **dev test host**;
- worker không mở kết nối SSH/Telnet/RESTCONF tới thiết bị;
- worker không gửi lệnh cấu hình thật;
- worker vẫn tạo report thành công giả lập;
- dispatcher vẫn cập nhật DB như một lần push thành công bình thường.

Sau khi report thành công giả lập được xử lý:

- row thêm/sửa có `success = 0` được chuyển thành `success = 1`;
- row xóa có `success = -1` được xóa khỏi DB theo cơ chế cũ.

Mục đích của `dev = 1` là kiểm thử luồng UI → DB → dispatcher → worker mà không cần thiết bị mạng thật và không làm thay đổi cấu hình thật trên router/switch.

### 3.2. Những điều `dev` không làm

`dev` chỉ là cờ điều khiển luồng push cấu hình. Nó không phải là tài khoản đăng nhập thiết bị.

Cụ thể:

- `dev` không phải username.
- `dev` không phải password.
- `dev` không phải tài khoản quản trị thiết bị.
- `dev = 1` không thay đổi các cột `username`, `password`, `method`, `portnumber`.
- `dev = 1` không tự tạo cấu hình mới; nó chỉ thay đổi cách worker xử lý khi đã có task pending.
- Các chức năng chỉ đọc danh sách thiết bị, mở form sửa thiết bị, hoặc connect/login thủ công vẫn dùng thông tin thiết bị bình thường.

### 3.3. Nguyên lý hoạt động

UI hoặc backend bật cờ dev bằng câu lệnh:

```sql
UPDATE t01_devices
SET dev = 1
WHERE host = ?;
```

Worker Routing/DHCP kiểm tra host dev trước khi build inventory thật:

```sql
SELECT host
FROM t01_devices
WHERE COALESCE(dev, 0) = 1
  AND host IN (...);
```

Sau đó worker xử lý theo nguyên tắc:

1. Tách các host có `dev = 1` khỏi danh sách inventory thật.
2. Với host `dev = 1`, tạo report thành công giả lập.
3. Với host `dev = 0`, tiếp tục luồng thật: build inventory, đăng nhập thiết bị và push cấu hình.
4. Dispatcher cập nhật các row pending dựa trên report trả về.

Việc đổi tên tham số nghiệp vụ từ `admin` sang `dev` chỉ là đổi tên cờ điều khiển. Nguyên lý xử lý cũ không thay đổi. Không dùng lại tên `admin` để tránh nhầm với username hoặc tài khoản quản trị thiết bị mạng.

Ví dụ truy vấn danh sách host dev:

```sql
SELECT host, device_name, username, password, dev
FROM t01_devices
WHERE COALESCE(dev, 0) = 1;
```

### 3.4. Trạng thái triển khai và kiểm thử

Đã triển khai và xác nhận trong phạm vi `app/`:

- `features/routing/worker.py` tách host dev trước khi lấy active session hoặc build inventory Nornir.
- `features/dhcp/worker.py` tách host dev trước khi lấy active session hoặc build inventory DHCP.
- Schema runtime chính thức `infrastructure/database/schemas/device_network/01_core_devices.sql` chỉ dùng cột `dev`; database runtime được tạo trong `data/` và không được Git theo dõi.
- Mỗi host dev nhận đúng một report `status = "success"` với thông báo không có login/push thật.
- Host thật trong cùng batch vẫn đi theo luồng session/inventory bình thường.
- Dispatcher Routing và DHCP xử lý report dev giống report thành công thật:
  - row pending add/update được chuyển từ `success = 0` sang `success = 1`;
  - row pending delete có `success = -1` được xóa khỏi DB.
- Các cột `username`, `password`, `method`, `portnumber` và chính cờ `dev` không bị thay đổi trong quá trình mô phỏng.

Luồng kiểm tra cờ `dev` dùng nguyên tắc **fail-closed**. Nếu worker không đọc được DB, bảng thiết bị hoặc cột `dev`:

1. không host nào được chuyển sang luồng push thật;
2. worker không yêu cầu active session và không build inventory thật;
3. worker ghi report `failed` cho từng target;
4. dispatcher giữ nguyên các row pending để có thể thử lại sau khi lỗi schema/DB được sửa.

Regression test nằm tại `tests/test_dev_mode_workers.py`, bao phủ:

- batch chỉ có host dev không yêu cầu session thật;
- batch trộn host dev/host thật chỉ yêu cầu session cho host thật;
- lỗi thiếu cột `dev` chặn toàn bộ push thật;
- Routing dispatcher cập nhật row `success = 0` và xóa row `success = -1` từ report dev;
- DHCP dispatcher cập nhật row `success = 0` và xóa row `success = -1` từ report dev.

Lệnh kiểm thử:

```powershell
app/.venv/Scripts/python.exe -B -m unittest app.tests.test_dev_mode_workers -v
```

Kết quả hiện tại: `5/5` test đạt; không test nào mở kết nối tới thiết bị mạng thật.

---

## 4. Cột `action` và `action_Cfg`

### 4.1. Nguyên tắc chung

- `action` là field cũ, hiện vẫn được giữ lại để tương thích với một số phần backend.
- `action_Cfg` là field điều khiển các option có thể cập nhật trực tiếp mà không cần xóa toàn bộ đối tượng cấu hình.
- Không phải mọi bảng đều có `action` hoặc `action_Cfg`.
- Hiện tồn tại hai kiểu lưu bitmask:
  - `INTEGER bitmask`;
  - chuỗi nhị phân dạng `TEXT`, ví dụ `'111'`, `'1111111'`.

### 4.2. Bảng có `action` hoặc `action_Cfg`

| Bảng | Cột | Kiểu dữ liệu |
| ---- | --- | ------------ |
| `eigrp_processes` | `action` | `INTEGER` |
| `eigrp_processes` | `action_Cfg` | `TEXT` nhị phân 7 bit |
| `dhcp_pool` | `action_Cfg` | `TEXT` nhị phân 3 bit |
| `ACL_DB` | `action_Cfg` | `INTEGER` |
| `NAT_ACL_DB` | `action_Cfg` | `INTEGER` |
| `NAT_DB` | `action_Cfg` | `INTEGER` |

### 4.3. Bảng hiện không có `action` hoặc `action_Cfg`

Các bảng sau hiện xử lý chủ yếu bằng `success`:

- `ospf_processes`
- `ospf_networks`
- `ospf_distance`
- `ospf_areas`
- `ospf_area_ranges`
- `ospf_redistribute`
- `ospf_passive_interfaces`
- `ospf_tuning`
- `ospf_interface_settings`
- `static_routes`
- `static_default_routes`
- `eigrp_networks`
- `eigrp_interface_settings`
- `eigrp_passive_interfaces`
- `eigrp_distribute_lists`
- `eigrp_offset_lists`
- `eigrp_redistribute`
- `eigrp_key_chains`
- `excluded_address`
- toàn bộ bảng rule con của ACL/NAT ACL
- toàn bộ bảng con của NAT, ngoại trừ `NAT_DB`

---

## 5. Logic theo từng nhóm schema

### 5.1. Static Route

Áp dụng cho:

- `static_default_routes`
- `static_routes`

Đặc điểm:

- Chỉ dùng `success`.
- Mọi thay đổi route nên xử lý theo kiểu replace:
  - row cũ: `success = -1`;
  - row mới: `success = 0`.

---

### 5.2. OSPF

Áp dụng cho:

- `ospf_processes`
- `ospf_networks`
- `ospf_distance`
- `ospf_areas`
- `ospf_area_ranges`
- `ospf_redistribute`
- `ospf_passive_interfaces`
- `ospf_tuning`
- `ospf_interface_settings`

Đặc điểm:

- OSPF hiện chỉ dùng `success`.
- OSPF hiện không có `action` và không có `action_Cfg` trong schema.

Nguyên tắc xử lý:

- Đổi `process_id`, `router_id`, `reference_bandwidth` hoặc các field process-level quan trọng:
  - nên mark row cũ `success = -1`;
  - insert row mới `success = 0`.
- Thêm/xóa network xử lý độc lập trong `ospf_networks`.
- Area, redistribute, passive-interface, tuning và interface settings nên được xem là các row cấu hình độc lập.
- Với các row cấu hình độc lập, cách sửa an toàn nhất là delete + insert thông qua cơ chế `success`.

Lưu ý schema hiện tại:

- `ospf_processes` đang dùng các field:
  - `reference_bandwidth`
  - `passive_default`
  - `default_originate`
  - `default_originate_always`
- Các field hoặc quy ước cũ như `default_info`, `auto_summary`, `action` của OSPF không còn khớp với schema hiện tại nếu DB đã thay đổi.

---

### 5.3. EIGRP

Áp dụng cho:

- `eigrp_processes`
- `eigrp_networks`
- `eigrp_interface_settings`
- `eigrp_passive_interfaces`
- `eigrp_distribute_lists`
- `eigrp_offset_lists`
- `eigrp_redistribute`
- `eigrp_key_chains`

#### 5.3.1. `eigrp_processes.action`

- Kiểu dữ liệu: `INTEGER`
- Giá trị mặc định hiện tại: `15`
- Vai trò: field tương thích ngược, chỉ nên dùng nếu backend hiện tại vẫn còn đọc field này.

#### 5.3.2. `eigrp_processes.action_Cfg`

- Kiểu dữ liệu: `TEXT`
- Format: chuỗi nhị phân 7 ký tự
- Giá trị mặc định: `'1111111'`

Schema có ràng buộc:

```sql
CHECK(length(action_Cfg) = 7 AND action_Cfg GLOB '[01][01][01][01][01][01][01]')
```

Ví dụ hợp lệ:

```text
'1111111'
'0010000'
'0000000'
```

Ý nghĩa nghiệp vụ:

- `action_Cfg` dùng cho các option process-level có thể ghi đè trực tiếp.
- Mapping bit chi tiết phải theo backend đang xử lý thực tế.
- Khi repository/service chưa thống nhất mapping, không nên suy diễn bit dựa trên tài liệu cũ.

Nguyên tắc xử lý:

- Đổi `as_number` hoặc các field backend xem là identity:
  - mark process cũ `success = -1`;
  - insert process mới `success = 0`.
- Đổi các option process-level có thể ghi đè:
  - giữ row hiện tại;
  - cập nhật field liên quan;
  - cập nhật `action_Cfg` tương ứng.
- Các bảng network, passive-interface, distribute-list, offset-list, redistribute và key-chain xử lý như row độc lập theo `success`.

---

### 5.4. DHCP

Áp dụng cho:

- `dhcp_pool`
- `excluded_address`

#### 5.4.1. `dhcp_pool.action_Cfg`

- Kiểu dữ liệu: `TEXT`
- Format: chuỗi nhị phân 3 ký tự
- Giá trị mặc định: `'111'`

Bit mapping hiện tại:

| Bit | Vị trí trong chuỗi | Trường DB | CLI tương ứng |
| --: | ------------------ | --------- | ------------- |
| `2` | Ký tự thứ 1 | `defaut` | `default-router <ip>` |
| `1` | Ký tự thứ 2 | `dns` | `dns-server <ip>` |
| `0` | Ký tự thứ 3 | `lease` | `lease <d> [h m s]` |

> Lưu ý: tên field `defaut` được giữ nguyên theo schema hiện tại. Không tự sửa thành `default` nếu code và DB vẫn đang dùng `defaut`.

Ví dụ:

```text
'111' -> push default-router, dns-server và lease
'110' -> push default-router và dns-server
'001' -> chỉ push lease
'000' -> không có option ghi đè nào thay đổi
```

Nguyên tắc xử lý:

- Đổi `pool`, `network`, `subnetmask`:
  - nên xử lý theo kiểu replace;
  - row cũ `success = -1`;
  - row mới `success = 0`.
- Đổi `defaut`, `dns`, `lease`:
  - có thể giữ row hiện tại;
  - cập nhật field liên quan;
  - cập nhật lại `action_Cfg`.
- `excluded_address` không có `action_Cfg`, chỉ dùng `success`.

---

### 5.5. ACL

Áp dụng cho:

- `ACL_DB`
- `standard_acl_rules`
- `extended_acl_rules`
- `dynamic_acl_rules`
- `reflexive_acl_rules`
- `mac_acl_rules`
- `router_iface_acl`

#### 5.5.1. `ACL_DB.action_Cfg`

- Kiểu dữ liệu: `INTEGER`
- Giá trị mặc định: `1`
- Bit `0`: `description`/`remark`

Nguyên tắc xử lý:

- Đổi `acl_name` hoặc `acl_type`:
  - mark ACL cũ `success = -1`;
  - insert ACL mới `success = 0`.
- Đổi `description`:
  - có thể giữ row hiện tại;
  - cập nhật `description`;
  - set bit tương ứng trong `action_Cfg`.
- Các bảng rule con chỉ dùng `success`.
- `router_iface_acl` chỉ dùng `success`.

---

### 5.6. Route Map và NAT ACL

Áp dụng cho:

- `route_map_db`
- `route_map_entries`
- `NAT_ACL_DB`
- `nat_standard_acl_rules`
- `nat_extended_acl_rules`

#### 5.6.1. `NAT_ACL_DB.action_Cfg`

- Kiểu dữ liệu: `INTEGER`
- Giá trị mặc định: `1`
- Bit `0`: `description`

Nguyên tắc xử lý:

- Đổi `acl_name` hoặc `acl_type`:
  - mark NAT ACL cũ `success = -1`;
  - insert NAT ACL mới `success = 0`.
- Đổi `description`:
  - có thể giữ row hiện tại;
  - cập nhật `description`;
  - set bit `0` trong `action_Cfg`.
- Các bảng rule con chỉ dùng `success`.

---

### 5.7. NAT

Áp dụng cho:

- `NAT_DB`
- `nat_interfaces`
- `router_iface_nat`
- `nat_pools`
- `nat_static_mappings`
- `nat_dynamic_rules`
- `nat_overload_interface_rules`
- `nat_exempt_rules`

#### 5.7.1. `NAT_DB.action_Cfg`

- Kiểu dữ liệu: `INTEGER`
- Giá trị mặc định: `1`
- Bit `0`: `description`

Nguyên tắc xử lý:

- Đổi `nat_name` hoặc `nat_type`:
  - mark NAT cũ `success = -1`;
  - insert NAT mới `success = 0`.
- Đổi `description`:
  - có thể giữ row hiện tại;
  - cập nhật `description`;
  - set bit tương ứng trong `action_Cfg`.
- Các bảng con của NAT chỉ dùng `success`.
- `router_iface_nat` chỉ dùng `success`.

---

### 5.8. L2 Switching

Áp dụng cho:

- `vlan_db`
- `interface_l2`
- `iface_access`
- `iface_trunk`
- `iface_stp`
- `iface_port_security`
- `iface_monitor`
- `iface_mac_table`
- `etherchannel`
- `stp_config`
- `security_l2`
- `dhcp_trust_ports`
- `svi_interface`

Đặc điểm:

- Phần lớn bảng L2 không dùng `success`.
- `svi_interface` có `success` để đánh dấu trạng thái cấu hình SVI.
- Nhiều bảng L2 có `FOREIGN KEY` tham chiếu đến `devices(host)` và `vlan_db(host, vlan_id)`.
- Thay đổi cấu hình L2 thường cập nhật row trực tiếp, không dùng `action_Cfg`.

---

## 6. Hàm xử lý bitmask tham khảo cho backend Python

### 6.1. Đọc `action_Cfg` dạng `TEXT` nhị phân

```python
def has_text_bit(action_cfg: str, bit_index_from_right: int) -> bool:
    """Trả về True nếu bit tại vị trí chỉ định đang bật.

    action_cfg: chuỗi nhị phân, ví dụ '111' hoặc '1111111'.
    bit_index_from_right: vị trí bit tính từ phải sang trái, bắt đầu từ 0.
    """
    if not action_cfg:
        return False

    pos = len(action_cfg) - 1 - bit_index_from_right
    if pos < 0 or pos >= len(action_cfg):
        return False

    return action_cfg[pos] == '1'
```

Ví dụ:

```python
has_text_bit('111', 2)  # True  -> default-router
has_text_bit('111', 1)  # True  -> dns-server
has_text_bit('111', 0)  # True  -> lease
```

### 6.2. Đọc `action` hoặc `action_Cfg` dạng `INTEGER` bitmask

```python
def has_int_bit(action: int, bit: int) -> bool:
    """Trả về True nếu bit trong integer bitmask đang bật."""
    return bool(action & (1 << bit))
```

Ví dụ:

```python
has_int_bit(1, 0)  # True
has_int_bit(2, 0)  # False
has_int_bit(2, 1)  # True
```

---

## 7. Liên hệ với feature implementation hiện tại

| File | Luồng xử lý | Ghi chú |
| ---- | ----------- | ------- |
| `OspfRoutingRepository.cpp` | C++ → DB | Logic ghi DB phải khớp với schema OSPF hiện tại. |
| `EigrpRoutingRepository.cpp` | C++ → DB | Cần thống nhất rõ backend dùng `action`, `action_Cfg`, hoặc cả hai. |
| `RoutingStaticRepository.cpp` | C++ → DB | Chủ yếu dùng `success`. |
| `services/routing_service.py` | Thiết bị → DB | Import cấu hình từ thiết bị về DB, thường insert row mới với `success = 0`. |
| `services/acl_service.py` | Thiết bị → DB | Import ACL từ thiết bị về DB, tương tự routing service. |
| NAT/DHCP service | Tùy implementation | Cần parse đúng kiểu `INTEGER` hoặc `TEXT` của từng `action_Cfg`. |

---

## 8. Ghi chú bảo trì

Khi thay đổi `action_Cfg`, `success`, `dev` hoặc schema liên quan, cần cập nhật đồng thời:

1. File schema SQL.
2. C++ repository/service ghi DB.
3. Python worker/service đọc DB và push cấu hình.
4. Dispatcher xử lý report push.
5. Tài liệu `SCHEMA_LOGIC.md` này.

Các lưu ý quan trọng:

- Không dùng tài liệu cũ của OSPF/EIGRP nếu schema đã thay đổi nhưng tài liệu chưa được cập nhật.
- Không tự đổi tên field DB nếu code hiện tại vẫn phụ thuộc vào tên cũ.
- Với SQLite, `UNIQUE` trên cột nullable vẫn cho phép nhiều row có `NULL`; nếu cần chống trùng tuyệt đối, nên chuẩn hóa `NULL` ở tầng ứng dụng.
- Trước khi sửa logic push, cần kiểm tra cả luồng thật (`dev = 0`) và luồng dev/test (`dev = 1`).
