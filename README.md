# NetworkTools – Network Management System

![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux-blue)
![Frontend](https://img.shields.io/badge/frontend-Qt%206%20%2B%20QML-green)
![Backend](https://img.shields.io/badge/backend-C%2B%2B%20%2B%20Python%20scripts-yellow)
![Database](https://img.shields.io/badge/database-SQLite-lightgrey)
![Status](https://img.shields.io/badge/status-Development-orange)

## Giới thiệu

**NetworkTools** là dự án xây dựng hệ thống quản lý mạng tập trung, hướng tới phục vụ đề tài nghiên cứu khoa học sinh viên:

> **Nghiên cứu và xây dựng hệ thống quản lý tập trung, tự động hóa cấu hình và giám sát an ninh mạng.**

Repository hiện được tổ chức theo hai phần chính:

- `frontend/`: ứng dụng desktop xây dựng bằng Qt 6, QML và C++.
- `backend/`: tài nguyên backend/runtime, script hỗ trợ và schema SQL dùng khi ứng dụng khởi tạo cơ sở dữ liệu.

Dự án tập trung vào việc xây dựng nền tảng quản lý thiết bị mạng, lưu trữ cấu hình, thao tác với các chức năng mạng phổ biến và mở rộng dần sang tự động hóa cấu hình, giám sát trạng thái và cảnh báo sự kiện.

## Mục tiêu

- Quản lý tập trung danh sách thiết bị mạng.
- Lưu trữ dữ liệu thiết bị, DHCP, routing, NAT, ACL và các cấu hình liên quan bằng SQLite.
- Xây dựng giao diện desktop trực quan bằng Qt/QML.
- Kết nối giao diện QML với tầng xử lý C++ thông qua context properties và `Q_INVOKABLE`.
- Chuẩn bị nền tảng để mở rộng sang triển khai cấu hình, giám sát trạng thái và cảnh báo bất thường.

## Phạm vi hiện tại

Dự án đang trong giai đoạn **development**. Một số chức năng đã có giao diện và tầng dữ liệu, nhưng phần triển khai cấu hình thật xuống thiết bị, giám sát an ninh đầy đủ và cảnh báo nâng cao vẫn cần tiếp tục hoàn thiện.

Các phần đã có nền tảng rõ ràng:

- Ứng dụng desktop Qt 6/QML.
- QML module `NetworkTools`.
- Backend C++ cho tầng dữ liệu và xử lý nghiệp vụ.
- SQLite database cục bộ.
- SQLite amalgamation được build trực tiếp cùng ứng dụng.
- Giao diện quản lý thiết bị, routing, DHCP, ACL, NAT và một số panel hệ thống.
- Backend/runtime resources được copy từ `backend/` sang thư mục output khi build.

Các phần đang phát triển hoặc cần hoàn thiện:

- Đồng bộ hoàn chỉnh giữa UI và backend cho toàn bộ module cấu hình.
- Sinh và triển khai cấu hình thật xuống thiết bị mạng.
- Monitoring thời gian thực ở mức thiết bị/dịch vụ.
- Logs, alerts và phát hiện bất thường an ninh.
- Kịch bản kiểm thử và đánh giá phục vụ báo cáo nghiên cứu khoa học.
- Tài liệu kỹ thuật mới phản ánh đúng source hiện tại.

## Kiến trúc tổng quan

```text
NetworkTools/
│
├── frontend/                         # Qt/QML + C++ desktop application
│   ├── CMakeLists.txt
│   ├── main.cpp
│   ├── app_icon.rc
│   ├── qml/                          # Application screens and feature views
│   ├── components/                   # Reusable QML components
│   ├── theme/                        # Theme singleton and design tokens
│   ├── resources/                    # Icons and UI assets
│   └── src/                          # C++ application/data layer
│
├── backend/                          # Backend/runtime resources
│   ├── sql/                          # SQL schema files
│   │   └── main.sql
│   ├── setup_venv.bat
│   ├── setup_venv.sh
│   └── packages.txt
│
├── docs/                             # Project documentation
├── mock/                             # Mock/test data if needed
├── report/                           # Research report materials
└── README.md
```

## Luồng hoạt động chính

```text
QML UI
  │
  ▼
C++ application layer
  │
  ├── DatabaseManager
  ├── DatabaseConnection
  ├── TerminalHelper
  └── NetworkMonitor
  │
  ▼
SQLite database
  │
  ▼
backend/sql/main.sql
```

Luồng khởi động cơ bản:

1. `frontend/main.cpp` khởi tạo ứng dụng Qt.
2. Ứng dụng tạo `DatabaseManager`, `TerminalHelper`, `NetworkMonitor`.
3. Các object này được inject vào QML thông qua context properties: `dbManager`, `cli`, `networkMonitor`.
4. QML được load bằng `engine.loadFromModule("NetworkTools", "Main")`.
5. `DatabaseConnection` mở hoặc tạo file `device_network.db` trong thư mục chạy ứng dụng.
6. Nếu database chưa tồn tại, schema được đọc từ `backend/sql/main.sql` trong thư mục output.
7. SQLite database được khởi tạo trực tiếp bằng SQLite amalgamation, không cần Python interpreter cho bước tạo DB.

## Frontend

Frontend nằm trong thư mục:

```text
frontend/
```

Công nghệ chính:

- Qt 6.
- Qt Quick/QML.
- C++.
- CMake.
- SQLite amalgamation.

Một số nhóm thư mục quan trọng:

```text
frontend/qml/          # Màn hình và module tính năng
frontend/components/   # Component QML dùng lại
frontend/theme/        # Theme, state, token màu/kích thước/chữ/chuyển động
frontend/resources/    # Icon và tài nguyên UI
frontend/src/          # C++ source
```

Các nhóm giao diện chính hiện có:

- Device management.
- Routing.
- DHCP.
- ACL.
- NAT.
- Logs/Alerts panel.
- Settings panel.
- Sidebar, activity bar, status bar và notification UI.

## Backend/runtime resources

Backend/runtime resources nằm trong thư mục:

```text
backend/
```

Khi build, `frontend/CMakeLists.txt` copy thư mục `backend/` sang thư mục output của executable:

```text
<build-output>/bin/backend/
```

Database runtime hiện phụ thuộc vào file:

```text
backend/sql/main.sql
```

Vì vậy không nên đổi tên hoặc di chuyển `backend/` và `backend/sql/main.sql` nếu chưa cập nhật lại `frontend/CMakeLists.txt` và logic trong `DatabaseConnection.cpp`.

## Database

Dự án sử dụng SQLite để lưu dữ liệu cục bộ.

Database runtime:

```text
<applicationDirPath>/device_network.db
```

Schema khởi tạo:

```text
<applicationDirPath>/backend/sql/main.sql
```

Các nhóm dữ liệu có thể bao gồm:

- Devices.
- DHCP.
- Static routing.
- OSPF.
- EIGRP.
- ACL.
- NAT.
- YANG/RESTCONF-related configuration.

## Build và chạy

### Yêu cầu chung

- Qt 6.8 hoặc mới hơn.
- CMake 3.16 hoặc mới hơn.
- Trình biên dịch C/C++.
- Ninja hoặc build tool tương đương.
- Python nếu cần chạy các script hỗ trợ trong `backend/`.

### Fedora/Linux

```bash
sudo dnf group install c-development
sudo dnf install gcc-c++ cmake ninja-build mesa-libGL-devel python3
```

```bash
cd frontend
mkdir -p build
cd build

cmake ..
cmake --build .
```

### Windows

Khuyến nghị build bằng Qt Creator với Qt 6.8+ kit phù hợp.

Các file/thư mục quan trọng khi build:

```text
frontend/CMakeLists.txt
frontend/main.cpp
frontend/qml/
frontend/components/
frontend/theme/
frontend/resources/
frontend/src/
backend/
backend/sql/main.sql
```

## Những path nhạy cảm

Không nên đổi vị trí các path sau nếu chưa sửa build/runtime logic:

| Path | Lý do |
|---|---|
| `frontend/` | Chứa `CMakeLists.txt`, source C++, QML module và resource |
| `backend/` | Được `frontend/CMakeLists.txt` copy sang output bằng đường dẫn `../backend` |
| `backend/sql/main.sql` | Được `DatabaseConnection.cpp` dùng để khởi tạo database |
| `frontend/qml/` | Các file QML được liệt kê trong `qt_add_qml_module` |
| `frontend/components/` | Component QML dùng lại, cũng được liệt kê trong CMake |
| `frontend/theme/` | Chứa QML singleton/theme tokens |
| `frontend/resources/` | Resource path được dùng trong QML/C++ dạng `qrc:/qt/qml/NetworkTools/resources/...` hoặc `:/qt/qml/NetworkTools/resources/...` |

## Định hướng nghiên cứu

Trong phạm vi đề tài nghiên cứu khoa học, dự án có thể được phát triển theo bốn hướng chính:

1. **Quản lý tập trung**
   - Quản lý danh sách thiết bị mạng.
   - Lưu trữ thông tin trạng thái và cấu hình liên quan.

2. **Tự động hóa cấu hình**
   - Chuẩn hóa form nhập cấu hình.
   - Sinh cấu hình từ dữ liệu đã nhập.
   - Triển khai hoặc mô phỏng triển khai cấu hình trên môi trường lab.

3. **Giám sát và cảnh báo**
   - Theo dõi trạng thái kết nối.
   - Ghi nhận log/sự kiện.
   - Thiết kế cơ chế cảnh báo cho tình huống bất thường.

4. **Đánh giá kết quả**
   - So sánh thao tác thủ công và thao tác qua hệ thống.
   - Đánh giá thời gian cấu hình, khả năng giảm lỗi nhập liệu và khả năng quan sát trạng thái hệ thống.

## Roadmap

- [ ] Chuẩn hóa lại tài liệu trong `docs/` theo source hiện tại.
- [ ] Hoàn thiện đồng bộ UI ↔ backend cho các module cấu hình.
- [ ] Hoàn thiện luồng sinh cấu hình.
- [ ] Bổ sung kịch bản kiểm thử trong môi trường lab.
- [ ] Phát triển monitoring/logs/alerts.
- [ ] Bổ sung tiêu chí đánh giá phục vụ báo cáo nghiên cứu khoa học.
- [ ] Chuẩn hóa báo cáo trong `report/`.

## Ghi chú

Một số file Markdown trong `docs/` có thể vẫn đang phản ánh cấu trúc cũ của dự án. Khi cần đánh giá cấu trúc hiện tại, ưu tiên đối chiếu với source thực tế trong `frontend/`, `backend/` và `frontend/CMakeLists.txt`.
