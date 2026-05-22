# Project Summary

## Mục đích

**NetworkTools** là ứng dụng desktop phục vụ quản lý thiết bị mạng, lưu trữ cấu hình và làm nền tảng cho đề tài nghiên cứu khoa học:

> Nghiên cứu và xây dựng hệ thống quản lý tập trung, tự động hóa cấu hình và giám sát an ninh mạng.

Tài liệu này mô tả tổng quan hệ thống theo source hiện tại trên nhánh `main`.

## Kiến trúc tổng thể

```text
QML UI
  │
  ▼
C++ application/data layer
  │
  ├── DatabaseManager
  ├── DatabaseConnection
  ├── Repository classes
  ├── TerminalHelper
  └── NetworkMonitor
  │
  ▼
SQLite database
  │
  ▼
Python app kernel + SQL schema
```

## Thành phần chính

### 1. Frontend Qt/QML

Thư mục:

```text
frontend/
```

Vai trò:

- Cung cấp giao diện desktop.
- Tổ chức các màn hình theo module: devices, interface, routing, DHCP, ACL, NAT, logs/alerts, settings.
- Dùng QML module `NetworkTools`.
- Dùng component và theme dùng lại trong `components/` và `theme/`.

### 2. C++ application layer

Thư mục:

```text
frontend/src/
```

Vai trò:

- Expose object C++ sang QML.
- Quản lý kết nối SQLite.
- Cung cấp repository theo domain.
- Xử lý tác vụ terminal và network monitor.

Các object chính được QML sử dụng:

| Object | Vai trò |
|---|---|
| `dbManager` | Facade cho QML gọi database/repository logic |
| `cli` | Hỗ trợ mở terminal/tác vụ CLI |
| `networkMonitor` | Cung cấp trạng thái mạng và thông tin runtime cơ bản |

### 3. Python app kernel

Thư mục gốc hiện tại:

```text
python app kenel/
```

Thư mục này được CMake copy sang output với tên:

```text
python_app_kenel/
```

Vai trò:

- Chứa `main.py`.
- Chứa SQL schema trong `sql/`.
- Hỗ trợ khởi tạo database mới.
- Có thể hỗ trợ các tác vụ Python khác như login/kết nối thiết bị.

> Lưu ý: tên `kenel` có vẻ là lỗi chính tả của `kernel`, nhưng hiện source đang dùng đúng tên này. Không đổi tên nếu chưa sửa đồng bộ source/build.

### 4. SQLite database

Database runtime:

```text
<applicationDirPath>/device_network.db
```

Khi database chưa tồn tại, `DatabaseConnection.cpp` gọi Python app kernel để khởi tạo database từ:

```text
<applicationDirPath>/python_app_kenel/sql/main.sql
```

## Luồng khởi động

1. `frontend/main.cpp` khởi tạo `QApplication`.
2. Thiết lập metadata ứng dụng: organization, domain, application name.
3. Thiết lập icon từ Qt resource.
4. Tạo `DatabaseManager` và gọi `initializeDatabase()`.
5. Tạo `TerminalHelper` và `NetworkMonitor`.
6. Inject các context properties vào QML:
   - `dbManager`
   - `cli`
   - `networkMonitor`
7. Load QML module:

```cpp
engine.loadFromModule("NetworkTools", "Main");
```

## Luồng khởi tạo database

1. `DatabaseConnection` xác định database path:

```text
applicationDirPath()/device_network.db
```

2. Nếu database chưa tồn tại, gọi Python initializer.
3. Python initializer chạy `main.py` với tham số:

```text
--init-db --sql <main.sql> --db <device_network.db>
```

4. Sau khi database được tạo, Qt mở database bằng `QSQLITE`.
5. Bật `PRAGMA foreign_keys = ON`.
6. Thực hiện một số bước migration/ensure table/ensure column cho database cũ.

## Các module chức năng chính

| Module | Trạng thái tổng quát |
|---|---|
| Devices | Có UI và repository/data layer |
| Interface | Có UI và repository tương ứng |
| DHCP | Có UI và repository/data layer |
| Routing | Có Static, OSPF, EIGRP UI và repository |
| ACL | Có nhiều form/rule type trong QML |
| NAT | Có UI cho Static, Dynamic, PAT, Interface, ACL, Route Map |
| Logs/Alerts | Có panel UI, cần hoàn thiện logic giám sát/cảnh báo |
| Settings | Có panel UI |

## Phạm vi nghiên cứu

Trong đề tài nghiên cứu khoa học, dự án nên được trình bày theo 4 nhóm nội dung:

1. **Quản lý tập trung**
   - Quản lý thiết bị mạng.
   - Lưu trữ thông tin thiết bị và cấu hình theo host.

2. **Tự động hóa cấu hình**
   - Chuẩn hóa form nhập cấu hình.
   - Lưu cấu hình theo domain: interface, routing, DHCP, ACL, NAT.
   - Hướng tới sinh/triển khai cấu hình tự động.

3. **Giám sát và cảnh báo**
   - Theo dõi trạng thái kết nối.
   - Thiết kế logs/alerts.
   - Mở rộng sang phát hiện bất thường.

4. **Đánh giá hệ thống**
   - So sánh thao tác thủ công và thao tác qua hệ thống.
   - Đánh giá khả năng giảm lỗi nhập liệu.
   - Đánh giá khả năng quan sát trạng thái và quản lý tập trung.

## Ghi chú bảo trì tài liệu

- Source thật là nguồn ưu tiên cao nhất.
- Khi CMake, path runtime hoặc schema thay đổi, cần cập nhật đồng thời:
  - `README.md`
  - `docs/PROJECT_SUMMARY.md`
  - `docs/PROJECT_STRUCTURE.md`
  - `docs/GENERATED_FILES.md`
  - tài liệu trong `docs/analysis/` nếu liên quan.
