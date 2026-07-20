# ACL

Standard/extended/MAC/reflexive ACL và interface bindings. **implemented**. QML `qml/features/acl/AclView.qml`; slots `core/acl_slots.py`; repository/validation `features/acl`; DB nhóm ACL `t05_*`. Save/delete ACL và rules/bindings là transaction cha-con, rollback khi validation/SQL lỗi. View/push mới partial. Test: `test_dhcp_acl_persistence.py`, UI/QML contracts. Backlog: chuyển namespace và dùng model chung có kiểm soát với NAT.
