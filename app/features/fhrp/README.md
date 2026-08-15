# FHRP

Trạng thái: **implemented** cho Cisco IOS SSH/Telnet. Đối chiếu:
**2026-08-16**.

Feature FHRP cấu hình một Default Gateway ảo trên nhiều router/L3 switch cùng
lúc. QML entry là `UI/qml/features/fhrp/FhrpView.qml`, chia thành ba tab con
HSRP, VRRP và GLBP. Mỗi tab lazy-load một `FhrpProtocolPage.qml` và giữ draft,
host selection, group list riêng. Contract QML nằm trong `core/fhrp_slots.py`;
dữ liệu dùng các bảng `t08_fhrp_*`.

Luồng chuẩn:

1. Chọn ít nhất hai host đang connected.
2. Nhập protocol, group/VRID và IP Default Gateway.
3. `FhrpService` lọc interface theo subnet IPv4 đang cấu hình trên từng host;
   gateway không được trùng IP interface, network address hoặc broadcast.
4. Nhập priority, preempt và authentication riêng cho từng host.
5. Repository lưu group/member/options trong transaction; member là đơn vị
   `sync_status`.
6. View & Push preview theo host, sau đó worker dùng session SSH/Telnet hiện có
   và cập nhật đúng member thành công.

Các file được tách theo trách nhiệm:

- `service.py`: validation và policy đa host.
- `repository.py`: inventory query và transaction SQLite.
- `collector.py`: đọc member pending.
- `commands.py` + `templates/cisco_ios/fhrp.j2`: render/redact lệnh.
- `worker.py`: device I/O.
- `push_state.py`: cập nhật trạng thái sau push.
- `view_push.py`: điều phối preview/push.

Hiện push hỗ trợ Cisco IOS qua SSH/Telnet cho HSRP, VRRP và GLBP. RESTCONF,
NETCONF, IPv6, verify trạng thái gateway sau push và rollback tự động chưa được
tích hợp. Authentication secret được che trong preview/report command.
