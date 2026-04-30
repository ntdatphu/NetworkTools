# PROJECT SUMMARY

## Phạm vi
- Tài liệu tổng quan toàn dự án, loại trừ nội dung liên quan PythonEnvManager.

## 1) Kiến trúc tổng thể (C++ + QML)

Dự án dùng mô hình Qt Quick frontend + C++ backend:
- Frontend QML: tổ chức giao diện theo module layout, sidebar, devices, content, routing, dhcp.
- Backend C++: cung cấp data/service qua QObject context properties và Q_INVOKABLE methods.
- Build system: CMake + Qt6, đóng gói QML, resources và C++ vào executable.

Các context properties được inject từ main.cpp:
- dbManager: lớp DatabaseManager làm facade cho tầng dữ liệu.
- cli: lớp TerminalHelper cho thao tác terminal/ping.
- networkMonitor: lớp NetworkMonitor cho trạng thái mạng thời gian thực.

## 2) Data flow chính

## Startup flow
1. main.cpp khởi tạo QApplication và metadata ứng dụng.
2. ScriptSyncHelper đồng bộ thư mục script về thư mục chạy app.
3. DatabaseManager.initializeDatabase() mở hoặc tạo SQLite DB.
4. Nếu DB mới: DatabaseConnection gọi script Python `script/database/init_db.py` (qua `QProcess`) để tạo DB từ `data.sql`.
5. Nếu DB đã tồn tại: DatabaseConnection áp dụng migration schema tối thiểu (ví dụ thêm cột/table mới như devices.yangcfg và bảng yangcfg).
6. Inject dbManager, cli, networkMonitor cho QML.
7. Load module QML NetworkUI với Main.qml.

## UI interaction flow
1. Người dùng thao tác trên Main.qml và các component con.
2. Các signal từ menu/sidebar/tab/feature điều phối state giao diện.
3. Khi cần dữ liệu, QML gọi trực tiếp dbManager qua Q_INVOKABLE.
4. Kết quả trả về QVariantList/QVariantMap được nạp vào ListModel để render.
5. StatusBar đọc trực tiếp networkMonitor properties qua bindings reactive (trạng thái mạng, RAM %, ngày/tháng/năm và giờ hiện tại).

## Device management flow
1. PanelSideBar gọi dbManager.getDevices() để tải danh sách.
2. NewDevice gọi add/update và sau đó createFoldersFromDevices().
3. DeviceContextMenu phát signal edit/delete cho mọi trạng thái; riêng Ping chỉ bật khi thiết bị connected (`success = 1`), và menu tự đóng khi click ra ngoài.
4. Với thiết bị waiting (`success = 0`), menu có thêm:
  - `Up (Admin)`: cập nhật `success` từ 0 sang 1 qua `dbManager.updateDeviceSuccess(...)`, sau đó refresh danh sách.
  - `Connec`: gọi terminal helper để in chuỗi `connec` trong terminal.
5. Với thiết bị connected (`success = 1`), menu có thêm `Down (Admin)` để cập nhật ngược lại `success` từ 1 về 0, sau đó refresh danh sách.
6. Với thiết bị connected (`success = 1`), menu có thêm `Add Yangcfg` để mở form nhập thông tin và thêm bản ghi vào bảng `yangcfg`.
7. Hậu tố `(Admin)` là tính năng dành cho người phát triển (developer) trong quá trình phát triển và kiểm thử.

## DHCP flow
1. DhcpPoolForm và DhcpExcludedForm nhận currentHostIp.
2. Form gọi getDhcpPools/getExcludedAddresses để load danh sách.
3. Add/Delete thao tác ngay bằng dbManager methods.

## Routing flow
- RoutingView phân tách theo tab: Static, OSPF, EIGRP.
- StaticRoutingForm điều phối toàn bộ luồng Static/Default route: load -> compare snapshot -> save phân tách.
  - `StaticRoutingDefaultCard`: UI nhập default route, Enter = Save, Cancel revert, Save bị disable khi chưa đổi.
  - `StaticRoutingRoutesCard`: UI danh sách static routes; Enter trong ô nhập = Save Static; Save disable khi chưa đổi.
  - `StaticRouteRow`: delegate từng dòng route; phát `submitRequested` khi Enter.
  - `StaticRoutingValidationDialog`: dialog modal báo thiếu field bắt buộc.
- OSPF/EIGRP form quản lý UI process card, Push Config đang ở mức placeholder.

## 3) Key modules

## Entry và tích hợp
- main.cpp: entry point, inject context properties, load QML module.
- CMakeLists.txt: cấu hình build Qt/QML/resources và copy data.sql sau build.

## Data layer
- DatabaseConnection: quản lý kết nối SQLite; với DB mới thì gọi `script/database/init_db.py` để khởi tạo schema từ `data.sql`.
- DatabaseManager: facade cho QML gọi CRUD và nghiệp vụ liên quan.
- DeviceRepository, DhcpPoolRepository, ExcludedAddressRepository: truy vấn SQL theo domain.
- Schema hiện có thêm bảng yangcfg để lưu thông tin đăng nhập RESTCONF của Cisco theo host (nếu host có hỗ trợ).
- SqlUtils: helper bind giá trị nullable cho truy vấn SQL.
- BackupService: tạo thư mục backup theo danh sách host.

## System helpers
- TerminalHelper: mở terminal hệ thống, ping host (khi connected) và in `connec` cho thao tác context menu của thiết bị waiting.
- NetworkMonitor: phát hiện trạng thái kết nối mạng, đồng thời cung cấp phần trăm RAM hệ thống để StatusBar hiển thị.
- ScriptSyncHelper: đồng bộ script folder dựa trên versionScript.txt.
- VersionScriptHelper: helper copy version file (có trong codebase, không thấy được gọi ở startup hiện tại).

## UI modules
- app/: shell ứng dụng và Theme singleton.
- layout/: menu/activity/status bar.
- sidebar/: tìm kiếm/lọc/danh sách thiết bị + dialog thêm sửa.
- devices/: tab thiết bị và state theo tab.
- content/: router hiển thị theo appMode/feature.
- routing/, dhcp/: màn hình nghiệp vụ theo feature.
- shared/: thành phần dùng lại (alert, resize handles).

## 4) Interaction overview

## C++ -> QML
- Dữ liệu và hàm backend được expose qua context property.
- QML gọi hàm C++ trực tiếp bằng Q_INVOKABLE cho CRUD.

## QML -> QML
- Các component trao đổi qua signal/handler:
  - PanelSideBar -> Main -> DeviceTabs -> ContentArea.
  - FeatureBar -> DeviceTabs -> ContentArea.
  - AppMenuBar -> Main actions.

## State management
- Theme singleton điều phối style/spacing/màu thống nhất.
- DeviceTabs dùng Settings để persist tab/session state.
- Routing/DHCP forms dùng ListModel cục bộ để quản lý danh sách hiển thị.

## Kết luận ngắn
- Kiến trúc hiện tại rõ ràng theo hướng tách UI và data layer.
- Điểm mạnh là QML gọi backend trực tiếp, tốc độ phát triển nhanh cho CRUD.
- Một số mảng feature nâng cao (đặc biệt Routing push config) đang ở trạng thái UI-ready nhưng backend integration chưa hoàn tất.
