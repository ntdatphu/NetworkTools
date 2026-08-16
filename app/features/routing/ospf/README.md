# OSPF

**partial**, đối chiếu **2026-08-16**, cho process, area/range, network,
distance, interface, passive, redistribution và tuning. QML
`UI/qml/features/routing/ospf/OspfRoutingForm.qml`; API qua `dbManager`; DB nhóm
OSPF `t04_*`; worker `features/routing/ospf/worker.py`. Validate process/area/
prefix/cost và ghi parent-child atomically. Backlog: repository/service riêng và
fake-session integration rộng hơn.
