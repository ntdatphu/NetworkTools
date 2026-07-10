# NetworkTools PyQt6/QML app

Thu muc `app/` la ban desktop app dung PyQt6 + QML. QML nam trong
`app/UI/`, Python bridge nam trong `app/main.py`, `app/core/`,
`app/backend/`, va `app/network_code/`.

## Module chinh hien tai la `UI`

Hien tai app chay module chinh `UI`.

Trang thai code sau khi gop:

- `app/UI/qmldir` khai bao `module UI`.
- `app/main.py` goi `engine.loadFromModule("UI", "Main")`.
- `app/core/runtime.py` dat `QML_MODULE_DIR = APP_DIR / "UI"`.
- Cac file QML trong `app/UI/` dang `import UI`.
- `app/network_code/database_paths.json` tro `main_sql` ve `app/UI/main.sql`.

Noi dung moi nhat tu `app/NetworkTools/` da duoc gop sang `app/UI/`. Thu muc
`app/NetworkTools/` khong con la module runtime va se duoc xoa sau khi xac minh.

## Chay app

```bash
cd app
uv sync
uv run python main.py
```

Entry point:

- `main.py`: tao `QApplication`, nap QML module `UI/Main`, dang ky cac object cho QML:
  - `dbManager` -> `core.database.DatabaseManager`
  - `cli` -> `core.runtime.TerminalHelper`
  - `networkMonitor` -> `core.runtime.NetworkMonitor`
  - `statusBarSettings` -> `core.runtime.StatusBarSettings`
  - `themeSettings` -> `core.runtime.ThemeSettings`
  - `AppPaths` -> `core.runtime.AppPaths`

## Cau truc chinh

| Thanh phan | Duong dan | Vai tro |
|---|---|---|
| QML module | `UI/qmldir` | Khai bao module `UI` va danh sach component QML |
| UI shell | `UI/qml/app/Main.qml` | Cua so chinh, shortcut, layout tong |
| Runtime bridge | `core/runtime.py` | Terminal, ping, login/sync, resource path, network/RAM monitor, settings |
| Database bridge | `core/database.py` | Slot `dbManager.*`, khoi tao SQLite, devices, routing, backup |
| DHCP bridge | `core/dhcp_slots.py` + `backend/dhcp/` | Slot DHCP that su thao tac DB |
| Routing bridge | `backend/route/` + `network_code/routing/` | Luu doc routing, preview/push cau hinh |
| Stub bridge | `core/database_stubs.py` | Slot tam cho Interface/ACL/NAT chua co backend that |
| DB runtime | `device_network.db` | SQLite duoc tao/cap nhat tu `UI/main.sql` |
| Path sync | `network_code/database_paths.json` | Cho `network_code` biet DB va SQL dang dung |

## Mapping QML -> Python

### App shell va layout

| QML | Python tuong ung | Ghi chu |
|---|---|---|
| `qml/app/Main.qml` | `main.py`, `core/runtime.py` | Load app, shortcut `Ctrl+N`, goi `cli.openTerminal()` |
| `qml/app/StatefulWindow.qml` | `core/runtime.py` | Dung chung voi QML state/settings |
| `qml/layout/ActivityBar.qml` | `core/runtime.AppPaths` | Lay icon/resource bang `AppPaths.resource()` |
| `qml/layout/StatusBar.qml` | `core/runtime.NetworkMonitor`, `StatusBarSettings` | Hien network type/name, RAM, date/time, notification settings |
| `qml/shared/AppAssets.qml` | `core/runtime.AppPaths` | Helper resolve resource path cho QML |
| `qml/shared/*.qml` | `core/runtime.AppPaths` | Toast, alert, notification, resize handles |

### Device sidebar va quan ly thiet bi

