# Kiến trúc Kỹ thuật - NetworkTools

Tài liệu này mô tả chi tiết kiến trúc tổng thể của hệ thống NetworkTools, một ứng dụng desktop quản lý mạng được xây dựng trên nền tảng **Python (PyQt6)** và **QML**.

## 1. Tổng quan Kiến trúc Hệ thống

NetworkTools áp dụng mô hình kiến trúc phân tách rõ ràng giữa giao diện người dùng (Frontend) và logic nghiệp vụ (Backend), giao tiếp qua cầu nối (Bridge) của PyQt6.

```text
[QML Frontend] ← (Context Properties & Signals/Slots) → [Python Backend] ← (SQL) → [SQLite DB]
                                                                ↓
                                                         [Network Scripts]
                                                                ↓
                                                        [Thiết bị Mạng Thật]
```

### 1.1 QML Frontend (Giao diện người dùng)
- **Công nghệ:** Qt Quick / QML.
- **Nhiệm vụ:** Hiển thị giao diện người dùng mượt mà, phản hồi nhanh. Quản lý trạng thái hiển thị, nhận dữ liệu nhập từ người dùng và gọi các hàm (Slots) của Python thông qua các đối tượng được nhúng sẵn (Context Properties).
- **Kiến trúc UI:** Áp dụng hệ thống phân lớp theo "Interface Families" (Họ giao diện) giúp đồng nhất UX/UI trên toàn ứng dụng.

### 1.2 Python Backend & Bridge (Logic & Cầu nối)
- **Công nghệ:** Python 3.10+, PyQt6.
- **Nhiệm vụ:** Xử lý nghiệp vụ, giao tiếp cơ sở dữ liệu, quản lý trạng thái runtime.
- **Cầu nối (Bridge):** Tại `app/main.py`, các service chính được tiêm vào QML Engine:
  - `dbManager`: Đối tượng trung tâm xử lý CRUD dữ liệu và điều phối logic (kế thừa từ `QObject`).
  - `cli`, `networkMonitor`: Quản lý terminal ngoài và monitor thông số hệ thống.

### 1.3 Database (Lưu trữ)
- **Công nghệ:** SQLite.
- **Nhiệm vụ:** Lưu trữ toàn bộ dữ liệu thiết bị, cấu hình mạng (DHCP, Routing, ACL, NAT), cấu hình ứng dụng.
- Cơ sở dữ liệu được tự động sinh ra (`device_network.db`) từ file schema `main_numbered_tables.sql` trong lần chạy đầu tiên.

### 1.4 Network Scripts (Triển khai cấu hình)
- **Công nghệ:** Python (Netmiko, Napalm, v.v.).
- **Nhiệm vụ:** Nhận cấu hình từ Backend, biên dịch template (Jinja2) và kết nối SSH/RESTCONF xuống các thiết bị mạng thực tế để lấy thông tin (Pull) hoặc đẩy cấu hình (Push).

## 2. Luồng Hoạt Động Cốt Lõi (Workflow)

### Khởi chạy Ứng dụng
1. `app/main.py` khởi tạo `QApplication` và `QQmlApplicationEngine`.
2. Hệ thống kiểm tra và khởi tạo SQLite Database nếu chưa có.
3. Khởi tạo các Manager (`DatabaseManager`, `TerminalHelper`, `AppPaths`).
4. Inject các đối tượng này vào QML Context.
5. Engine tải `app/UI/qml/app/Main.qml` và render giao diện.

### Thao tác Dữ liệu (Ví dụ: Thêm DHCP Pool)
1. Người dùng nhập thông tin trên form `DhcpPoolForm.qml`.
2. Khi ấn *Save*, QML gọi hàm: `dbManager.addDhcpPool(...)`.
3. Trong Python, hàm này thuộc `DhcpSlotsMixin`, nó sẽ mở kết nối tới SQLite, thực thi câu lệnh `INSERT` hoặc `UPDATE` và trả về kết quả (dict).
4. Giao diện nhận `result.ok` và hiển thị thông báo qua StatusBar.

### Triển khai cấu hình (Push Code)
1. Người dùng chọn thiết bị, ấn *Push Config*.
2. QML gọi hàm push (ví dụ `network_code/dhcp/worker_dhcp.py`).
3. Dữ liệu thô từ Database được truy xuất, đưa qua hàm sinh cấu hình.
4. (Tuỳ chọn dev-mode): Nếu thiết bị được đánh dấu `dev = 1`, hệ thống bỏ qua bước kết nối SSH thực tế, trả về success mô phỏng. Nếu `dev = 0`, mở SSH thực hiện cấu hình thật.
5. Cập nhật cờ `success = 1` vào Database để báo hiệu cấu hình đã được áp dụng.

## 3. Signal và Slot Pattern

Giao tiếp QML - Python tuân thủ quy tắc nghiêm ngặt:
- **Từ QML gọi Python:** Dùng `@Slot` decorator. Các hàm trả về `QVariant` (Dict/List) hoặc `bool`.
- **Từ Python gọi QML:** Dùng `Signal`. Ví dụ `dataChanged = Signal(str)` kích hoạt sự kiện để QML tự động cập nhật UI.
- **Bên trong QML:** Components con emit signal (ví dụ `saveRequested`), Component cha lắng nghe (ví dụ `onSaveRequested`) và gọi Backend.
