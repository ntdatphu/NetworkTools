# NetworkTools – Hệ thống Quản lý và Tự động hóa Mạng

![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux-blue)
![Frontend](https://img.shields.io/badge/frontend-PyQt6%20%2B%20QML-green)
![Backend](https://img.shields.io/badge/backend-Python%203-yellow)
![Database](https://img.shields.io/badge/database-SQLite-lightgrey)
![Status](https://img.shields.io/badge/status-Development-orange)

## Giới thiệu

**NetworkTools** là một hệ thống quản lý mạng tập trung hiện đại, phục vụ đề tài nghiên cứu khoa học sinh viên:

> **"Nghiên cứu và xây dựng hệ thống quản lý tập trung, tự động hóa cấu hình và giám sát an ninh mạng."**

Dự án được phát triển chuyên sâu nhằm quản trị, giám sát và cấu hình các thiết bị hạ tầng mạng (như Router, Switch của Cisco). Hệ thống tự động hóa quá trình cấu hình bằng cách trừu tượng hóa các dòng lệnh phức tạp, cho phép người dùng thao tác trực quan qua giao diện đồ họa. Từ đó, phần mềm tự sinh các tập tin cấu hình hợp lệ và truyền tải tới thiết bị mạng qua giao thức quản lý từ xa.

## Mục tiêu Dự án

- **Quản lý Tập trung:** Thu thập và kiểm soát thông số của danh sách các thiết bị mạng trên một cổng giao diện duy nhất.
- **Tự động hóa Cấu hình:** Thiết kế giao diện đồ họa (UI/UX) cho phép tinh chỉnh các giao thức mạng phức tạp như DHCP, Định tuyến (Routing), Quản lý Truy cập (ACL) và NAT.
- **Triển khai Trực tiếp (Push config):** Đẩy mã cấu hình từ phần mềm xuống phần cứng mạng thật thông qua SSH/API.
- **Mô phỏng (Dev-mode):** Hỗ trợ test luồng dữ liệu thông qua các cờ giả lập để bảo vệ thiết bị thực tế hoặc cấu hình trước (Pre-config) cấu trúc mạng.
- **Báo cáo Khoa học:** Chuẩn hóa quy trình tạo ra các bài đánh giá khách quan bằng bộ template báo cáo nghiên cứu LaTeX (`latex/`).

## Kiến trúc Hệ thống

Dự án được xây dựng theo mô hình phần mềm phân lớp:

1. **Frontend (Giao diện):** Xây dựng hoàn toàn bằng **QML** và **Qt Quick** mang lại trải nghiệm tương tác mượt mà và linh hoạt.
2. **Bridge (Cầu nối):** Sử dụng thư viện **PyQt6 (Python)** để tiêm các dịch vụ xử lý, truy xuất DB, quản lý hệ điều hành vào QML Engine thông qua Context Properties.
3. **Lưu trữ Cục bộ (Database):** Toàn bộ trạng thái và cấu hình thiết bị đều được lưu trên một cơ sở dữ liệu nội bộ bằng **SQLite**.
4. **Backend Worker (Kịch bản mạng):** Sử dụng các module Python nguyên bản như Netmiko kết hợp Jinja2 Templates để render lệnh cấu hình thành chuỗi logic, nạp qua terminal thiết bị mạng.

## Tài liệu Dự án

Để hỗ trợ các nhà phát triển và người tham gia dự án tra cứu, hiểu rõ chi tiết hoạt động của hệ thống, chúng tôi cung cấp bộ tài liệu hoàn chỉnh. Xin vui lòng tham khảo các tệp tin sau:

- 📖 **[Hướng dẫn Sử dụng (Usage Guide)](docs/USAGE_GUIDE.md):** Hướng dẫn cài đặt thư viện Python, chạy hệ thống và cách thao tác các tính năng mạng cốt lõi.
- 🏗️ **[Kiến trúc Kỹ thuật (Architecture)](docs/ARCHITECTURE.md):** Đặc tả luồng dữ liệu Frontend-Backend, vòng đời component và cấu trúc phân quyền module.
- 📁 **[Cấu trúc Thư mục (Project Structure)](docs/PROJECT_STRUCTURE.md):** Giải thích chi tiết vai trò, nhiệm vụ của từng thư mục, từng tệp tin cốt lõi trong dự án.
- 🎨 **[Giao diện & Thành phần (UI Components)](docs/UI_COMPONENTS.md):** Danh sách các Standard Components, quy tắc Design Tokens (Theme) và cách áp dụng "Họ giao diện" (Interface Families) cho tính năng mới.
- 🗄️ **[Sơ đồ Cơ sở Dữ liệu (Database Schema)](docs/DATABASE_SCHEMA.md):** Giải thích thiết kế hệ thống bảng (Table), cơ chế mô phỏng `dev-mode` nội bộ và liên kết cấu hình thiết bị.

## Báo cáo Đề tài (LaTeX)

Nằm trong định hướng phục vụ báo cáo khoa học, dự án cung cấp mã nguồn báo cáo tại thư mục `latex/`. Mã nguồn được phân chia thành các thư mục trực quan (`chapters/`, `appendix/`), cho phép tự động biên dịch bằng công cụ LaTeX để cho ra tài liệu học thuật theo định dạng tiêu chuẩn.

## Công nghệ sử dụng

- **Ngôn ngữ:** Python 3.10+, QML
- **Frameworks:** PyQt6, Qt 6.8+
- **Thư viện mạng:** Netmiko, NAPALM
- **Database:** SQLite
- **Biên dịch báo cáo:** LaTeX (TexLive/MiKTeX)
