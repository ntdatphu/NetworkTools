# Chức năng hiện có của NetworkTools App

Cập nhật: **2026-08-11**. Tài liệu này mô tả những gì người dùng có thể thao tác
trong desktop app ở trạng thái mã nguồn hiện tại. “Có code” không đồng nghĩa đã
được kiểm chứng production trên mọi model/firmware thiết bị.

## 1. Quản lý thiết bị và phiên kết nối

- Thêm, sửa, xóa, tìm kiếm, lọc và nhập nhiều thiết bị vào inventory SQLite.
- Phân loại router, switch Layer 2 và switch Layer 3 theo `role`.
- Ping, Connect, Reconnect, Disconnect và chạy batch tối đa có giới hạn đồng thời.
- Mở nhiều tab thiết bị; session vẫn tồn tại khi đóng tab và được khóa theo host.
- Mở CLI tương tác do app quản lý, không truyền mật khẩu qua command line.
- Thu thập `running-config`, lưu snapshot theo host và đồng bộ trạng thái hỗ trợ.
- Lưu `running-config` thành `startup-config` trên session SSH/Telnet đang mở qua
  menu **Save configuration**. App không tự mở kết nối ngầm cho thao tác này.
- Dev-mode để preview/test luồng được hỗ trợ mà không kết nối thiết bị thật.

## 2. Cấu hình router và dịch vụ mạng

| Nhóm | Khả năng hiện có |
| --- | --- |
| Interface | CRUD địa chỉ IPv4/secondary, L3 tuning, WAN/PPP và Tunnel; preview/push Cisco IOS SSH/Telnet |
| Static routing | Default/static route, lưu desired state, preview/push |
| OSPF | Process, network/area và các tham số liên quan; persistence, preview/push |
| EIGRP | Process, network, interface, passive, key-chain và policy liên quan; persistence, preview/push |
| Routing Group | Gom nhiều host, lọc connected network, preview/push theo host |
| FHRP | HSRP, VRRP, GLBP; validation, lưu và preview/push nhiều member |
| DHCP | Pool, excluded address, helper/relay, thông tin thu thập và preview/push |
| ACL | Standard/extended/MAC ACL, rule và binding nhiều interface; preview/push |
| NAT | Static/dynamic NAT, PAT, NAT ACL và route-map; preview/push |

## 3. Switching

- CRUD switch port, access/trunk, VLAN, routed port và SVI cho đúng vai trò SW2/SW3.
- Xem port counter và MAC address table đã thu thập.
- Preview/Push Layer 2 Cisco IOS qua SSH/Telnet cho VLAN, switchport,
  EtherChannel, STP, VTP, DHCP Snooping/DAI và Port Security.
- Theo dõi hash trạng thái push theo module; chỉ đánh dấu đồng bộ sau khi thiết bị
  chấp nhận lệnh.

STP, VTP và EtherChannel chưa có trang CRUD riêng; dữ liệu tương ứng vẫn được
đọc từ SQLite và đi cùng View & Push Layer 2. Các giới hạn chi tiết nằm trong
[`INTEGRATION_LIMITATIONS.md`](../app/features/switching/INTEGRATION_LIMITATIONS.md).

## 4. Quan sát, dữ liệu và tiện ích

- Syslog UDP/TCP: listener, parser, cấu hình nguồn, filter/page, retention và lưu
  theo batch vào `info_collected.db`.
- Device Logs: capture/inspect lưu lượng bằng TShark trong môi trường được cấp quyền.
- SFTP tích hợp: xác nhận host key, duyệt thư mục, upload/download, progress/cancel;
  có thể mở client SFTP ngoài đã cấu hình.
- Database Browser, SSH/Telnet client và terminal ngoài qua catalog ứng dụng.
- Xem database/schema, trạng thái hệ thống, notification history và phím tắt.
- Workspace project có thể tạo/mở/lưu, mã hóa bằng mật khẩu, snapshot và phục hồi.

## 5. Lịch sử và đối chiếu cấu hình

- Lưu lịch sử `running-config` riêng cho từng host bằng Dulwich.
- Xem snapshot mới nhất, danh sách tối đa 100 commit và nội dung commit bất kỳ.
- So sánh hai phiên bản bằng unified diff, thống kê dòng thêm/xóa.
- Thu thập nhiều host, preview đồng bộ thủ công và giữ desired state đang pending
  khi có xung đột.

## 6. Chưa phải chức năng app

- Topology discovery/draw.io của backend cũ chưa được tích hợp: implementation
  hiện tại quét blocking, thiếu scope/limit/cancel và chưa có UI/test an toàn.
- Packet sniffer dùng để thu thập credential Telnet không được tích hợp.
- FastAPI cũ không phải runtime bắt buộc của desktop app và chưa có auth/task
  contract đủ an toàn để công bố là API sản phẩm.
- NETCONF/RESTCONF, rollback/verify tự động và hỗ trợ đa vendor chưa đồng đều.
- Topology, Console Serial, SNMP và plugin/provider API vẫn là backlog.

Xem bảng đối chiếu nguồn backend tại
[`BACKEND_APP_PARITY.md`](BACKEND_APP_PARITY.md).
