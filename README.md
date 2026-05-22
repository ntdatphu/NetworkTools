# NetworkTools – Network Management System

![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux-blue)
![Frontend](https://img.shields.io/badge/frontend-Qt%206%20%2B%20QML-green)
![Backend](https://img.shields.io/badge/backend-C%2B%2B%20%2B%20Python%20scripts-yellow)
![Database](https://img.shields.io/badge/database-SQLite-lightgrey)
![Status](https://img.shields.io/badge/status-Development-orange)

## Giới thiệu

**NetworkTools** là dự án xây dựng hệ thống quản lý mạng tập trung, hướng tới phục vụ đề tài nghiên cứu khoa học sinh viên:

> **Nghiên cứu và xây dựng hệ thống quản lý tập trung, tự động hóa cấu hình và giám sát an ninh mạng.**

Ở trạng thái hiện tại, repository tập trung vào việc xây dựng ứng dụng quản lý thiết bị mạng với giao diện Qt/QML, tầng xử lý C++, cơ sở dữ liệu SQLite và một số script Python hỗ trợ khởi tạo dữ liệu/tác vụ hệ thống.

Dự án hướng đến các mục tiêu chính:

- Quản lý tập trung danh sách thiết bị mạng.
- Lưu trữ thông tin thiết bị, cấu hình routing, DHCP và các dữ liệu liên quan bằng SQLite.
- Xây dựng giao diện trực quan để thao tác với thiết bị, routing và DHCP.
- Hỗ trợ các thao tác kiểm thử như ping, cập nhật trạng thái thiết bị và tạo thư mục backup.
- Làm nền tảng để mở rộng sang tự động hóa cấu hình, giám sát trạng thái và cảnh báo an ninh mạng.

## Phạm vi hiện tại

Repository hiện **chưa phải là một hệ thống giám sát an ninh mạng hoàn chỉnh**. Một số chức năng nâng cao vẫn đang ở mức thiết kế, giao diện hoặc định hướng phát triển.

Các phần đã có nền tảng rõ ràng:

- Ứng dụng desktop Qt 6/QML.
- Backend C++ expose dữ liệu và hàm xử lý cho QML thông qua `Q_INVOKABLE` và context properties.
- Cơ sở dữ liệu SQLite được khởi tạo từ `data.sql`.
- Quản lý thiết bị mạng.
- Giao diện Routing, DHCP, Device Management.
- Network monitor cơ bản cho trạng thái mạng/RAM.
- Tài liệu phân tích kiến trúc, QML, database và kế hoạch triển khai routing.

Các phần đang phát triển hoặc cần hoàn thiện:

- Đồng bộ hoàn chỉnh giữa UI Routing và backend.
- Push cấu hình thật xuống thiết bị mạng.
- Giám sát thời gian thực ở mức dịch vụ/thiết bị.
- Cảnh báo bất thường và chức năng an ninh mạng.
- Phân quyền người dùng.
- Hệ thống plugin hoặc hỗ trợ nhiều vendor.

## Kiến trúc tổng quan

```text
User Interface (Qt Quick / QML)
        │
        ▼
C++ Application Layer
        │
        ├── DatabaseManager
        ├── TerminalHelper
        ├── NetworkMonitor
        ├── ScriptSyncHelper
        │
        ▼
SQLite Database + Python Helper Scripts
```

### Luồng khởi động chính

1. `main.cpp` khởi tạo ứng dụng Qt.
2. `ScriptSyncHelper` đồng bộ thư mục script về thư mục chạy ứng dụng.
3. `DatabaseManager` và `DatabaseConnection` mở hoặc tạo SQLite database.
4. Nếu database chưa tồn tại, script Python `script/database/init_db.py` được gọi để khởi tạo schema từ `data.sql`.
5. Các object như `dbManager`, `cli`, `networkMonitor` được inject vào QML.
6. QML load giao diện chính và gọi backend C++ khi cần dữ liệu hoặc thao tác nghiệp vụ.

## Cấu trúc dự án

```text
NetworkTools/
├── frontend/                 # Ứng dụng Qt/QML + C++
│   └── NetworkUI/
│       ├── main.cpp
│       ├── CMakeLists.txt
│       ├── data.sql
│       ├── qml/              # Giao diện QML
│       ├── src/              # Backend C++
│       ├── resources/        # Icon/tài nguyên giao diện
│       └── script/           # Script Python hỗ trợ
│
├── docs/                     # Tài liệu phân tích, kiến trúc, kế hoạch
├── mock/                     # Dữ liệu/kịch bản kiểm thử mẫu
├── report/                   # Báo cáo nghiên cứu khoa học/LaTeX
└── README.md
```

> Lưu ý: tên thư mục và nội dung có thể thay đổi trong quá trình phát triển đề tài.

## Thành phần chính

### Frontend

- **Qt 6 / Qt Quick / QML**: xây dựng giao diện desktop.
- **QML modules**: chia theo layout, sidebar, devices, content, routing, DHCP và shared components.
- **UI hiện có**:
  - Device Management.
  - Routing: Static, OSPF, EIGRP.
  - DHCP Pool và Excluded Address.
  - Logs/Alerts view ở mức giao diện.
  - Settings/Status bar/Navigation.

### Backend C++

- `DatabaseManager`: facade cho QML gọi các chức năng CRUD và nghiệp vụ.
- `DatabaseConnection`: quản lý kết nối SQLite và khởi tạo database.
- `DeviceRepository`, `DhcpPoolRepository`, `ExcludedAddressRepository`: xử lý truy vấn theo domain.
- `BackupService`: tạo cấu trúc thư mục backup theo danh sách host.
- `TerminalHelper`: hỗ trợ mở terminal/ping host từ giao diện.
- `NetworkMonitor`: theo dõi trạng thái mạng và thông tin RAM cơ bản.
- `ScriptSyncHelper`: đồng bộ thư mục script khi chạy ứng dụng.

### Python scripts

Python hiện được dùng như tầng hỗ trợ, không phải backend chính của toàn bộ ứng dụng.

Các script hiện liên quan đến:

- Khởi tạo database từ `data.sql`.
- Hỗ trợ một số tác vụ hệ thống/login theo cấu trúc thư mục `script/`.

### Database

Dự án sử dụng **SQLite** để lưu dữ liệu cục bộ, gồm các nhóm thông tin như:

- Danh sách thiết bị mạng.
- DHCP pool.
- Excluded addresses.
- Routing configuration.
- Thông tin cấu hình liên quan đến thiết bị.

## Tính năng hiện có

- Quản lý danh sách thiết bị mạng.
- Thêm, sửa, xóa thiết bị.
- Cập nhật trạng thái thiết bị trong quá trình kiểm thử.
- Ping thiết bị từ giao diện.
- Quản lý DHCP pool và DHCP excluded address.
- Giao diện cấu hình Static Route.
- Giao diện OSPF/EIGRP ở mức process card/placeholder cho phần push config.
- Theo dõi trạng thái mạng và RAM cơ bản trên status bar.
- Khởi tạo và migration SQLite database cơ bản.
- Tạo thư mục backup theo host.

## Định hướng nghiên cứu

Trong phạm vi đề tài nghiên cứu khoa học, dự án có thể được phát triển theo hướng:

1. **Quản lý tập trung**
   - Xây dựng mô hình quản lý danh sách thiết bị mạng.
   - Lưu trữ thông tin thiết bị, trạng thái và cấu hình liên quan.

2. **Tự động hóa cấu hình**
   - Chuẩn hóa form nhập cấu hình.
   - Sinh cấu hình từ dữ liệu đã nhập.
   - Kiểm thử triển khai cấu hình trên môi trường lab/mô phỏng.

3. **Giám sát và cảnh báo**
   - Theo dõi trạng thái kết nối thiết bị.
   - Ghi nhận log/sự kiện cơ bản.
   - Thiết kế cơ chế cảnh báo cho các tình huống bất thường.

4. **Đánh giá kết quả**
   - So sánh thao tác thủ công và thao tác qua hệ thống.
   - Đánh giá thời gian cấu hình, mức độ giảm lỗi nhập liệu và khả năng quan sát trạng thái hệ thống.

## Tài liệu dự án

### Tiếng Việt

- [Tổng quan dự án](docs/architecture/PROJECT_SUMMARY.md)
- [Cấu trúc dự án](docs/architecture/PROJECT_STRUCTURE.md)
- [Phân tích QML](docs/analysis/QML_ANALYSIS.md)
- [Phân tích Database](docs/analysis/DATA_SQL_ANALYSIS.md)
- [Generated Files](docs/architecture/GENERATED_FILES.md)
- [Routing Backend + UI Plan](docs/plans/ROUTING_BACKEND_PLAN_VI.md)

### English

- [PROJECT_SUMMARY_EN](docs/architecture/PROJECT_SUMMARY_EN.md)
- [PROJECT_STRUCTURE_EN](docs/architecture/PROJECT_STRUCTURE_EN.md)
- [QML_ANALYSIS_EN](docs/analysis/QML_ANALYSIS_EN.md)
- [GENERATED_FILES_EN](docs/architecture/GENERATED_FILES_EN.md)
- [ROUTING_BACKEND_PLAN_EN](docs/plans/ROUTING_BACKEND_PLAN_EN.md)

## Thứ tự đọc đề xuất

1. [PROJECT_SUMMARY](docs/architecture/PROJECT_SUMMARY.md)
2. [PROJECT_STRUCTURE](docs/architecture/PROJECT_STRUCTURE.md)
3. [QML_ANALYSIS](docs/analysis/QML_ANALYSIS.md)
4. [DATA_SQL_ANALYSIS](docs/analysis/DATA_SQL_ANALYSIS.md)
5. [ROUTING_BACKEND_PLAN_VI](docs/plans/ROUTING_BACKEND_PLAN_VI.md)
6. [GENERATED_FILES](docs/architecture/GENERATED_FILES.md)

## Cài đặt và chạy

### Yêu cầu chung

- Qt 6.
- CMake.
- Ninja hoặc build tool tương đương.
- Trình biên dịch C++ phù hợp với Qt.
- Python 3 để chạy các script hỗ trợ.

### Fedora/Linux

```bash
sudo dnf group install c-development
sudo dnf install gcc-c++ cmake ninja-build mesa-libGL-devel python3
```

```bash
cd frontend/NetworkUI
mkdir -p build
cd build

cmake ..
cmake --build .
```

### Windows

Khuyến nghị build bằng **Qt Creator** với Qt 6 kit phù hợp.

Các file quan trọng khi build:

- `frontend/NetworkUI/CMakeLists.txt`
- `frontend/NetworkUI/main.cpp`
- `frontend/NetworkUI/data.sql`
- `frontend/NetworkUI/qml/`
- `frontend/NetworkUI/src/`

## Dữ liệu kiểm thử

Thư mục `mock/` dùng để lưu dữ liệu hoặc kịch bản kiểm thử mẫu cho các chức năng như:

- Thiết bị mạng.
- Routing.
- DHCP.
- Interface/config mẫu.
- Kịch bản phục vụ đánh giá đề tài.

## Roadmap

- [ ] Hoàn thiện đồng bộ Routing UI ↔ Backend.
- [ ] Hoàn thiện luồng sinh và triển khai cấu hình.
- [ ] Bổ sung kịch bản kiểm thử trong môi trường lab.
- [ ] Phát triển chức năng monitoring thời gian thực.
- [ ] Bổ sung logs/alerts cho sự kiện bất thường.
- [ ] Nghiên cứu phân quyền người dùng.
- [ ] Chuẩn hóa báo cáo nghiên cứu trong thư mục `report/`.

## Trạng thái dự án

Dự án đang trong giai đoạn **development**.

Một số module đã có giao diện và cấu trúc dữ liệu, nhưng phần tích hợp backend, triển khai cấu hình thật và giám sát/cảnh báo an ninh vẫn cần tiếp tục hoàn thiện. README này ưu tiên phản ánh đúng hiện trạng repository thay vì mô tả hệ thống như một sản phẩm đã hoàn chỉnh.
