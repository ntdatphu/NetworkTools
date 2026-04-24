# GENERATED FILES

## Phạm vi
- Danh sách file/thư mục được tạo ở build-time hoặc runtime.
- Loại trừ các thành phần liên quan PythonEnvManager.

## 1) Build-time generated/copied

## appNetworkUI executable
- Loại: binary output.
- Mục đích: file chạy chính của ứng dụng.
- Khi tạo: trong quá trình build từ CMake target appNetworkUI.

## data.sql (bản copy ở output)
- Loại: file copy sau build.
- Mục đích: cung cấp schema cho runtime init DB ở thư mục chạy app.
- Khi tạo: bước POST_BUILD copy_if_different trong CMakeLists.txt.

## Qt MOC/Autogen files
- Loại: file build trung gian (moc_*.cpp, autogen metadata).
- Mục đích: hỗ trợ meta-object cho QObject, signal/slot, Q_INVOKABLE.
- Khi tạo: tự động bởi Qt/CMake trong mỗi lần build.

## 2) Runtime generated files/folders

## device_network.db
- Loại: SQLite database file.
- Vị trí: applicationDirPath()/device_network.db.
- Mục đích: lưu toàn bộ dữ liệu thiết bị, DHCP và domain liên quan.
- Khi tạo: lần chạy đầu nếu DB chưa tồn tại, trong DatabaseConnection.initializeDatabase().

## backup/
- Loại: thư mục gốc backup.
- Vị trí: applicationDirPath()/backup.
- Mục đích: chứa thư mục con theo host để lưu dữ liệu backup về sau.
- Khi tạo: khi gọi DatabaseManager.createFoldersFromDevices() (thường sau khi thêm thiết bị).

## backup/<host>/
- Loại: thư mục theo host.
- Vị trí: applicationDirPath()/backup/<host>.
- Mục đích: phân vùng dữ liệu backup theo từng thiết bị.
- Khi tạo: BackupService.createFoldersFromHosts().

## script/ (thư mục đích cạnh executable)
- Loại: thư mục đồng bộ runtime.
- Vị trí: applicationDirPath()/script.
- Mục đích: chứa script runtime được sync từ source script folder.
- Khi tạo: startup, bởi ScriptSyncHelper.syncScriptFolder() trong main.cpp.

## script/versionScript.txt (trong thư mục đích)
- Loại: file version của bộ script.
- Mục đích: so sánh version để xác định có cần copy lại script folder.
- Khi tạo: xuất hiện sau khi ScriptSyncHelper copy thư mục script thành công.

## 3) Runtime state/config files (Qt framework)

## QSettings storage
- Loại: file cấu hình do Qt tự quản theo Organization/Application name.
- Mục đích: lưu state cửa sổ (StatefulWindow) và state tab thiết bị (DeviceTabs).
- Khi tạo: runtime, khi lần đầu ghi settings.
- Ghi chú: đường dẫn vật lý phụ thuộc OS và backend của QSettings.

## 4) Các mục không xác nhận là đang tạo trong luồng hiện tại

## versionScript.txt tại root app dir
- Có helper hỗ trợ copy file version riêng (VersionScriptHelper).
- Tuy nhiên trong luồng khởi động hiện tại chưa thấy lời gọi trực tiếp helper này.
- Vì vậy tài liệu ghi nhận là khả năng có hỗ trợ, không xem là file chắc chắn được tạo ở runtime hiện tại.

## Tóm tắt nhanh
- Build-time chắc chắn: executable, file copy data.sql, autogen files của Qt.
- Runtime chắc chắn: device_network.db, backup/, backup/<host>/, script/ (khi sync thành công), QSettings data.

## 5) File QML mới được đóng gói (kể từ refactor Static Routing)

Các file sau được thêm vào `qt_add_qml_module ... QML_FILES` trong `CMakeLists.txt` và được đóng gói vào tài nguyên ứng dụng (`appNetworkUI_raw_qml_0.rcc`) tại build-time:
- `qml/routing/static/StaticRouteRow.qml`
- `qml/routing/static/StaticRoutingDefaultCard.qml`
- `qml/routing/static/StaticRoutingRoutesCard.qml`
- `qml/routing/static/StaticRoutingValidationDialog.qml`
