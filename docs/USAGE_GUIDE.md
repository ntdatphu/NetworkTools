# Hướng Dẫn Cài Đặt và Sử Dụng - NetworkTools

Tài liệu này hướng dẫn cách thiết lập môi trường, chạy ứng dụng NetworkTools (Giao diện PyQt6/QML) và các luồng thao tác cơ bản dành cho người dùng cũng như nhà phát triển.

## 1. Yêu cầu Hệ Thống (Prerequisites)

- Hệ điều hành: Windows, Linux hoặc macOS.
- Trình thông dịch: Python 3.10 trở lên.
- Trình quản lý gói: `uv` (Khuyến nghị dùng Rust-based `uv` để cài đặt thư viện siêu tốc) hoặc dùng `pip` tiêu chuẩn.
- Các phụ thuộc thư viện chính: `PyQt6`, `netmiko`, `napalm`, `jinja2`, `paramiko`.

## 2. Thiết lập Môi trường và Khởi chạy

### Bước 2.1: Clone dự án và di chuyển vào thư mục ứng dụng
Mở Terminal / PowerShell:
```bash
cd NetworkTools/app
```

### Bước 2.2: Đồng bộ thư viện
Nếu bạn đang dùng `uv`:
```bash
uv sync
```
(Nếu dùng pip, hãy đảm bảo khởi tạo virtual environment `python -m venv .venv` và cài thư viện `pip install -r requirements.txt`).

### Bước 2.3: Khởi chạy Ứng dụng
Chạy script chính thông qua Python (hoặc qua `uv run`):
```bash
uv run python main.py
```
> **Lưu ý lần chạy đầu tiên**: Hệ thống sẽ tự động quét thư mục để nạp schema từ `UI/main_numbered_tables.sql` và khởi tạo file cơ sở dữ liệu `device_network.db`. Không tắt ngang ứng dụng trong vài giây đầu.

## 3. Luồng Sử Dụng Các Tính Năng Cơ Bản

### 3.1. Thêm Thiết bị mạng (Device Management)
1. Ở giao diện chính, bấm phím tắt **`Ctrl + N`** hoặc click biểu tượng **Dấu cộng (+)** bên thanh Sidebar.
2. Form **New Device** hiện ra. Nhập:
   - **IP Address**: Địa chỉ IPv4 hợp lệ của Router/Switch.
   - **Device Name**: Tên gợi nhớ.
   - Chọn loại (Router, Switch...)
3. Bấm **Save**. Thiết bị sẽ xuất hiện trong nhóm *Waiting* bên thanh Sidebar.

### 3.2. Kiểm tra Kết Nối & Sync
1. Ở Sidebar, **Chuột phải (Right-click)** vào thiết bị vừa thêm.
2. Chọn **Ping** để gửi gói tin ICMP thăm dò nghiệm thu kết nối (yêu cầu thiết bị bật mạng).
3. Chọn **Connect & Sync**: Tính năng này sẽ mở kết nối SSH vào thiết bị, thu thập cấu hình đang chạy (`running-config`) lưu thành file backup ở máy của bạn, đồng thời kéo các thông tin bảng định tuyến về hệ thống để đồng bộ.

### 3.3. Cấu hình Dịch Vụ (DHCP / Routing / ACL)
1. Tại Content Area (Khu vực lớn giữa màn hình), chọn Tab tính năng tương ứng. Ví dụ: Bấm tab **DHCP**.
2. Phân vùng SubBar hiện ra (Pool, Excluded, Helper). Chọn cấu hình cần làm.
3. Nhập số liệu vào form bên trái (IP Pool, Network, Mask).
4. Bấm **Save**. Dữ liệu lúc này *mới chỉ được lưu vào SQLite nội bộ*, bảng bên phải sẽ load ra số liệu bạn vừa lưu.
5. Để cấu hình thật sự áp dụng xuống thiết bị, ấn nút **Push Config**.
   - Hộp thoại **Preview** sẽ xuất hiện cho phép bạn soát lại mã cấu hình thô.
   - Bấm OK để đẩy thật xuống máy. Thanh trạng thái StatusBar bên dưới cùng sẽ thông báo `Success` hay `Error`.

### 3.4. Chế độ Mô Phỏng (Dev-Mode)
Nếu bạn đang test phần mềm mà không có thiết bị Router thật:
1. Chuột phải vào thiết bị trên thanh Sidebar.
2. Chọn **Up (Dev)**. Thiết bị được chuyển đổi thành cờ giả lập.
3. Giờ đây bạn có thể cấu hình và Push mọi dịch vụ (Routing, ACL...). Hệ thống sẽ giả lập thông báo cấu hình thành công mà không mở SSH tới IP đó.

## 4. Troubleshooting (Gỡ rối)

1. **Lỗi `ModuleNotFoundError`**: Do chưa kích hoạt môi trường ảo (virtualenv) hoặc thiếu thư viện. Hãy kiểm tra lại lệnh `uv sync`.
2. **Push Code thất bại (Authentication Failed)**: Hãy đảm bảo bạn đã cấu hình tên đăng nhập/mật khẩu SSH đúng. (Trong bản Beta, credentials có thể được load cấu hình sẵn trong `login/`).
3. **Database bị lỗi/xung đột schema**: Bạn có thể xoá file `app/device_network.db` và chạy lại ứng dụng để hệ thống tự động sinh lại file trắng mới theo schema mới nhất. Đừng quên backup nếu cần.
