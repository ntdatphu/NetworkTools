# NAT

Static, dynamic pool, PAT, inside/outside interface, NAT ACL và route-map. **implemented**. QML `qml/features/nat/NatView.qml`; slots `core/nat_slots.py`; repository `features/nat`; collector/worker `features/nat/worker.py`; DB nhóm NAT/ACL `t05_*`. Validation bao gồm address/port/pool/reference; service phải gọi ACL contract thay vì sửa bảng sở hữu ngoài. Test: `test_nat_persistence.py`, dev-mode worker, QML smoke. Backlog: service boundary và transaction cha-con đầy đủ.
