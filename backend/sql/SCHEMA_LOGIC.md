# Schema Logic — `success`, `action`, `action_Cfg`

> Tài liệu này mô tả logic đồng bộ theo schema SQL hiện tại trong thư mục `sql`.
> Khi schema thay đổi, file này phải được cập nhật cùng lúc để tránh lệch giữa DB và backend.

---

## 1. Cột `success` — trạng thái đồng bộ

| Giá trị | Ý nghĩa | Ai ghi |
|---------|---------|--------|
| `0`  | **Pending write** — hàng vừa được tạo/sửa, đang chờ push lên thiết bị | C++ / service import |
| `1`  | **Done** — đã push thành công | Python / worker đồng bộ |
| `-1` | **Pending delete** — cần gửi `no ...` rồi xóa khỏi DB | C++ / service sửa-xóa |
| `3`  | **Skip** — trạng thái đặc biệt, chỉ dùng khi backend có quy ước riêng | Backend |

### Vòng đời dữ liệu chuẩn

```text
INSERT mới                -> success = 0
Push CLI thành công       -> success = 1
Đánh dấu cần xóa/sửa kiểu replace
                         -> success = -1
Worker đọc success = -1   -> gửi no ... -> DELETE khỏi DB
```

### Ý nghĩa thực tế

- Bảng chỉ có `success`, không có `action` / `action_Cfg`:
  mọi thay đổi thường xử lý theo kiểu mark `-1` rồi insert row mới `0`.
- Bảng có thêm `action` / `action_Cfg`:
  một số field có thể ghi đè trực tiếp mà không cần xóa cả đối tượng cũ.

---

## 2. Cột `action` và `action_Cfg`

### Nguyên tắc chung

- `action`: field cũ, hiện vẫn tồn tại để tương thích backend ở một số bảng.
- `action_Cfg`: field điều khiển các option có thể ghi đè trực tiếp.
- Không phải mọi bảng process đều có `action` / `action_Cfg`.
- Hiện tại có 2 kiểu lưu:
        - `INTEGER bitmask`
        - `TEXT` nhị phân (`'111'`, `'1111111'`)

### Bảng nào đang có `action` / `action_Cfg`

| Bảng | Cột | Kiểu |
|------|-----|------|
| `eigrp_processes` | `action` | INTEGER |
| `eigrp_processes` | `action_Cfg` | TEXT nhị phân 7 bit |
| `dhcp_pool` | `action_Cfg` | TEXT nhị phân 3 bit |
| `ACL_DB` | `action_Cfg` | INTEGER |
| `NAT_ACL_DB` | `action_Cfg` | INTEGER |
| `NAT_DB` | `action_Cfg` | INTEGER |

### Bảng hiện KHÔNG có `action` / `action_Cfg`

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
- toàn bộ bảng con của NAT ngoài `NAT_DB`

---

## 3. Logic theo nhóm schema

### 3.1 Static Route

Áp dụng cho:

- `static_default_routes`
- `static_routes`

Đặc điểm:

- Chỉ dùng `success`.
- Mọi thay đổi route thường xử lý kiểu replace:
        row cũ `success = -1`, row mới `success = 0`.

---

### 3.2 OSPF

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

Đặc điểm hiện tại:

- Toàn bộ OSPF hiện chỉ dùng `success`.
- Không có `action` và không có `action_Cfg` trong schema hiện tại.

Hệ quả xử lý:

- Đổi `process_id`, `router_id`, `reference_bandwidth` hoặc các field process-level khác:
  thường nên mark row cũ `success = -1`, insert row mới `success = 0`.
- Thêm/xóa network:
  thao tác độc lập ở `ospf_networks`.
- Area, redistribute, passive-interface, tuning, interface settings:
  mỗi row là một đơn vị cấu hình độc lập, sửa theo kiểu delete + insert là an toàn nhất.

Lưu ý schema hiện tại:

- `ospf_processes` đang dùng các field:
        `reference_bandwidth`, `passive_default`, `default_originate`, `default_originate_always`.
- Tài liệu cũ nhắc `default_info`, `auto_summary`, `action` của OSPF là không còn đúng với schema hiện tại.

---

### 3.3 EIGRP

Áp dụng cho:

- `eigrp_processes`
- `eigrp_networks`
- `eigrp_interface_settings`
- `eigrp_passive_interfaces`
- `eigrp_distribute_lists`
- `eigrp_offset_lists`
- `eigrp_redistribute`
- `eigrp_key_chains`

#### `eigrp_processes.action`

- Kiểu: `INTEGER`
- Default hiện tại: `15`
- Là field tương thích ngược đang được giữ lại.
- Chỉ nên dùng nếu backend hiện có còn đang đọc field này.

#### `eigrp_processes.action_Cfg`

- Kiểu: `TEXT`
- Format: chuỗi nhị phân 7 ký tự
- Default: `'1111111'`
- Schema có CHECK:

```sql
CHECK(length(action_Cfg) = 7 AND action_Cfg GLOB '[01][01][01][01][01][01][01]')
```

Ví dụ hợp lệ:

- `'1111111'`
- `'0010000'`
- `'0000000'`

Ý nghĩa nghiệp vụ:

- Dùng cho các option process-level có thể ghi đè mà không cần xóa cả process.
- Mapping bit chi tiết phải theo backend đang xử lý thực tế.
- Khi chưa thống nhất mapping ở repository/service, không nên suy diễn bit theo tài liệu cũ.

Logic sửa dữ liệu:

- Đổi `as_number` hoặc các field backend coi là identity:
  mark process cũ `success = -1`, insert process mới `success = 0`.
