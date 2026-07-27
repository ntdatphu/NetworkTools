# ACL

Standard/extended/dynamic/reflexive/MAC ACL và interface bindings. **implemented**. QML `qml/features/acl/AclView.qml`; slots `core/acl_slots.py`; persistence/validation trong `acl_db.py`, `rules.py`, `bindings.py`; View & Push trong `collector.py`, `dispatcher.py`, `worker.py` và `templates/`.

Preview gom các row `success = 0/-1`, render ACL cùng `ip access-group` mà không kết nối. Push chạy nền qua session SSH/Telnet đang gắn với tab hoặc Nornir fallback; `dev = 1` chỉ mô phỏng. Chỉ kết quả thiết bị thành công mới chuyển row sang `success = 1`/xóa row pending-delete. RESTCONF chưa được backend ACL hỗ trợ.

Test: `test_acl_view_push.py`, `test_dhcp_acl_persistence.py`, UI/QML contracts. Backlog: fake-connector integration cho nhiều ACL trên cùng host và model dùng chung có kiểm soát với NAT ACL.
