# Interfaces

Router interface persistence, workspace và View & Push. **implemented** cho Cisco
IOS SSH/Telnet trong phạm vi được mô tả bên dưới. `repository.py` sở hữu API
load/save/edit/delete `t02_*`; `core/interface_slots.py` giữ contract QML. Shim
`features/dhcp/interfaces.py` chỉ còn để tương thích import cũ.

UI được tách theo trách nhiệm:

- `InterfaceView.qml`: điều phối host, model, selection, context menu và shortcut.
- `InterfaceEditorPane.qml`: form L3/WAN/Tunnel và tạo payload.
- `InterfaceSavedPanel.qml`: danh sách, badge và row action.

Pipeline push được tách theo trách nhiệm:

- `collector.py`: đọc pending state ở bảng interface chính và profile L3/WAN/Tunnel.
- `commands.py`: dựng lệnh Cisco IOS thuần và redaction mật khẩu PPP.
- `worker.py`: gửi một batch interface qua session SSH/Telnet do app sở hữu.
- `push_state.py`: chỉ cập nhật/xóa đúng row sau khi thiết bị chấp nhận lệnh.
- `view_push.py`: kiểm tra platform, điều phối preview/push và tạo report theo interface.

Nguồn tham khảo ban đầu là `backend/PyCode/router_layer3/interface`, nhưng runtime
mới không tạo Nornir inventory hoặc file output tạm. Nó dùng chung
`DeviceSessionRegistry` với app để tránh mở hai kết nối cho cùng một thao tác.

Hiện hỗ trợ Cisco IOS qua SSH/Telnet cho cấu hình cơ bản, secondary IPv4, tuning
L3, WAN và Tunnel. Preview và report che mật khẩu PPP. RESTCONF/NETCONF, IPv6,
verify sau push và rollback tự động chưa nằm trong phạm vi tích hợp này; cần kiểm
chứng cú pháp WAN/Tunnel trên image lab mục tiêu trước khi dùng thực tế.

Test chính: `test_interface_view_push.py`, `test_dhcp_acl_persistence.py`,
`test_ui_contracts.py` và QML smoke.
