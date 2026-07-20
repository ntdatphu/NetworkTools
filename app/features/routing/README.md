# Routing

Điều phối Static, OSPF, EIGRP và routing information. **partial**: CRUD/preview/push đã ở namespace feature nhưng service/repository vẫn cần tách nhỏ hơn. QML entry `qml/features/routing/RoutingView.qml`; DB `t04_*`. Mỗi protocol sở hữu validation và transaction riêng; preview không kết nối, push dùng session registry. Test: routing contract, dev-mode worker, QML smoke. Xem README thư mục con.
