# Interfaces

Quản lý interface router, switchport và SVI. **partial**: QML ở `qml/features/interfaces/InterfaceView.qml` và `qml/features/switching/interfaces`; persistence hiện chia giữa DHCP/switching legacy. API load/save/edit/delete qua `dbManager`; DB gồm `t02_*` và các bảng switching liên quan. Validation yêu cầu device tồn tại, tên interface hợp lệ và parent-child ghi trong một transaction. Worker sync/push còn planned. Test chính: `test_switching_workspace.py`, `test_dhcp_acl_persistence.py`. Backlog: repository contract chung, tách khỏi DHCP và test rollback.