| QML | Python slot/file | Chuc nang |
|---|---|---|
| `qml/panels/DevicesPanel.qml` | `core/database.py` | `getDevices`, `getDeviceByHost`, `deleteDevice`, `setDeviceDevState`, `updateDeviceSuccess` |
| `components/standard/StandardSideBar.qml` | `core/database.py`, `core/runtime.py` | Danh sach device, ping, connect/sync, delete |
| `qml/sidebar/new_device/NewDevice.qml` | `core/database.py` | `addDevice`, `updateDevice`, `createFoldersFromDevices` |
| `qml/sidebar/new_device/BatchNewDevice.qml` | `core/database.py` | `importDevicesFromFile`, `saveDeviceImportSample`, `addDevice` |
| `qml/sidebar/new_device/AddYangcfg.qml` | `core/database.py` | `addYangcfg` |
| `qml/sidebar/devices/DeviceContextMenu.qml` | `core/runtime.AppPaths` | Icon/menu resource |
| `qml/sidebar/header_search/*.qml` | `core/runtime.AppPaths` | Icon/search resource |

Python lien quan:

- `core/database.py`: CRUD device, import JSON/XLSX, tao folder `backup/<host>`.
- `core/runtime.py`: `TerminalHelper.pingHost`, `connectHostAndSync`.
- `network_code/login/device_connector.py`: login thiet bi, luu running-config.

### Backup va thong tin thiet bi

| QML | Python slot/file | Chuc nang |
|---|---|---|
| `qml/content/InformationView.qml` | `core/database.py` | `getRunningConfigBackup(host)` doc `backup/<host>/<host>_running-config.txt` |
| `qml/routing/info_routing.qml` | `core/database.py` | `getRunningConfigBackup`, `getRoutingInfo` |

### Interface

| QML | Python slot/file | Trang thai hien tai |
|---|---|---|
| `qml/interface/InterfaceView.qml` | `core/database_stubs.py` | Dang dung stub: `getRouterInterfaces`, `getRouterInterfaceByName`, `saveRouterInterface`, `deleteRouterInterface` |

Ghi chu: `getRouterInterfaces` cung duoc override that trong `core/dhcp_slots.py` cho DHCP helper. Cac thao tac save/delete interface rieng van la stub.

### DHCP

| QML | Python slot/file | Chuc nang |
|---|---|---|
| `qml/dhcp/DhcpView.qml` | QML container | Man hinh DHCP tong |
| `qml/dhcp/DhcpPoolForm.qml` | `core/dhcp_slots.py`, `backend/dhcp/pool.py` | `getDhcpPools`, `addDhcpPool`, `updateDhcpPool`, `deleteDhcpPool` |
| `qml/dhcp/DhcpExcludedForm.qml` | `core/dhcp_slots.py`, `backend/dhcp/excluded.py` | `getExcludedAddresses`, `addExcludedAddress`, `deleteExcludedAddress` |
| `qml/dhcp/DhcpHelperForm.qml` | `core/dhcp_slots.py`, `backend/dhcp/helper.py`, `backend/dhcp/interfaces.py` | `getRouterInterfaces`, `getDhcpHelperAddresses`, `addDhcpHelperAddress`, `deleteDhcpHelperAddress` |

### Routing

| QML | Python slot/file | Chuc nang |
|---|---|---|
| `qml/routing/RoutingView.qml` | QML container | Man hinh routing tong |
| `qml/routing/static/StaticRoutingForm.qml` | `core/database.py`, `backend/route/static_route.py`, `backend/route/static_default.py` | `getStaticRouting`, `saveStaticRouting` |
| `qml/routing/ospf/OspfRoutingForm.qml` | `core/database.py`, `backend/route/ospf/` | `getOspfRouting`, `saveOspfRouting`, `getLastRoutingError` |
| `qml/routing/eigrp/EigrpRoutingForm.qml` | `core/database.py`, `backend/route/eigrp/` | `getEigrpRouting`, `saveEigrpRouting` |
| `qml/routing/RoutingPushDialog.qml` | `core/database.py`, `network_code/routing/main.py`, `network_code/routing/worker_routing.py` | `previewRoutingConfig`, `pushRoutingConfig` |
| `qml/routing/info_routing.qml` | `core/database.py` | Hien routing table va running-config backup |

Python lien quan:

