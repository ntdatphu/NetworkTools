<!-- markdownlint-disable MD033 MD041 -->
[English](README.en.md) | [Tiếng Việt](README.md)
<div align="center">
  <img src="app/UI/resources/brand/logo_readme.svg" alt="NetworkTools logo" width="144">

  <img src="app/UI/resources/brand/name.svg" alt="NetworkTools name">

  <p><strong>Nền tảng desktop quản lý, cấu hình và giám sát thiết bị mạng tập trung.</strong></p>

  <p>
    <img alt="Python" src="https://img.shields.io/badge/Python-%E2%89%A53.11-3776AB?logo=python&logoColor=white">
    <img alt="PyQt6" src="https://img.shields.io/badge/UI-PyQt6%20%2B%20QML-41CD52?logo=qt&logoColor=white">
    <img alt="SQLite" src="https://img.shields.io/badge/Database-SQLite-003B57?logo=sqlite&logoColor=white">
    <img alt="Status" src="https://img.shields.io/badge/Status-Development-F59E0B">
  </p>
</div>

<img src="app/UI/resources/brand/stats-dark.svg" alt="stats-dark">

## Tổng quan

NetworkTools cung cấp một giao diện thống nhất để quản lý inventory, theo dõi trạng thái và xây dựng cấu hình cho router, switch cùng các dịch vụ mạng. Ứng dụng kết hợp giao diện Qt Quick/QML với backend Python, lưu dữ liệu cục bộ bằng SQLite và giao tiếp với thiết bị qua SSH.

Dự án được phát triển trong khuôn khổ nghiên cứu:

> Nghiên cứu và xây dựng hệ thống quản lý tập trung, tự động hóa cấu hình và giám sát an ninh mạng.

## Tính năng chính

| Nhóm tính năng | Khả năng |
| --- | --- |
| Quản lý thiết bị | Thêm, sửa, xóa, nhập hàng loạt, ping, kết nối/đồng bộ đồng thời nhiều host |
| Cấu hình mạng | DHCP, ACL, NAT, Router Interface View & Push, static route, OSPF và EIGRP |
| Switching | Quản lý switchport, VLAN, SVI/L3, theo dõi switch và View & Push Layer 2 Cisco IOS |
| Terminal & phiên kết nối | Mở CLI, quản lý vòng đời session và chạy lệnh trên thiết bị |
| Sao lưu cấu hình | Lưu lịch sử running-config theo thiết bị bằng Dulwich |
| System Logs | Nhận, lọc và lưu Syslog qua UDP/TCP |
| Device Logs | Bắt và phân tích lưu lượng với TShark trong môi trường được cấp quyền |
| SFTP | Duyệt file, upload/download và theo dõi hàng đợi truyền file |
| Công cụ ngoài | Tích hợp SSH client, terminal và trình duyệt SQLite trên máy người dùng |
| Báo cáo | Mã nguồn và quy trình biên dịch báo cáo khoa học bằng LaTeX |

> Một số luồng cấu hình phụ thuộc vendor, protocol và thiết bị lab. Luôn xem trước lệnh và thử nghiệm trong dev-mode trước khi đẩy cấu hình lên thiết bị thật.

## Yêu cầu hệ thống

