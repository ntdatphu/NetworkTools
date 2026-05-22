# Generated Files

Tài liệu này liệt kê các file/thư mục được tạo hoặc copy trong quá trình build/runtime theo source hiện tại trên nhánh `main`.

## Build-time copied/generated

### `NetworkTools` executable

- Loại: binary output.
- Tạo bởi: CMake target `NetworkTools`.
- Vị trí runtime theo cấu hình hiện tại:

```text
frontend/build/bin/NetworkTools
```

hoặc tương đương tùy build directory/platform.

### Qt generated/autogen files

- Loại: file build trung gian.
- Ví dụ: MOC files, autogen metadata, QML cache/resource artifacts.
- Tạo bởi: Qt/CMake.
- Không commit vào repository.

### Qt resource/QML module artifacts

- Loại: file build trung gian phục vụ QML module `NetworkTools`.
- Nguồn: `QML_FILES` và `RESOURCES` trong `frontend/CMakeLists.txt`.
- Không commit vào repository.

### `python_app_kenel/`

- Loại: thư mục copy sau build.
- Nguồn:

```text
python app kenel/
```

- Đích:

```text
<TARGET_FILE_DIR:NetworkTools>/python_app_kenel/
```

- Tạo bởi: `add_custom_command(... POST_BUILD ...)` trong `frontend/CMakeLists.txt`.
- Vai trò: chứa Python helper/runtime và SQL schema phục vụ khởi tạo database.

> Lưu ý: `kenel` có vẻ là lỗi chính tả, nhưng hiện source đang dùng tên này. Không đổi tên nếu chưa sửa đồng bộ CMake và C++ runtime path.

## Runtime generated files/folders

### `device_network.db`

- Loại: SQLite database.
- Vị trí:

```text
<applicationDirPath>/device_network.db
```

- Khi tạo: lần chạy đầu nếu file database chưa tồn tại.
- Cơ chế tạo: `DatabaseConnection.cpp` gọi Python app kernel để chạy `main.py --init-db` với `sql/main.sql`.

### `python_app_kenel/database_paths.json`

- Loại: file JSON runtime/helper.
- Có thể được tạo bởi Python app kernel khi chạy chức năng lưu path.
- Vị trí phụ thuộc vào thư mục làm việc của Python app kernel.

### SQLite WAL/SHM files

Do SQL schema bật WAL mode, SQLite có thể tạo thêm:

```text
device_network.db-wal
device_network.db-shm
```

Các file này là runtime database files, không commit vào repository.

### QSettings storage

- Loại: file/cơ chế lưu cấu hình do Qt quản lý.
- Nội dung có thể gồm trạng thái cửa sổ, UI state hoặc preference.
- Vị trí phụ thuộc hệ điều hành và cấu hình Qt.

## File/thư mục không nên commit

```text
frontend/build/
*.db
*.db-wal
*.db-shm
CMakeFiles/
CMakeCache.txt
cmake_install.cmake
*.user
```

## File/thư mục cần commit

```text
frontend/CMakeLists.txt
frontend/main.cpp
frontend/qml/
frontend/components/
frontend/theme/
frontend/resources/
frontend/src/
python app kenel/main.py
python app kenel/sql/
docs/
report/
README.md
```

## Ghi chú cập nhật

Khi thay đổi build/runtime path, cần cập nhật tài liệu này cùng với:

- `README.md`
- `docs/PROJECT_SUMMARY.md`
- `docs/PROJECT_STRUCTURE.md`