- `backend/route/static_route.py`: doc/luu static route.
- `backend/route/ospf/*`: normalize, compare, insert/update OSPF.
- `backend/route/eigrp/*`: normalize, sync child table, insert/update EIGRP.
- `network_code/routing/main.py`: routing dispatcher khi preview/push.
- `network_code/routing/worker_routing.py`: render/push cau hinh.
- `network_code/routing/ospf_api.py`: apply OSPF pending qua session login.

### ACL

| QML | Python slot/file | Trang thai hien tai |
|---|---|---|
| `qml/acl/AclView.qml` | QML container | Man hinh ACL tong |
| `qml/acl/AclForm.qml` va `AclRule*.qml` | `core/database_stubs.py` | Dang dung stub: `getAcls`, `saveAcl`, `deleteAcl` |

### NAT

| QML | Python slot/file | Trang thai hien tai |
|---|---|---|
| `qml/nat/NatView.qml` | QML container | Man hinh NAT tong |
| `qml/nat/NatStaticForm.qml` | `core/database_stubs.py` | `getNatStaticEntries`, `addNatStaticEntry`, `deleteNatStaticEntry` dang la stub |
| `qml/nat/NatInterfaceForm.qml` | `core/database_stubs.py` | `getNatInterfaces`, `addNatInterface`, `deleteNatInterface` dang la stub |
| `qml/nat/NatDynamicForm.qml` | `core/database_stubs.py` | `getNatDynamicPools`, `addNatDynamicPool`, `deleteNatDynamicPool` dang la stub |
| `qml/nat/NatPatForm.qml` | `core/database_stubs.py` | `getNatPatRules`, `addNatPatRule`, `deleteNatPatRule` dang la stub |
| `qml/nat/NatAclForm.qml` | `core/database_stubs.py` | `getNatAcls`, `addNatAcl`, `deleteNatAcl` dang la stub |
| `qml/nat/NatRouteMapForm.qml` | `core/database_stubs.py` | `getNatRouteMapEntries`, `addNatRouteMapEntry`, `deleteNatRouteMapEntry` dang la stub |

### Settings, theme, status

| QML | Python slot/file | Chuc nang |
|---|---|---|
| `qml/content/SettingsView.qml` | `core/runtime.ThemeSettings`, `StatusBarSettings` | Luu setting bang `QSettings` |
| `theme/Theme.qml`, `theme/state/*.qml`, `theme/tokens/*.qml` | QML singleton + `core/runtime.py` settings | Theme, token mau/size/font/motion, UI state |
| `qml/layout/StatusBar.qml` | `NetworkMonitor`, `StatusBarSettings` | Trang thai mang, RAM, date/time |

### Man hinh thong tin

| QML | Python slot/file | Ghi chu |
|---|---|---|
| `qml/content/WelcomeScreen.qml` | `AppPaths` | Man hinh chao, resource icon |
| `qml/content/ContentArea.qml` | QML router/container | Doi view theo feature dang chon |

## Context object tu QML

QML khong import truc tiep Python file. QML goi cac object duoc `main.py` dua vao context:

```python
context.setContextProperty("dbManager", DatabaseManager())
context.setContextProperty("cli", TerminalHelper())
context.setContextProperty("networkMonitor", NetworkMonitor())
context.setContextProperty("statusBarSettings", StatusBarSettings())
context.setContextProperty("themeSettings", ThemeSettings())
context.setContextProperty("AppPaths", AppPaths())
```

Vi vay khi them mot nut/chuc nang moi trong QML:

1. Neu can DB: them `@pyqtSlot` vao `core/database.py` hoac mixin trong `core/`.
2. Neu can lenh he thong/login/ping: them vao `core/runtime.py`.
3. Neu la DHCP/routing co logic lon: dat logic trong `backend/`, de `core/database.py` hoac mixin goi.
4. Neu la push cau hinh thiet bi: dung/bo sung `network_code/`.

## Trang thai bridge hien tai

- Da co backend that: Devices, import device, backup running-config, DHCP, Static Routing, OSPF, EIGRP, routing preview/push, status/network/theme settings.
- Dang la stub: Interface save/delete, ACL, NAT.
- `app/UI/` la module QML chinh dang duoc app load.
