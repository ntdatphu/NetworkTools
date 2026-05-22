# SQL Schema Analysis

Tài liệu này phân tích schema SQLite hiện tại theo source trên nhánh `main`.

## Nguồn schema

Schema runtime hiện nằm trong Python app kernel:

```text
python app kenel/sql/main.sql
```

Khi build ứng dụng, thư mục này được copy sang output:

```text
python_app_kenel/sql/main.sql
```

Khi database `device_network.db` chưa tồn tại, `DatabaseConnection.cpp` gọi Python app kernel để tạo database từ file SQL này.

## Vai trò của schema

Schema phục vụ lưu trữ dữ liệu cấu hình mạng theo thiết bị, gồm:

- Thông tin thiết bị.
- Thông tin YANG/RESTCONF liên quan đến thiết bị.
- Interface.
- DHCP.
- Routing.
- ACL.
- NAT.
- Route map.
- Các trạng thái phục vụ quá trình cấu hình/đồng bộ.

## Nhóm bảng chính

### 1. Core devices

Nhóm bảng thiết bị là nền tảng cho các module khác.

Bảng chính:

```text
devices
yangcfg
```

Vai trò:

- `devices`: lưu thông tin thiết bị theo `host`.
- `yangcfg`: lưu thông tin đăng nhập/cấu hình liên quan YANG/RESTCONF theo thiết bị.

`host` là khóa tham chiếu quan trọng được nhiều bảng domain khác sử dụng.

### 2. Interface

Nhóm bảng interface lưu thông tin interface vật lý, Layer 3, subinterface, tunnel, WAN, QoS và helper.

Các nhóm đáng chú ý:

```text
interface_name
router_iface_l3
router_iface_subif
router_iface_tunnel
router_iface_wan
router_iface_qos
router_iface_helper
```

Đặc điểm:

- `interface_name` là bảng gốc cho interface.
- Các bảng mở rộng thường dùng `iface_id` làm khóa liên kết.
- Một số bảng có `action_Cfg` dạng chuỗi nhị phân để mô tả nhóm tùy chọn cần áp dụng.

### 3. DHCP

Các bảng chính:

```text
dhcp_pool
excluded_address
```

Vai trò:

- `dhcp_pool`: lưu pool DHCP theo host.
- `excluded_address`: lưu dải IP loại trừ.

Một số trường như `success` và `action_Cfg` hỗ trợ theo dõi trạng thái cấu hình.

### 4. Routing

Các nhóm chính:

```text
static_default_routes
static_routes
ospf_processes
ospf_networks
eigrp_processes
eigrp_networks
```

Vai trò:

- Static route/default route.
- OSPF process và network statements.
- EIGRP process và network statements.

Các bảng routing gắn với `host` hoặc process ID tương ứng.

### 5. ACL

Nhóm ACL phục vụ lưu rule theo nhiều loại ACL.

Các dạng có thể bao gồm:

- Standard ACL.
- Extended ACL.
- Dynamic ACL.
- Reflexive ACL.
- MAC ACL.

Tài liệu chi tiết từng bảng cần được cập nhật tiếp sau khi khóa schema cuối cùng.

### 6. NAT và route map

Nhóm NAT phục vụ cấu hình:

- Static NAT.
- Dynamic NAT.
- PAT.
- NAT interface.
- NAT ACL.
- Route map.

Cấu trúc source hiện có repository riêng cho NAT và route-map trong:

```text
frontend/src/database/nat/
```

## Các trường trạng thái phổ biến

### `success`

Nhiều bảng có trường:

```text
success INTEGER DEFAULT 0
```

Ý nghĩa khuyến nghị:

| Giá trị | Ý nghĩa đề xuất |
|---|---|
| `0` | Chưa áp dụng/chờ xử lý |
| `1` | Đã áp dụng/thành công |
| `-1` | Đánh dấu xóa/thay thế/thất bại tùy domain |

Cần thống nhất ý nghĩa `success` trong source và tài liệu trước khi viết báo cáo chính thức.

### `action_Cfg`

Một số bảng dùng `action_Cfg` để mô tả nhóm cấu hình cần áp dụng.

Ví dụ:

```text
action_Cfg TEXT DEFAULT '111'
```

Ý nghĩa cụ thể phụ thuộc từng bảng. Khi triển khai sinh cấu hình, cần viết tài liệu mapping rõ:

```text
bit position -> nhóm cấu hình -> câu lệnh CLI/API tương ứng
```

## Ràng buộc dữ liệu

Schema có sử dụng:

- `PRIMARY KEY`.
- `FOREIGN KEY`.
- `UNIQUE`.
- `CHECK`.
- `DEFAULT`.
- `ON DELETE CASCADE`.
- `ON UPDATE CASCADE`.

Điều này giúp giữ tính nhất quán khi xóa thiết bị hoặc xóa process/config cha.

## Điểm cần chú ý

1. `host` là khóa logic quan trọng nhất cho dữ liệu theo thiết bị.
2. Các bảng con nên có cascade phù hợp để tránh dữ liệu mồ côi.
3. Cần thống nhất ý nghĩa `success` giữa UI, repository và báo cáo.
4. Cần tránh để schema runtime và tài liệu phân tích bị lệch nhau.
5. Nếu SQL được tách thành nhiều file trong `sql/`, cần đảm bảo `main.sql` luôn là bản hợp nhất đúng cho runtime.

## Khuyến nghị cho báo cáo NCKH

Trong báo cáo, schema nên được trình bày theo nhóm chức năng thay vì liệt kê toàn bộ bảng:

| Nhóm | Vai trò nghiên cứu |
|---|---|
| Devices | Quản lý tập trung thiết bị |
| Interface | Quản lý cấu hình cổng mạng |
| DHCP | Tự động hóa cấu hình dịch vụ IP |
| Routing | Tự động hóa định tuyến |
| ACL/NAT | Cấu hình chính sách mạng |
| Logs/Status | Nền tảng giám sát/cảnh báo |

## Việc cần cập nhật tiếp

- Bổ sung ERD hoặc sơ đồ quan hệ bảng.
- Mô tả chi tiết từng bảng sau khi schema ổn định.
- Chuẩn hóa mapping `success` và `action_Cfg`.
- Bổ sung ví dụ dữ liệu mẫu phục vụ kiểm thử.
