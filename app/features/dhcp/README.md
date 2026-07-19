# DHCP

DHCP pool, excluded address và helper address. **implemented** với QML `qml/features/dhcp/DhcpView.qml`, slots `core/dhcp_slots.py`, persistence `features/dhcp`, worker `features/dhcp/worker.py` trong thời gian chuyển đổi. DB: `t03_*`, `t08_*`; kiểm tra network/mask, range, gateway, DNS và foreign key interface. Luồng Load/Save/Edit/Delete qua slot; View tạo preview không kết nối; Push chạy nền/dev mode không mở session thật. Test: `test_dhcp_acl_persistence.py`, `test_dev_mode_workers.py`, QML smoke. Backlog: chuyển code/QML vào namespace feature và fake-connector integration test.
