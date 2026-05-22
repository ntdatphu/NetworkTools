# Project Structure

Tài liệu này mô tả cấu trúc hiện tại của repository `NetworkTools` theo source thật trên nhánh `main`.

> Ghi chú: các tài liệu cũ từng nhắc tới `NetworkUI/`, `data.sql`, `script/database/init_db.py` không còn phản ánh đúng cấu trúc hiện tại.

## Cây thư mục chuẩn

```text
NetworkTools/
├── frontend/
│   ├── CMakeLists.txt
│   ├── main.cpp
│   ├── app_icon.rc
│   ├── qml/
│   ├── components/
│   ├── theme/
│   ├── resources/
│   └── src/
│
├── python app kenel/
│   ├── main.py
│   ├── sql/
│   └── ...
│
├── docs/
│   ├── README.md
│   ├── PROJECT_SUMMARY.md
│   ├── PROJECT_STRUCTURE.md
│   ├── GENERATED_FILES.md
│   ├── ROUTING_BACKEND_PLAN_VI.md
│   ├── analysis/
│   └── research/
│
├── mock/
├── report/
└── README.md
```

## `frontend/`

Thư mục `frontend/` là ứng dụng desktop chính.

### File gốc quan trọng

| File/thư mục | Vai trò |
|---|---|
| `frontend/CMakeLists.txt` | Cấu hình build Qt/CMake, khai báo QML module, source C++ và resource |
| `frontend/main.cpp` | Entry point của ứng dụng Qt |
| `frontend/app_icon.rc` | Resource icon cho Windows build |
| `frontend/qml/` | Các màn hình và view theo module chức năng |
| `frontend/components/` | Component QML dùng lại |
| `frontend/theme/` | Theme singleton, UI state và design tokens |
| `frontend/resources/` | Icon và asset UI được đóng gói vào Qt resource |
| `frontend/src/` | Tầng C++ application/data layer |

### QML module

Ứng dụng khai báo QML module:

```cmake
qt_add_qml_module(NetworkTools
    URI NetworkTools
    ...
)
```

Các file QML trong `qml/`, `components/`, `theme/` được liệt kê trực tiếp trong `frontend/CMakeLists.txt`. Vì vậy khi thêm, xóa hoặc di chuyển file QML, cần cập nhật `QML_FILES` tương ứng.

### Nhóm QML chính

| Nhóm | Chức năng |
|---|---|
| `qml/app/` | Cửa sổ chính, state cửa sổ |
| `qml/panels/` | Panel thiết bị, logs/alerts, settings |
| `qml/layout/` | Activity bar, status bar |
| `qml/sidebar/` | Sidebar thiết bị, thêm/sửa thiết bị, YANG config |
| `qml/devices/` | Tab thiết bị |
| `qml/content/` | Điều phối vùng nội dung |
| `qml/interface/` | Giao diện cấu hình interface |
| `qml/routing/` | Static, OSPF, EIGRP |
| `qml/dhcp/` | DHCP pool và excluded address |
| `qml/acl/` | ACL views/forms/rules |
| `qml/nat/` | NAT static/dynamic/PAT/interface/ACL/route-map |
| `qml/shared/` | Toast, notification, resize handles, alert |

## `frontend/src/`

Thư mục này chứa tầng C++ kết nối QML với dữ liệu và tác vụ hệ thống.

| Nhóm | Vai trò |
|---|---|
| `src/database/` | Database manager, connection, repositories |
| `src/database/routing/` | Repositories cho routing |
| `src/database/nat/` | Repositories cho NAT và route-map |
| `src/TerminalHelper.*` | Mở terminal/tác vụ CLI |
| `src/NetworkMonitor.*` | Theo dõi trạng thái mạng/RAM cơ bản |

## `python app kenel/`

Thư mục này là Python runtime/helper hiện tại của dự án.

`frontend/CMakeLists.txt` copy thư mục này sang output với tên:

```text
python_app_kenel/
```

Tên `kenel` có vẻ là lỗi chính tả của `kernel`, nhưng hiện source đang phụ thuộc vào tên này. Không nên đổi tên nếu chưa sửa đồng thời:

- `frontend/CMakeLists.txt`
- `frontend/src/database/DatabaseConnection.cpp`
- mọi script hoặc tài liệu build/runtime liên quan

## `docs/`

Tài liệu được chuẩn hóa theo cấu trúc:

```text
docs/
├── README.md
├── PROJECT_SUMMARY.md
├── PROJECT_STRUCTURE.md
├── GENERATED_FILES.md
├── ROUTING_BACKEND_PLAN_VI.md
├── PROJECT_SUMMARY_EN.md
├── PROJECT_STRUCTURE_EN.md
├── GENERATED_FILES_EN.md
├── ROUTING_BACKEND_PLAN_EN.md
├── analysis/
│   ├── QML_ANALYSIS.md
│   └── DATA_SQL_ANALYSIS.md
└── research/
    ├── RESEARCH_SCOPE.md
    ├── TEST_SCENARIOS.md
    └── EVALUATION_CRITERIA.md
```

## Path nhạy cảm

Không nên di chuyển hoặc đổi tên các path sau nếu chưa sửa source/build:

| Path | Lý do |
|---|---|
| `frontend/` | Là project Qt/CMake chính |
| `frontend/CMakeLists.txt` | Liệt kê trực tiếp source, QML, resource |
| `frontend/qml/` | Được khai báo trong `qt_add_qml_module` |
| `frontend/components/` | Được khai báo trong `qt_add_qml_module` |
| `frontend/theme/` | Chứa QML singleton và tokens |
| `frontend/resources/` | Dùng bởi resource path trong QML/C++ |
| `python app kenel/` | Được CMake copy sang output |
| `python app kenel/main.py` | Được gọi khi khởi tạo database mới |
| `python app kenel/sql/main.sql` | Schema database runtime |

## Quy tắc khi thêm file mới

- Thêm QML mới: cập nhật `frontend/CMakeLists.txt` trong `QML_FILES`.
- Thêm resource mới: cập nhật `RESOURCES` trong `frontend/CMakeLists.txt`.
- Thêm source C++ mới: cập nhật `SOURCES` trong `frontend/CMakeLists.txt`.
- Thêm bảng SQL mới: cập nhật SQL trong `python app kenel/sql/` và đảm bảo `main.sql` phản ánh schema cần dùng.
- Thêm tài liệu nghiên cứu: ưu tiên đặt trong `docs/research/`.
