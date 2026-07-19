# Routing

Điều phối Static, OSPF, EIGRP và routing information. **partial**: CRUD/preview/push có code nhưng repository/worker còn ở namespace legacy. QML entry `qml/features/routing/RoutingView.qml`; DB `t04_*`. Mỗi protocol sở hữu validation và transaction riêng; preview không kết nối, push dùng session registry. Test: routing contract, dev-mode worker, QML smoke. Xem README thư mục con.
