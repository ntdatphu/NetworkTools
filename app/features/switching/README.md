# Switching

Trạng thái: **implemented** cho desired-state và View & Push Layer 2 Cisco IOS
qua SSH/Telnet; các transport/platform khác còn **partial**. Đối chiếu:
**2026-08-19**.

Workspace quản lý switch được bố trí theo trách nhiệm nhỏ:

- `vlan_repository.py`, `interface_repository.py`, `l3_repository.py` và
  `monitoring_repository.py`: CRUD/truy vấn desired state.
- `desired_state.py`: đọc và chuẩn hoá dữ liệu Layer 2 cho từng module.
- `commands.py`: dựng lệnh Cisco IOS cho VLAN, switch port/EtherChannel, STP,
  VTP và L2 Security.
- `worker.py`: gửi tập lệnh qua phiên SSH/Telnet đang mở của app.
- `push_state_repository.py`: lưu SHA-256 của cấu hình đã push thành công,
  không lưu payload hoặc bí mật.
- `view_push.py`: điều phối Preview/Push và chỉ đánh dấu module đã đồng bộ sau
  khi thiết bị chấp nhận lệnh.
- `vtp_group.py`: lưu một VTP domain cho 2–5 switch theo từng transaction độc
  lập, cho phép retry/upsert và trả kết quả partial khi một member lỗi.
- `sync.py`: parse output Cisco IOS và transaction pull-sync VLAN,
  switchport/trunk, EtherChannel, VTP status; bảo toàn module local pending.

QML dùng `ViewPushButton` chung trên trang VLAN, Switch Ports và Port Security.
Trang VTP Group dùng `MultiHostViewPushDialog`: Save ghi desired state ở trạng
thái `pending_apply`, sau đó Preview/Push song song tối đa 5 switch và chỉ push
những member đã lưu thành công.
Một lần View & Push kiểm tra toàn bộ Layer 2 để không bỏ sót STP/VTP hoặc policy
liên quan đến port. SVI, routed port và IP routing vẫn thuộc Layer 3, không được
đưa vào worker này. QoS và storm-control cũng không thuộc tích hợp này.

Schema nằm ở `infrastructure/database/schemas/device_network/06_l2_switching.sql`
và `09_vtp.sql`. Bảng `t06_switch_push_state` là phần mở rộng tương thích dữ
liệu cũ; `ensure_switch_schema()` chỉ tạo bổ sung, không dựng lại database.

Hỗ trợ push và pull-sync nêu trên: Cisco IOS qua SSH/Telnet. Các giới hạn chưa thể tích hợp
an toàn được ghi tại [INTEGRATION_LIMITATIONS.md](INTEGRATION_LIMITATIONS.md).

Kiểm thử:

```bash
.venv/bin/python -m unittest tests.test_switching_workspace \
  tests.test_switching_view_push tests.unit.test_switch_sync \
  tests.test_routing_group_fhrp
```
