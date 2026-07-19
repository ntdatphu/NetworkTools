# Bản đồ chức năng NetworkTools

Trạng thái được đối chiếu ngày 2026-07-19. `partial` nghĩa là luồng chính có code nhưng còn nằm trong facade/adapter legacy hoặc thiếu test độc lập.

## Tổng quan

| Feature | Role | Trạng thái | QML entry | Python API hiện tại | Persistence/worker | DB |
|---|---|---|---|---|---|---|
| Devices | all | partial | `UI/qml/sidebar/new_device`, `panels/DevicesPanel.qml` | `core.database.DatabaseManager` | facade trong `core/database.py` | device_network |
| Interfaces | rou/sw2/sw3 | partial | `UI/qml/features/interfaces/InterfaceView.qml` | `DatabaseManager`, switching slots | `features/dhcp/interfaces.py`, switching repository | device_network |
| DHCP | rou/sw3 | implemented | `UI/qml/features/dhcp/DhcpView.qml` | `core/dhcp_slots.py` | `features/dhcp`, `features/dhcp/worker.py` | device_network |
| Routing | rou/sw3 | partial | `UI/qml/features/routing/RoutingView.qml` | `DatabaseManager` | `features/routing`, `features/routing/worker.py` | device_network |
| ACL | rou/sw2/sw3 | implemented | `UI/qml/features/acl/AclView.qml` | `core/acl_slots.py` | `features/acl` | device_network |
| NAT | rou | implemented | `UI/qml/features/nat/NatView.qml` | `core/nat_slots.py` | `features/nat`, `features/nat/worker.py` | device_network |
| Switching | sw2/sw3 | partial | `UI/qml/features/switching/SwitchWorkspace.qml` | `core/switch_slots.py` | `features/switching` | device_network |
| Syslog | all | implemented | `UI/qml/features/syslog/SyslogWorkspace.qml` | `SyslogManager` | `features/syslog` | info_collected |

## UI → Python

| QML | Context object | Contract | Async? |
|---|---|---|---:|
| device/sidebar views | `dbManager` | device CRUD, tab lifecycle | no |
| feature workspaces | `dbManager` | load/save/delete/view/push slots | push: yes |
| terminal actions | `cli` | open/send/close session | yes |
| syslog workspace | `syslogManager`, `syslogSettings` | lifecycle/query/settings | yes |
| SFTP workspace | `sftpController` | connect/list/transfer | yes |

## Python → database

| Feature | Authority | Tables | Transaction |
|---|---|---|---:|
| Devices | DatabaseManager facade | `t01_devices` | yes |
| Interfaces | DHCP/switching repositories | `t02_*`, switching interface tables | yes |
| DHCP | DHCP repositories | `t03_*`, `t08_*` | yes |
| Routing | route repositories | `t04_*` | yes |
| ACL/NAT | ACL/NAT repositories | `t05_*` | yes |
| Switching | switching repositories | `t06_*` | yes |
| Syslog | SyslogRepository | syslog event/settings tables | batched |

## Thiết bị

| Feature | Show/collect | Config | Parser/worker |
|---|---|---|---|
| DHCP | show DHCP bindings/pools | IOS DHCP pool/helper commands | `features/dhcp/worker.py` |
| Routing | show ip route/protocol | static, OSPF, EIGRP templates | `features/routing/worker.py` |
| NAT | show ip nat | IOS NAT commands | `features/nat/worker.py` |
| Syslog | UDP/TCP messages | IOS logging commands | syslog receiver/parser/configurator |

## Ma trận UI

| Feature | Load | Save | Edit | Cancel | Delete | View | Push | Sync |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Devices | 🟡 | 🟡 | 🟡 | 🟡 | 🟡 | — | — | — |
| Interfaces | 🟡 | 🟡 | 🟡 | 🟡 | 🟡 | 📌 | 📌 | 📌 |
| DHCP | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | 🟡 |
| Routing | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | 🟡 |
| ACL | ✅ | ✅ | ✅ | ✅ | ✅ | 🟡 | 🟡 | 📌 |
| NAT | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | 🟡 |
| Switching | 🟡 | 🟡 | 🟡 | 🟡 | 🟡 | 🟡 | 📌 | 📌 |
| Syslog | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

## Ownership và dependency

| Module | Được import | Không được import | Owner | Test chính |
|---|---|---|---|---|
| `features/*` | core contracts, infrastructure | feature khác không qua contract | feature tương ứng | unit/integration feature |
| `infrastructure/database` | stdlib | QML, feature | platform | database bootstrap |
| `infrastructure/network` | transport libraries | QML, repository | platform | fake connector |
| `UI` | module `UI`, context objects | SQLite/worker | UI | QML smoke |

## Known gaps

| ID | Feature | Thiếu sót | Ảnh hưởng | Kế hoạch | Trạng thái |
|---|---|---|---|---|---|
| GAP-001 | Devices | facade còn lớn trong `core/database.py` | coupling | tách repository/service có test | open |
| GAP-002 | Network | worker đã chuyển nhưng integration test cần dependency tùy chọn | chưa xác minh full suite tại sandbox | chạy fake-session/full suite trong môi trường đã sync | blocked-environment |
| GAP-003 | Runtime | `core/runtime.py` còn nhiều QObject | khó bảo trì | tách settings/tasks/monitoring | open |
| GAP-004 | CI | môi trường hiện tại thiếu PyQt6/Jinja2/Paramiko | chưa chạy full suite | chạy `uv sync` nơi có network/cache | blocked-environment |
