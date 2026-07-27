# NAT

Static, dynamic pool, PAT, inside/outside interface, NAT ACL và route-map. **implemented**. QML `qml/features/nat/NatView.qml`; slots `core/nat_slots.py`; persistence trong `nat_db.py`; View & Push trong `collector.py`, `dispatcher.py`, `worker.py` và `templates/`; DB nhóm NAT/NAT ACL `t05_*`.

Nút View & Push ở header gom và render NAT ACL trước NAT engine, chạy nền, dùng session tab hiện có và chỉ cập nhật tracking row sau kết quả thành công. Preview/dev mode không mở kết nối thật. Validation bao gồm address/port/pool/reference.

Test: `test_nat_persistence.py`, dev-mode worker, QML smoke. Backlog: service boundary và transaction cha-con đầy đủ.
