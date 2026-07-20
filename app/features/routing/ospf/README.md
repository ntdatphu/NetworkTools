# OSPF

**partial** cho process, area, network, interface, passive, redistribution và tuning. QML `qml/features/routing/ospf/OspfRoutingForm.qml`; API qua `dbManager`; DB nhóm bảng OSPF `t04_*`; worker `features/routing/ospf/worker.py`. Validate process/area/prefix/cost và ghi parent-child atomically. Test CRUD contract/QML smoke; backlog: repository/service riêng và fake-session integration.
