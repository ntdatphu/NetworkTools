# Routing

`clone_service.py` owns OSPF/EIGRP process cloning. QML obtains only connected
(`success = 1`) target hosts through routing slots, supports selecting many
targets, validates the target process ID against every selected host, and
persists cloned rows as pending (`success = 0`) for View & Push. Batch results
retain successful hosts and report each failed host with its reason.

Each selected target owns independent Process ID/AS Number and Router ID
values. Clone Save & Push persists first and opens a batch preview; device
commands run only after the user confirms with Push in that preview.

Điều phối Static, OSPF, EIGRP và routing information. **partial**: CRUD/preview/push đã ở namespace feature nhưng service/repository vẫn cần tách nhỏ hơn. QML entry `qml/features/routing/RoutingView.qml`; DB `t04_*`. Mỗi protocol sở hữu validation và transaction riêng; preview không kết nối, push dùng session registry. Test: routing contract, dev-mode worker, QML smoke. Xem README thư mục con.