- Đổi các option process-level có thể ghi đè:
  giữ row, cập nhật field và cập nhật `action_Cfg`.
- Networks, passive-interface, distribute-list, offset-list, redistribute, key-chain:
  xử lý như các row độc lập theo `success`.

---

### 3.4 DHCP

Áp dụng cho:

- `dhcp_pool`
- `excluded_address`

#### `dhcp_pool.action_Cfg`

- Kiểu: `TEXT`
- Format: chuỗi nhị phân 3 ký tự
- Default: `'111'`

Bit mapping:

| Bit | Ký tự trong chuỗi | Trường | CLI |
|-----|-------------------|--------|-----|
| 2 | ký tự thứ 1 | `defaut` | `default-router <ip>` |
| 1 | ký tự thứ 2 | `dns` | `dns-server <ip>` |
| 0 | ký tự thứ 3 | `lease` | `lease <d> [h m s]` |

Ví dụ:

```text
'111' -> push cả default-router, dns-server, lease
'110' -> push default-router + dns-server
'001' -> chỉ push lease
'000' -> không có option ghi đè nào thay đổi
```

Logic sửa dữ liệu:

- Đổi `pool`, `network`, `subnetmask`:
  nên xử lý kiểu replace (`-1` rồi insert `0`).
- Đổi `defaut`, `dns`, `lease`:
  có thể giữ row, cập nhật field và set lại `action_Cfg`.
- `excluded_address` không có `action_Cfg`, chỉ dùng `success`.

---

### 3.5 ACL

Áp dụng cho:

- `ACL_DB`
- `standard_acl_rules`
- `extended_acl_rules`
- `dynamic_acl_rules`
- `reflexive_acl_rules`
- `mac_acl_rules`

#### `ACL_DB.action_Cfg`

- Kiểu: `INTEGER`
- Default: `1`
- Bit0 = `description` / `remark`

Logic sửa dữ liệu:

- Đổi `acl_name` hoặc `acl_type`:
  mark ACL cũ `success = -1`, insert ACL mới `success = 0`.
- Đổi `description`:
  có thể giữ row và set `action_Cfg`.
- Các bảng rule con không có `action_Cfg`.
- Cột `action` trong các bảng rule con là `TEXT` (`permit` / `deny`), không phải bitmask.

---

### 3.6 NAT ACL

Áp dụng cho:

- `NAT_ACL_DB`
- `nat_standard_acl_rules`
- `nat_extended_acl_rules`

#### `NAT_ACL_DB.action_Cfg`

- Kiểu: `INTEGER`
- Default: `1`
- Bit0 = `description`

Logic sửa dữ liệu:

- Đổi `acl_name` hoặc `acl_type`:
  mark ACL cũ `success = -1`, insert ACL mới `success = 0`.
- Đổi `description`:
  có thể giữ row và set bit0 trong `action_Cfg`.
- Rule con chỉ dùng `success`.

---

### 3.7 NAT

Áp dụng cho:

- `NAT_DB`
- `nat_interfaces`
- `nat_pools`
- `nat_static_mappings`
- `nat_dynamic_rules`
- `nat_overload_interface_rules`
- `nat_exempt_rules`

#### `NAT_DB.action_Cfg`

- Kiểu: `INTEGER`
- Default: `1`
- Bit0 = `description`

Logic sửa dữ liệu:

- Đổi `nat_name` hoặc `nat_type`:
  mark NAT cũ `success = -1`, insert NAT mới `success = 0`.
- Đổi `description`:
  có thể giữ row và set bit0 trong `action_Cfg`.
- Các bảng con của NAT chỉ dùng `success`.

---

## 4. Hàm xử lý tham khảo cho backend

### Đọc `action_Cfg` kiểu TEXT nhị phân

```python
def has_text_bit(action_cfg: str, bit_index_from_right: int) -> bool:
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
has_text_bit('111', 1)  # True  -> dns
has_text_bit('111', 0)  # True  -> lease
```

### Đọc `action` / `action_Cfg` kiểu INTEGER bitmask

```python
def has_int_bit(action: int, bit: int) -> bool:
                return bool(action & (1 << bit))
```

---

## 5. Liên hệ với backend hiện tại

| File | Luồng | Ghi chú |
|------|-------|---------|
| `OspfRoutingRepository.cpp` | C++ -> DB | Logic phải khớp với schema OSPF hiện tại, không dùng doc OSPF cũ |
| `EigrpRoutingRepository.cpp` | C++ -> DB | Cần thống nhất rõ việc dùng `action`, `action_Cfg`, hoặc cả hai |
| `RoutingStaticRepository.cpp` | C++ -> DB | Chủ yếu dùng `success` |
| `services/routing_service.py` | thiết bị -> DB | Import cấu hình về DB, thường insert row mới với `success = 0` |
| `services/acl_service.py` | thiết bị -> DB | Tương tự với ACL |
| NAT/DHCP service | tùy implementation | Cần parse đúng kiểu `INTEGER` hay `TEXT` của từng `action_Cfg` |

---

## 6. Ghi chú bảo trì

- Nếu đổi kiểu dữ liệu của `action_Cfg`, phải cập nhật cùng lúc:
        - schema SQL
        - repository/service đọc ghi DB
        - file này
- Không dùng tài liệu cũ của OSPF/EIGRP nếu schema đã đổi nhưng doc chưa cập nhật.
- Với SQLite, `UNIQUE` trên cột nullable vẫn cho phép nhiều row có `NULL`; nếu cần chống trùng logic tuyệt đối, nên cân nhắc chuẩn hóa giá trị `NULL` ở tầng ứng dụng.