- Python **3.11 trở lên**;
- [`uv`](https://docs.astral.sh/uv/) để quản lý môi trường và dependency;
- Windows là nền tảng phát triển chính; Linux cần có đầy đủ thư viện Qt tương ứng;
- TShark/Wireshark nếu sử dụng tính năng Device Logs;
- TeX Live hoặc MiKTeX nếu biên dịch báo cáo LaTeX;
- quyền truy cập hợp lệ tới thiết bị mạng khi sử dụng kết nối thật.

## Cài đặt nhanh

### 1. Lấy mã nguồn

```bash
git clone https://github.com/ntdatphu/NetworkTools.git
cd NetworkTools/app
```

### 2. Chạy ứng dụng

```bash
uv run main.py
```

Đây là lệnh duy nhất cần chạy. `uv` tự tạo môi trường từ `app/pyproject.toml` và `app/uv.lock`; ứng dụng tự tạo database mới hoặc bổ sung object schema còn thiếu mà không xóa dữ liệu hiện có. Dữ liệu runtime mặc định nằm trong `app/data/`; có thể đặt biến môi trường `NETWORKTOOLS_DATA_DIR` để sử dụng vị trí khác.

## Hướng dẫn sử dụng

### Thêm và kết nối thiết bị

1. Mở khu vực **Devices** và chọn **Add Device** hoặc nhấn `Ctrl+N`.
2. Nhập địa chỉ host, protocol, port, tài khoản đăng nhập, hệ điều hành và vai trò thiết bị.
3. Lưu thiết bị; trạng thái ban đầu là `Waiting`/`Pending`.
4. Mở menu ngữ cảnh của thiết bị để **Ping**, **Connect**, **Reconnect**, xem **Running Config** hoặc mở **CLI**.
   Có thể chọn **Connect All Waiting** từ menu nhóm để chạy các kết nối host độc
   lập và đồng thời.
5. Chỉ lưu credential dùng cho môi trường lab và không commit database runtime lên Git.

### Thử nghiệm bằng dev-mode

1. Thêm một thiết bị giả với thông tin lab.
2. Khi thiết bị ở trạng thái `Waiting`, chọn **Up (Dev)**.
3. Tạo hoặc chỉnh sửa cấu hình cục bộ.
4. Dùng **View & Push** để xem trước kết quả trước khi thực hiện trên thiết bị thật.

Dev-mode hiện phù hợp nhất với Routing và DHCP; không nên xem đây là lớp bảo vệ duy nhất cho mọi tính năng.

### Tạo và triển khai cấu hình

1. Chọn thiết bị đang hoạt động.
2. Mở feature cần cấu hình: Routing, DHCP, ACL, NAT, Interface hoặc Switching.
3. Nhập dữ liệu và lưu cấu hình cục bộ.
4. Kiểm tra phần preview, host đích, vendor và protocol.
5. Sao lưu running-config trước khi chọn **Push**.
6. Theo dõi trạng thái tác vụ và kiểm tra lại cấu hình trên thiết bị sau khi hoàn tất.

Switch Layer 2 dùng cùng luồng View & Push cho VLAN, switch port/EtherChannel,
STP, VTP và L2 Security qua SSH/Telnet. App chỉ đánh dấu từng module đã đồng bộ
sau khi thiết bị chấp nhận lệnh. Xem giới hạn an toàn tại
[`app/features/switching/INTEGRATION_LIMITATIONS.md`](app/features/switching/INTEGRATION_LIMITATIONS.md).

Router Interface View & Push hỗ trợ Cisco IOS qua SSH/Telnet cho cấu hình địa chỉ
IPv4, secondary IP, L3 tuning, WAN và Tunnel. Preview che mật khẩu PPP và app chỉ
đánh dấu row đã áp dụng sau khi thiết bị chấp nhận batch lệnh. RESTCONF/NETCONF,
IPv6, verify và rollback tự động chưa được tích hợp; xem chi tiết tại
[`app/features/interfaces/README.md`](app/features/interfaces/README.md).

### Syslog, Device Logs và SFTP

- **System Logs:** cấu hình listener trong **Settings → System Logs**, xác thực bind address/port rồi khởi động listener từ Activity Bar.
- **Device Logs:** chọn capture interface và filter trước khi bắt gói; chỉ sử dụng trên mạng mà bạn được phép giám sát.
- **SFTP:** xác minh fingerprint SHA-256 của máy chủ trước khi chấp nhận kết nối và truyền file.

Hướng dẫn chi tiết cho từng màn hình nằm trong [docs/USAGE_GUIDE.md](docs/USAGE_GUIDE.md). Danh sách phím tắt nằm tại [docs/SHORTCUTS.md](docs/SHORTCUTS.md).

## Kiến trúc

```text
QML / Qt Quick
      │
      ▼
Core facade & context properties
      │
      ▼
Feature services / repositories / workers
      │
      ├── SQLite
      └── Network adapters ──► Thiết bị
```

| Đường dẫn | Vai trò |
| --- | --- |
| `app/UI/` | Module QML, layout, component, theme và tài nguyên giao diện |
| `app/core/` | Facade và contract dùng chung giữa Python với QML |
| `app/features/` | Nghiệp vụ được tổ chức theo từng tính năng |
| `app/infrastructure/` | Adapter cơ sở dữ liệu, hệ thống và kết nối mạng |
| `app/scripts/` | Công cụ build database và kiểm tra cấu trúc |
| `app/tests/` | Unit, integration và QML smoke tests |
| `backend/` | Worker và mã tích hợp mạng đang tiếp tục được chuẩn hóa |
| `docs/` | Tài liệu sử dụng, kiến trúc và quy ước kỹ thuật |
| `latex/` | Mã nguồn báo cáo nghiên cứu |

Đọc thêm tại [Kiến trúc hệ thống](docs/ARCHITECTURE.md) và [Cấu trúc dự án](docs/PROJECT_STRUCTURE.md).

## Kiểm thử và kiểm tra chất lượng

Chạy các lệnh sau từ thư mục `app/`:

```bash
uv run python scripts/validate_structure.py
uv run python -m compileall .
uv run python -m unittest discover -s tests -v
```

Database runtime, log, cache, credential, private key và backup cục bộ không được đưa vào commit.

## Biên dịch báo cáo LaTeX

Trên PowerShell:

```powershell
cd latex
.\build.ps1
```

Dọn các file trung gian:

```powershell
.\build.ps1 -Clean
```

## Tài liệu

- [Hướng dẫn sử dụng](docs/USAGE_GUIDE.md)
- [Kiến trúc kỹ thuật](docs/ARCHITECTURE.md)
- [Cấu trúc thư mục](docs/PROJECT_STRUCTURE.md)
- [Cơ sở dữ liệu](docs/DATABASE_SCHEMA.md)
- [Thành phần giao diện](docs/UI_COMPONENTS.md)
- [System Logs](docs/SYSTEM_LOGS.md)
- [Phím tắt](docs/SHORTCUTS.md)
- [Báo cáo kiểm tra mã nguồn](docs/CODE_AUDIT.md)
- [Changelog](CHANGELOG.md)
- [Roadmap](ROADMAP.md)
- [Hướng dẫn đóng góp](CONTRIBUTING.md)
- [Quy tắc lập trình](docs/CODING_STANDARDS.md)
- [Tác giả và thành viên nghiên cứu](AUTHORS.md)

## An toàn vận hành

- Chỉ kết nối, bắt gói và thay đổi cấu hình trên hệ thống mà bạn được cấp quyền.
- Không đặt mật khẩu trong command-line argument, log, ảnh chụp hoặc commit.
- Luôn sao lưu cấu hình và database trước khi rebuild hoặc push.
- Xác minh thiết bị đích, nội dung preview và trạng thái dev-mode trước mọi thao tác triển khai.
- Không mở API, Syslog listener hoặc database ra mạng công cộng khi chưa có lớp xác thực và kiểm soát truy cập phù hợp.

## Trạng thái dự án

NetworkTools đang trong giai đoạn phát triển và kiểm chứng trong môi trường nghiên cứu/lab. API, một số worker backend và một số luồng View & Push vẫn đang được hoàn thiện; không nên sử dụng như một hệ thống production khi chưa có kiểm thử tích hợp trên hạ tầng mục tiêu.
