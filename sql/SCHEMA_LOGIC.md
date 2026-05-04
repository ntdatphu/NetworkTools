# Schema Logic — `success` & `action`

> Nguồn sự thật lấy từ `src/database/routing/OspfRoutingRepository.cpp`,
> `EigrpRoutingRepository.cpp`, `RoutingStaticRepository.cpp`.

---

## 1. Cột `success` — trạng thái đồng bộ

| Giá trị | Ý nghĩa | Ai ghi |
|---------|---------|--------|
| `0`  | **Pending write** — hàng vừa được tạo/sửa bởi C++, đang chờ Python push lên thiết bị | C++ |
| `1`  | **Done** — Python đã push thành công | Python |
| `-1` | **Pending delete** — C++ đánh dấu cần xóa; Python gửi `no ...` lên thiết bị rồi DELETE khỏi DB | C++ |
| `3`  | **Skip** — dùng cho `devices` (host placeholder) và `ospf_processes` mới tạo chưa đầy đủ network | C++ |

### Vòng đời hàng dữ liệu

```
C++ INSERT hàng mới   →  success = 0
        │
        ▼
Python đọc success = 0  →  push CLI lên thiết bị
        ├─ thành công  →  UPDATE success = 1
        └─ thất bại    →  giữ success = 0, retry lần sau

C++ muốn xóa/sửa hàng cần "no"  →  UPDATE success = -1
        │
        ▼
Python đọc success = -1  →  gửi "no <lệnh>" lên thiết bị  →  DELETE khỏi DB
```

---

## 2. Cột `action` — INTEGER bitmask cho các tùy chọn có thể ghi đè

### Nguyên tắc quan trọng

`action` **chỉ tồn tại** trên các bảng process (`ospf_processes`, `eigrp_processes`, `ACL_DB`) và là **INTEGER bitmask**, không phải TEXT.

**Tại sao chia hai loại trường?**

| Loại trường | Ví dụ | Khi thay đổi | Cơ chế |
|-------------|-------|-------------|--------|
| **Cần `no` trước** | process_id, router_id, ad, network/wildcard/area | Phải xóa cấu hình cũ trước | `success = -1` → insert mới `success = 0` |
| **Có thể ghi đè** | default_info, auto_summary (OSPF), passive_default (EIGRP), description (ACL) | Chỉ cần gửi lại lệnh mới, không cần `no` | `action` bitmask |

### Bit mapping

#### `ospf_processes.action` — default `3` (binary `11`)

| Bit | Giá trị | Trường | Lệnh CLI |
|-----|---------|--------|----------|
| 1   | 2       | `default_info` | `default-information originate` |
| 0   | 1       | `auto_summary` | `auto-summary` / `no auto-summary` |

```
action = 3  (11) → cả default_info và auto_summary đều cần push  (mặc định khi tạo mới)
action = 2  (10) → chỉ push default_info
action = 1  (01) → chỉ push auto_summary
action = 0  (00) → không có toggle nào thay đổi
```

> **Lưu ý:** Khi `process_id`, `router_id`, hoặc `ad` thay đổi → toàn bộ process bị mark `success = -1`,
> insert lại với `action = 3`.

> **Lưu ý:** Khi thêm/xóa network của OSPF → network đó được insert `success = 0` hoặc mark `success = -1`.
> Không cần xóa cả process — đây là thay đổi độc lập tại bảng `ospf_networks`.

#### `eigrp_processes.action` — default `3` (binary `11`)

| Bit | Giá trị | Trường | Lệnh CLI |
|-----|---------|--------|----------|
| 1   | 2       | `auto_summary` | `auto-summary` / `no auto-summary` |
| 0   | 1       | `passive_default` | `passive-interface default` |

```
action = 3  (11) → push cả auto_summary và passive_default  (mặc định khi tạo mới)
action = 2  (10) → chỉ push auto_summary
action = 1  (01) → chỉ push passive_default
action = 0  (00) → không có toggle nào thay đổi
```

> **Lưu ý:** Khi `as_number`, `router_id`, hoặc `metric_weights` thay đổi → toàn bộ process bị
> mark `success = -1`, insert lại với `action = 3`.
> Network EIGRP thay đổi tương tự OSPF — độc lập tại `eigrp_networks`.

#### `ACL_DB.action_Cfg` — default `1` (binary `1`)

| Bit | Giá trị | Trường | Lệnh CLI |
|-----|---------|--------|----------|
| 0   | 1       | `description` | `remark <text>` |

> `acl_name` hoặc `acl_type` thay đổi → ACL cũ bị mark `success = -1`, insert ACL mới `success = 0`.
> Toàn bộ rules thuộc ACL cũ cũng bị mark `-1` theo (xử lý ở tầng service).

> **Lưu ý:** `action_Cfg` chỉ có trên `ACL_DB` (bảng cha). Cột `action` trong các bảng rule con
> (`standard_acl_rules`, `extended_acl_rules`, ...) là `TEXT` permit/deny, **không phải** bitmask.

### Cách Python đọc `action`

```python
def has_bit(action: int, bit: int) -> bool:
    """Kiểm tra bit tại vị trí `bit` trong action INTEGER."""
    return bool(action & (1 << bit))

# Ví dụ — ospf_processes
# action = 2  (binary 10)
# bit 0 (auto_summary)  → 2 & 1 = 0 → không push
# bit 1 (default_info)  → 2 & 2 = 2 → push
```

---

## 3. Bảng nào KHÔNG có `action`

Các bảng sau chỉ dùng `success`, không có `action`:

| Bảng | Cơ chế khi sửa |
|------|----------------|
| `static_routes` | Bất kỳ thay đổi nào → mark `-1`, insert mới |
| `static_default_routes` | Tương tự |
| `ospf_networks` | Thêm → insert `0`; xóa → mark `-1` |
| `eigrp_networks` | Tương tự |
| `interface_name` | Mark `-1`, insert mới |
| `dhcp_pool`, `excluded_address` | Mark `-1`, insert mới |
| `*_acl_rules` | Mark `-1`, insert mới (cột `action` trong bảng này là permit/deny, không phải bitmask) |
| `NAT_*` | Mark `-1`, insert mới |

---

## 4. Liên hệ với backend hiện tại

| File | Luồng | Ghi chú |
|------|-------|---------|
| `OspfRoutingRepository.cpp` | **C++ → DB** | Tính `action` bitmask, phân biệt process changed vs options changed |
| `EigrpRoutingRepository.cpp` | **C++ → DB** | Logic tương tự OSPF |
| `RoutingStaticRepository.cpp` | **C++ → DB** | Không dùng `action`; dùng `edited` flag + `success=-1` |
| `services/routing_service.py` | **thiết bị → DB** | Parse config từ thiết bị, `clear_routing_for_host` + insert lại, `success` DEFAULT 0 |
| `services/acl_service.py` | **thiết bị → DB** | Tương tự, `clear_acl_for_host` + insert lại |
| `login_new.py` | **thiết bị → DB** | `update_login_status` set `success=1` (ok) hoặc `-1` (fail) cho `devices` |
