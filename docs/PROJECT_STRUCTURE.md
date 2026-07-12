# Cấu trúc Dự án (Project Structure)

Dự án NetworkTools được tổ chức theo cấu trúc module rõ ràng, phân tách mã nguồn giao diện (Frontend) và logic xử lý (Backend) ra từng phần độc lập để dễ dàng bảo trì và phát triển.

## Cây thư mục chính

```text
NetworkTools/
├── api_server.py
├── app/
├── dgreadiness_v3.6/
├── latex/
├── docs/
└── README.md
```

---

## Chi tiết từng thư mục

### 1. `app/` (Ứng dụng chính)
Đây là thư mục chứa toàn bộ mã nguồn cốt lõi của ứng dụng desktop.

- **`main.py`**: Điểm khởi chạy của ứng dụng. Khởi tạo `QApplication`, cấu hình QML Engine, nạp các thư viện cầu nối (Bridge) và gọi file giao diện chính.
- **`device_network.db`**: File cơ sở dữ liệu SQLite sinh ra trong quá trình chạy, lưu trữ thông tin thiết bị và cấu hình hệ thống.
- **`app/UI/`**: Chứa toàn bộ giao diện Frontend.
  - `qmldir`: Khai báo module UI cho QML.
  - `main_numbered_tables.sql`: File schema định nghĩa cấu trúc của toàn bộ cơ sở dữ liệu hệ thống.
  - `qml/`: Nơi chứa các màn hình và form chức năng (Routing, DHCP, ACL, NAT...).
  - `components/`: Chứa các custom components tái sử dụng (Nút bấm, Input field, Process Card, Dropdown...).
  - `theme/`: Khai báo các Tokens thiết kế (Màu sắc, kích thước, font chữ) và trạng thái giao diện (Sáng/Tối).
  - `resources/`: Chứa assets (Icons, Images) dạng SVG hoặc PNG.
- **`app/core/`**: Cầu nối giao tiếp giữa Python và QML (Middle-layer).
  - `runtime.py`: Khởi tạo môi trường ứng dụng, cung cấp các dịch vụ runtime như TerminalHelper, NetworkMonitor, cài đặt UI.
  - `database.py`: Class `DatabaseManager` là trung tâm của mọi luồng ghi/đọc cơ sở dữ liệu.
  - `*_slots.py` (ví dụ `dhcp_slots.py`, `acl_slots.py`): Các module nhỏ được mixin vào `DatabaseManager` để phân tách logic CRUD của từng giao thức.
  - `database_stubs.py`: Cung cấp các hàm giả lập (stub) cho những module chưa có logic Backend hoàn chỉnh.
- **`app/backend/`**: Chứa các script nghiệp vụ thực sự xử lý định dạng dữ liệu (Normalize), chuẩn hóa trước khi đẩy xuống DB.
  - `dhcp/`: Logic xử lý địa chỉ mạng, helper, exclusions.
  - `route/`: Logic so sánh, gộp bảng định tuyến OSPF/EIGRP.
  - `acl/`, `nat/`: Logic tiền xử lý quy tắc truy cập.
- **`app/network_code/`**: Mã nguồn dùng để tương tác vật lý/logicial với thiết bị mạng.
  - `login/`: Xử lý kết nối SSH, tạo session với thiết bị.
  - `routing/`, `dhcp/`: Kịch bản (Workers) sinh file cấu hình và tiến hành Push/Preview config xuống thiết bị.

### 2. `docs/` (Tài liệu hệ thống)
Chứa các tài liệu dạng Markdown phục vụ cho việc tham khảo, bảo trì và phát triển.
- `ARCHITECTURE.md`: Tài liệu kiến trúc luồng dữ liệu QML-Python.
- `PROJECT_STRUCTURE.md`: (Tài liệu này) Mô tả phân bố thư mục.
- `UI_COMPONENTS.md`: Phân loại và hướng dẫn dùng các components UI.
- `USAGE_GUIDE.md`: Hướng dẫn cài đặt và sử dụng ứng dụng.

### 3. `latex/` (Báo cáo Nghiên cứu)
Chứa mã nguồn báo cáo đề tài nghiên cứu khoa học dưới định dạng LaTeX.
- `main.tex`: File gốc chứa báo cáo tổng.
- `chapters/`: Các chương của báo cáo (Tổng quan, Lý thuyết, Kiến trúc, v.v.).
- `build.ps1`: Script PowerShell để biên dịch nhanh mã LaTeX ra PDF.

### 4. `dgreadiness_v3.6/` (Tools mở rộng)
Chứa công cụ đánh giá Device Guard Readiness phục vụ cho chức năng đánh giá bảo mật của đề tài.

### 5. `api_server.py`
API Server độc lập hỗ trợ tương tác thiết bị từ các nền tảng khác hoặc cho các tác vụ Web-based.
