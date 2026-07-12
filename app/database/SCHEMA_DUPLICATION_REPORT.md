# Báo cáo kiểm tra và hợp nhất bảng `database/schema`

## Kết luận

Hai cặp bảng routing per-interface là nguồn dữ liệu trùng chức năng thực sự. Schema mới chỉ giữ các bảng có FK `iface_id`:

| Chức năng | Bảng TEXT cũ | Bảng chính sau hợp nhất | Mức trùng | Kết quả |
|---|---|---|---|---|
| OSPF interface | `t04_ospf_interface_settings` | `t04_router_iface_ospf` | Cao | Đã hợp nhất |
| EIGRP interface | `t04_eigrp_interface_settings` | `t04_router_iface_eigrp` | Cao | Đã hợp nhất |
| NAT interface role | `t05_nat_interfaces` | `t05_router_iface_nat` | Gần trùng | Chưa hợp nhất: tầng ứng dụng vẫn là stub |
| Interface QoS | `t02_router_iface_qos` | `t06_iface_qos` | Trung bình | Giữ riêng: L3 và L2 có phạm vi khác nhau |
| Static route | `t04_static_routes` | `t07_vrf_static_routes` | Thấp | Giữ riêng: global routing và VRF |

`t04_router_iface_ospf` được bổ sung `bfd`; không mất các cột riêng `priority` và `auth_key`. `t04_router_iface_eigrp` đã có toàn bộ trường của bảng TEXT cũ.

## Vị trí ứng dụng sử dụng

| Bảng | File/hàm chính | Thao tác | Cột/ánh xạ |
|---|---|---|---|
| `t04_router_iface_ospf` | `backend/route/ospf/process_store.py` | Save/archive | UI `interface_name` → `iface_id`; area, cost, timer, mtu, bfd, auth |
| `t04_router_iface_ospf` | `backend/route/ospf/load.py`, `process_compare.py` | Load/compare | JOIN `t02_interface_name` để trả `interface_name` cho UI |
| `t04_router_iface_ospf` | `network_code/routing/main.py`, `ospf_api.py` | Build task/push/update status | JOIN tên interface, cập nhật theo `id` |
| `t04_router_iface_eigrp` | `backend/route/eigrp/child_writers.py`, `child_sync.py` | Save/update/sync | UI `interface_name` → `iface_id`; toàn bộ metric/timer/BFD |
| `t04_router_iface_eigrp` | `backend/route/eigrp/load.py`, `process_store.py` | Load/compare | JOIN tên interface theo `iface_id` |
| `t04_router_iface_eigrp` | `network_code/routing/main.py` | Build task | JOIN tên interface |
| `t02_interface_name` | `backend/route/interface_refs.py` | Resolve FK | Ghép bắt buộc theo `(host, interface_name)` |

UI không phải đổi API: `OspfProcessCard.qml` và `EigrpProcessCard.qml` vẫn gửi/nhận `interface_name`.

## Bảng chỉ có trong schema hoặc chưa có luồng thật

Kết quả tìm kiếm `.py`/`.qml` cho thấy các nhóm sau chưa có truy vấn dùng tên bảng chuẩn `tNN_*` hoặc mới chỉ có slot stub:

- Mở rộng interface: `t02_router_iface_l3`, `t02_router_iface_subif`, `t02_router_iface_tunnel`, `t02_router_iface_wan`, `t02_router_iface_qos`.
- DHCP schema chuẩn: `t03_dhcp_pool`, `t03_excluded_address`, `t03_router_iface_helper` (backend DHCP hiện còn dùng tên legacy không tiền tố).
- ACL/NAT: toàn bộ `t05_*`; `core/database_stubs.py` chưa có save/load thật.
- Switching: toàn bộ `t06_*`.
- VRF: toàn bộ `t07_*`.

Không xóa hoặc hợp nhất các nhóm này vì chưa đủ code input/save/load để chứng minh nghiệp vụ và migration an toàn.

## Quyết định khóa và schema cuối

Một interface vật lý chỉ có một cấu hình cho một routing process, vì vậy giữ:

```sql
UNIQUE(iface_id, ospf_id)
UNIQUE(iface_id, eigrp_id)
```

Tên interface chuẩn trong `t02_interface_name` là `interface_name`, với `UNIQUE(host, interface_name)`. Điều này ngăn ánh xạ nhầm hai thiết bị có cùng tên cổng.

## Migration dữ liệu cũ

Migration rời rạc đã được loại bỏ. Repository không có migration runner, version table hoặc `PRAGMA user_version`; builder luôn tạo database mới và `schema/04_routing.sql` đã chứa schema đích. Nếu cần nâng cấp dữ liệu người dùng đã phát hành trong tương lai, phải xây dựng migration system có versioning và kiểm thử riêng thay vì chạy lại file SQL cũ thủ công.

## Rủi ro và phần chưa tự động xử lý

- Interface trong form routing phải tồn tại ở `t02_interface_name` của đúng host; save trả lỗi rõ ràng nếu không tìm thấy.
- Dữ liệu cũ có tên interface trùng trong cùng host sẽ không tạo được unique index và migration sẽ rollback.
- Nếu bảng đích đã có cùng `(iface_id, process_id)`, migration dừng thay vì bỏ row âm thầm.
- `priority` và `auth_key` không tồn tại trong bảng OSPF cũ nên row migrate dùng lần lượt `1` và `NULL`.
- Các bảng backup không được xóa tự động.
- NAT, DHCP, ACL, switching và VRF chưa được hợp nhất vì code thật còn thiếu hoặc dùng tên legacy; cần xử lý riêng sau khi repository/service tương ứng hoàn thiện.
- `UI/main*.sql`, `network_code/sql/` và `database/main_numbered_tables new.sql` là snapshot legacy, không được builder/runtime đọc và không phải schema chính thức.

## Kế hoạch kiểm thử

1. Build database mới và chạy `integrity_check`, `foreign_key_check`.
2. Save/load/update/delete OSPF và EIGRP interface settings.
3. Xóa interface và xác nhận cascade hai bảng routing.
4. Xóa routing process và xác nhận cascade.
5. Xác nhận schema mới không tạo hai bảng TEXT cũ.
6. Chạy migration trên bản sao DB legacy, đối chiếu số row nguồn/đích và chỉ sau đó mới cân nhắc xóa bảng backup.
