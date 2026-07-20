# Switching

Switchport, VLAN, SVI/L3, monitoring; VTP/STP/EtherChannel/port-security còn **partial/planned**. QML `qml/features/switching/SwitchWorkspace.qml`; slots `core/switch_slots.py`; repository `features/switching`; DB `t06_*`. Save/edit/delete phải validate VLAN/interface/device role và transaction. Worker push/sync planned. Test: `test_switching_workspace.py`, QML smoke. Backlog: module con và worker/fake connector.
