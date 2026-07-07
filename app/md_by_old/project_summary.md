# Project Summary - NetworkTools Frontend

## 1. Tong quan

`frontend` la ung dung desktop Qt/QML cho du an NetworkTools. Giao dien huong den viec quan ly thiet bi mang, mo tab theo tung thiet bi, cau hinh cac tinh nang nhu Routing, DHCP, ACL, NAT, theo doi trang thai he thong va goi luong ket noi/sync tu backend Python.

Ung dung co phong cach bo cuc gan voi VS Code:

- Activity bar ben trai de chuyen che do chinh: Devices, Logs & Alerts, Settings.
- Sidebar co danh sach thiet bi, tim kiem, filter, context menu va form them/sua/xoa.
- Khu noi dung trung tam hien thi tab thiet bi, feature bar va form cau hinh theo tinh nang.
- Status bar duoi cung hien thi trang thai Python/backend, mang, RAM va thong bao.

## 2. Cong nghe va phu thuoc

- Ngon ngu chinh: C++ va QML/JavaScript.
- Framework UI: Qt 6, su dung `Quick`, `Quick.Controls.Basic`, `Quick.Layouts`, `QuickEffects`, `LabsPlatform`, `Widgets`.
- Build system: CMake, yeu cau Qt 6.8 theo `qt_standard_project_setup(REQUIRES 6.8)`.
- Database: SQLite. Du an build truc tiep SQLite amalgamation tu `src/database/sqlite-amalgamation/sqlite3.c`.
- Backend tich hop: thu muc `../backend` duoc copy vao output sau build; frontend goi script Python nhu `script/login/connect_selected.py`.
- Python runtime: `TerminalHelper` kiem tra/cai dat virtual environment bang `setup_venv.bat` hoac `setup_venv.sh`, can `uv` va Python trong PATH.

## 3. Entry point va khoi tao

- `main.cpp` tao `QApplication`, dat thong tin ung dung, icon, khoi tao `DatabaseManager`, `TerminalHelper`, `NetworkMonitor`.
- Cac object C++ duoc expose sang QML qua context property:
  - `dbManager`: API database va repository.
  - `cli`: mo terminal, ping, kiem tra Python deps, connect/sync host.
  - `networkMonitor`: trang thai mang, ten mang va RAM usage.
- QML entry point la module `NetworkTools`, component `Main`.
- `DatabaseManager::initializeDatabase()` mo/khoi tao file `device_network.db` trong thu muc chay cua app.

## 4. Cau truc thu muc chinh

- `CMakeLists.txt`: dinh nghia executable, QML module, resource, source C++ va lenh copy backend sau build.
- `main.cpp`: entry point ung dung.
- `qml/app`: cua so chinh va logic restore window state.
- `qml/layout`: activity bar, status bar.
- `qml/panels`: panel Devices, Logs & Alerts, Settings trong sidebar.
- `qml/sidebar`: danh sach thiet bi, search/header, form them thiet bi, batch add, yangcfg.
- `qml/devices`: tab thiet bi va item tab.
- `qml/content`: dieu phoi man hinh noi dung theo app mode va feature dang chon.
- `qml/routing`, `qml/dhcp`, `qml/acl`, `qml/nat`: cac man hinh cau hinh mang.
- `components`: component dung chung cho card, button, input, dropdown, sidebar, form layout.
- `theme/Theme.qml`: singleton theme, kich thuoc, mau sac, typography, animation, app lock.
- `resources`: icon SVG/PNG/ICO cho activity bar, sidebar, status bar, logo.
- `src/database`: connection, manager, repositories va SQLite amalgamation.
- `src/TerminalHelper.*`: mo terminal, ping, chuan bi Python env, chay connect script.
- `src/NetworkMonitor.h`: timer theo doi mang va RAM.

## 5. Kien truc UI

`qml/app/Main.qml` la trung tam dieu phoi UI:

- Quan ly trang thai sidebar, notification, active setting, thiet bi dang active.
- Dung `SplitView` de chia sidebar va content.
- `ActivityBar` dieu khien app mode.
- `PanelSideBar` hien panel theo app mode.
- `DeviceTabs` quan ly cac tab thiet bi dang mo.
- `FeatureBar` chon nhom tinh nang cua thiet bi.
- `ContentArea` render man hinh thuc te theo feature dang chon.
- `StatusBar` nhan trang thai Python/backend tu `DevicesPanel` va trang thai mang/RAM tu `networkMonitor`.

`qml/app/StatefulWindow.qml` xu ly restore/save kich thuoc, vi tri va trang thai maximize cua cua so bang `Settings`.

## 6. Luong du lieu va database

`DatabaseConnection` tao/mo SQLite database tai:

```text
<applicationDirPath>/device_network.db
```

Neu database chua ton tai, schema duoc nap tu:

```text
<applicationDirPath>/backend/sql/main.sql
```

Voi database cu, code co cac buoc migration nho de them cot/bang moi nhu `devices.yangcfg`, bang `yangcfg`, cot `success/action/metric_weights/passive_default` cho mot so bang routing.

`DatabaseManager` la facade expose sang QML va uy quyen cho repository:

