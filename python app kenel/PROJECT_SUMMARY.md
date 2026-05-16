# Tóm tắt dự án: Network Database Manager

## Giới thiệu
Đây là một ứng dụng Command Line Interface (CLI) được viết bằng Python. Ứng dụng này có chức năng chính là quản lý cơ sở dữ liệu mạng SQLite (`device_network.db`) bằng cách tổng hợp và thực thi các file script SQL, đồng thời hỗ trợ đăng nhập vào các thiết bị mạng (ví dụ: switch/router Cisco) thông qua các giao thức mạng.

## Cấu trúc thư mục chính
- `main.py`: File mã nguồn chính, chứa vòng lặp giao diện dòng lệnh (CLI).
- `sql/`: Thư mục chứa các file SQL chia nhỏ có đánh số thứ tự (ví dụ: `01_...sql`, `02_...sql`).
- `login/`: Chứa module đăng nhập thiết bị (`device_connector.py`).
- `device_network.db`: File cơ sở dữ liệu SQLite được hệ thống tự động tạo ra.
- `database_paths.json`: File JSON lưu trữ đường dẫn đến các file dữ liệu quan trọng.

## Các lệnh Input (Commands)
Dưới đây là danh sách các lệnh mà người dùng có thể nhập khi chạy chương trình:

1. **`cre database`**
   - **Chức năng:** Gộp tất cả các file SQL trong thư mục `sql/` lại thành một file duy nhất là `main.sql`, sau đó thực thi file này để tạo mới hoặc cập nhật toàn bộ cấu trúc/dữ liệu cho cơ sở dữ liệu `device_network.db`. Cuối cùng, chương trình sẽ lưu các đường dẫn vào file `database_paths.json`.

2. **`find database`**
   - **Chức năng:** Thực thi file `main.sql` hiện có để cập nhật cơ sở dữ liệu và lưu lại cấu hình đường dẫn.

3. **`login <host> <method> <port> <user> <pass>`**
   - **Chức năng:** Gọi module để kết nối và đăng nhập vào một thiết bị mạng.
   - **Tham số:** 
     - `<host>`: Địa chỉ IP hoặc hostname của thiết bị (VD: `192.168.1.1`).
     - `<method>`: Phương thức kết nối (VD: `ssh`).
     - `<port>`: Cổng kết nối (VD: `22`).
     - `<user>`: Tên đăng nhập.
     - `<pass>`: Mật khẩu.
   - **Ví dụ:** `login 192.168.1.1 ssh 22 admin cisco123`

4. **`info paths`**
   - **Chức năng:** Hiển thị tất cả các đường dẫn hệ thống đang được ứng dụng thiết lập và sử dụng (thư mục làm việc, thư mục chứa SQL, file SQL chính, file database, file cấu hình JSON).

5. **`info json`**
   - **Chức năng:** Đọc và in ra màn hình nội dung của file `database_paths.json`.

6. **`info sql`**
   - **Chức năng:** Liệt kê danh sách các file SQL con đã được tìm thấy trong thư mục `sql/` và trạng thái tồn tại của chúng.

7. **`exit`**
   - **Chức năng:** Thoát khỏi ứng dụng.

> **Mẹo:** Ứng dụng hỗ trợ sử dụng phím mũi tên Lên/Xuống (↑/↓) để gọi lại lịch sử các lệnh đã nhập (nếu hệ thống đã cài đặt module `pyreadline` trên Windows).
