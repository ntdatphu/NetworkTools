# Switching

Trạng thái: **implemented** cho desired-state và View & Push Layer 2 Cisco IOS
qua SSH/Telnet; các transport/platform khác còn **partial**. Đối chiếu:
**2026-08-19**.

Workspace quản lý switch được bố trí theo trách nhiệm nhỏ:

- `vlan_repository.py`, `interface_repository.py`, `etherchannel_repository.py`,
  `stp_repository.py`, `security_repository.py`, `l3_repository.py` và
  `monitoring_repository.py`: CRUD/truy vấn desired state.
- `desired_state.py`: đọc và chuẩn hoá dữ liệu Layer 2 cho từng module.
- `commands.py`: dựng lệnh Cisco IOS cho VLAN, switch port/EtherChannel, STP,
  VTP và L2 Security.
- `worker.py`: gửi tập lệnh qua phiên SSH/Telnet đang mở của app.
- `success_repository.py`: cập nhật `success` đúng row nghiệp vụ sau khi thiết
  bị chấp nhận task; không dùng hash hoặc bảng trạng thái song song.
- `view_push.py`: điều phối Preview/Push theo đúng tab và chỉ đánh dấu task đã
  đồng bộ sau khi thiết bị chấp nhận lệnh.
- `vtp_group.py`: lưu một VTP domain cho 2–5 switch theo từng transaction độc
  lập, cho phép retry/upsert và trả kết quả partial khi một member lỗi.
- `sync.py`: parse output Cisco IOS và transaction pull-sync VLAN,
  switchport/trunk, EtherChannel, VTP status; bảo toàn module local pending.

QML dùng `ViewPushButton` chung trên trang VLAN, Switch Ports, EtherChannel,
STP, L2 Security và Port Security. Trang EtherChannel tạo/cập nhật trực tiếp
bảng `t06_etherchannel` cũ. Trang STP quản lý mode toàn cục và root policy theo
VLAN. Trang L2 Security quản lý DHCP Snooping, DAI, trusted uplink và static
MAC; các bảng desired state cũ được giữ nguyên và được bổ sung cột `success`.
Trang VTP Group dùng `MultiHostViewPushDialog`: Save ghi desired state ở trạng
thái `pending_apply`, sau đó Preview/Push song song tối đa 5 switch và chỉ push
những member đã lưu thành công.
View & Push của mỗi tab chỉ thu thập row thay đổi thuộc tab đó. Chế độ `all` chỉ
dùng cho thao tác tổng hợp có chủ ý. SVI, routed port và IP routing vẫn thuộc
Layer 3, không được đưa vào worker này. QoS và storm-control cũng không thuộc
tích hợp này.

Schema nằm ở `infrastructure/database/schemas/device_network/06_l2_switching.sql`
và `09_vtp.sql`. `ensure_switch_schema()` chỉ `ALTER TABLE ... ADD COLUMN
success` khi cần, không dựng lại database. Bảng hash của project cũ (nếu có)
không còn được đọc hoặc ghi.

Hỗ trợ push và pull-sync nêu trên: Cisco IOS qua SSH/Telnet. Các giới hạn chưa thể tích hợp
an toàn được ghi tại [INTEGRATION_LIMITATIONS.md](INTEGRATION_LIMITATIONS.md).

Kiểm thử:

```bash
.venv/bin/python -m unittest tests.test_switching_workspace \
  tests.test_switching_view_push tests.unit.test_switch_sync \
  tests.test_routing_group_fhrp
```