- `DeviceRepository`: them/sua/xoa/list thiet bi, cap nhat `success`, them `yangcfg`.
- `DhcpPoolRepository`, `ExcludedAddressRepository`: DHCP pool va excluded address.
- `RoutingStaticRepository`: static/default route, co transaction va soft-delete bang `success = -1`.
- `OspfRoutingRepository`, `EigrpRoutingRepository`: luu/lay/clear process routing.
- `NatRepository`, `NatAclRepository`: doc NAT interfaces, PAT, dynamic pools, static mappings, NAT ACL.
- `BackupService`: tao thu muc backup theo host.

Schema backend lon hon phan UI hien tai, gom cac nhom bang cho interface, routing, ACL, NAT, VLAN, L2, VRF.

## 7. Tinh nang hien co

- Quan ly thiet bi:
  - Them mot thiet bi.
  - Them hang loat.
  - Sua/xoa thiet bi.
  - Tim kiem va filter theo status/type.
  - Phan nhom Connected, Waiting, Disconnected.
  - Ping host qua terminal.
  - Admin set trang thai connected/waiting.
  - Add Yang config credential.

- Ket noi backend:
  - Tu context menu co flow connect host.
  - `TerminalHelper` kiem tra Python/uv, tao/verify venv, chay `connect_selected.py`.
  - Sau connect, UI reload device list va hien toast/status.

- Tab va workspace:
  - Mo thiet bi thanh tab.
  - Dong tab, reopen tab, next/previous tab, drag/move tab.
  - Moi tab giu feature dang chon.

- Routing:
  - Static/default route co form luu database.
  - OSPF va EIGRP co form process/network va repository tuong ung.
  - Info va BGP dang placeholder.

- DHCP:
  - DHCP Pool.
  - Excluded Address.
  - Info dang placeholder.

- ACL:
  - Form tao rule theo loai Standard, Extended, Dynamic, Reflexive, MAC.
  - Hien danh sach pending rules trong QML.

- NAT:
  - Views cho Static, Dynamic, PAT, Interfaces, ACL.
  - Cac form doc du lieu NAT tu database qua repository.

- He thong/UI:
  - Theme dark/light/system trong singleton `Theme`.
  - Toast va notification panel.
  - Status bar hien Python/backend status, network status, RAM usage.
  - Restore window state.
  - Sidebar resize/collapse.

## 8. Tinh nang chua hoan thien hoac dang placeholder

- Cac feature trong `ContentArea` co danh sach lon: VLAN, BGP, STP, QoS, SNMP, NTP, AAA, MPLS, VPN, Firewall, Monitor. Hien chi Routing, DHCP, ACL, NAT co view rieng; cac feature con lai hien "Not yet implemented".
- Routing Info va BGP dang placeholder.
- DHCP Info dang placeholder.
- NAT Info dang placeholder.
- Logs & Alerts va Settings co khung UI rieng, can doc them chi tiet neu muon danh gia day du muc do hoan thien.
- ACL hien co nhieu input QML, nhung trong `DatabaseManager` chua expose API luu ACL tong quat tu `ACL_DB`; can kiem tra tiep neu muc tieu la luu ACL that vao database.

## 9. Build va chay

Build bang CMake voi Qt 6.8. Target chinh la `NetworkTools`.

Sau build, CMake copy:

- `../backend` vao thu muc output cua executable.
- `setup_venv.bat`, `setup_venv.sh`, `packages.txt` vao output.

Khi app chay lan dau, database duoc tao tu `backend/sql/main.sql` trong thu muc output. Vi vay output sau build can co backend da duoc copy dung cach.

## 10. Luu y ky thuat

- Co nhieu comment trong source hien bi loi encoding khi doc bang terminal, kha nang file goc co van de ma hoa hoac terminal dang hien sai codepage. Nen thong nhat UTF-8 de tranh kho doc/khac biet diff.
- `rule.md` trong `frontend` dang la file untracked theo `git status`; file nay khong lien quan truc tiep den build.
- `components/standard/StandardSideBar.qml` co ve trung lap logic voi `qml/panels/DevicesPanel.qml`; neu tiep tuc phat trien sidebar nen xac dinh component nao la source of truth.
- `TerminalHelper::connectHostAndSync` chay process dong bo trong QML timer callback. Voi script lau, UI co the bi block trong luc connect.
- Mat khau thiet bi duoc luu qua database field `password`; can danh gia lai ve ma hoa/bao mat neu dung thuc te.
- Migration schema hien duoc viet thu cong trong `DatabaseConnection.cpp`; neu schema tang nhanh nen can co co che migration co version ro rang.
- `NatRepository` hien chu yeu doc du lieu; them/sua/xoa NAT form co the chua duoc expose day du qua C++.

## 11. Huong mo rong de xuat

- Hoan thien API C++ cho ACL/NAT neu UI can luu du lieu thuc.
- Dua cac tac vu Python/backend sang bat dong bo de tranh dong bang UI.
- Chuan hoa encoding source sang UTF-8.
- Them test/kiem tra build toi thieu cho C++ repository va QML lint neu workflow cho phep.
- Tach ro domain "pending config", "applied config", "deleted config" thay vi chi dua vao cot `success` neu luong sync backend phuc tap hon.
