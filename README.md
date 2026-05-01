
# NetworkTools – Network Management System

![Platform](https://img.shields.io/badge/platform-Windows-blue)
![Frontend](https://img.shields.io/badge/frontend-Qt%20(QML%20%2B%20C++)-green)
![Backend](https://img.shields.io/badge/backend-Python-yellow)
![Database](https://img.shields.io/badge/database-SQLite-lightgrey)
![Status](https://img.shields.io/badge/status-Development-orange)


## 📌 Giới thiệu

**NetworkTools** là hệ thống quản lý và tự động hóa mạng, được xây dựng theo kiến trúc tách biệt:

- **Frontend:** Qt (QML + C++)
- **Backend:** Python
- **Database:** SQLite

Mục tiêu:
- Tự động hóa cấu hình thiết bị mạng
- Quản lý tập trung Router/Switch
- Giao diện trực quan, dễ mở rộng
- Hỗ trợ đa giao thức (SSH, NETCONF, RESTCONF)


## 🧠 Kiến trúc hệ thống

```

Frontend (QML + C++)
│
▼
C++ Bridge Layer
│
▼
Backend (Python)
│
├── Controllers
├── Services
├── Protocol Adapters
└── Database (SQLite)

```

### 🔄 Luồng xử lý

1. User thao tác trên UI (QML)
2. C++ xử lý signal & bridge
3. Backend nhận request
4. Generate config bằng Jinja2
5. Gửi xuống thiết bị mạng
6. Trả kết quả về UI


## 📁 Cấu trúc dự án

```

NETWORKTOOLS/
│
├── backend/        # Logic xử lý mạng (Python)
├── frontend/       # UI (Qt/QML + C++)
├── docs/           # Tài liệu phân tích & kiến trúc
├── mock/           # Dữ liệu test
├── report/         # Báo cáo LaTeX
└── README.md

```


## 🔧 Backend

### Thành phần chính

- **controllers/**: Xử lý logic (login, database, parsing)
- **routing/**: Cấu hình routing (BGP, OSPF, EIGRP, Static)
- **switching/**: Cấu hình switch
- **security/**: Packet sniffing, security tools
- **topology/**: Xử lý topology
- **service/dhcp/**: DHCP

### Protocol hỗ trợ

- SSH
- Telnet
- NETCONF
- RESTCONF

### Template Engine

- Jinja2 dùng để generate config cho:
  - Cisco IOS
  - MikroTik RouterOS


## 🎨 Frontend

### Công nghệ

- Qt 6
- QML (UI)
- C++ (logic + database bridge)

### Module UI

- Routing (OSPF, EIGRP, Static)
- ACL
- DHCP
- Device Management
- Sidebar + Navigation
- Notification system


## Database

- SQLite
  - Device info
  - Routing config
  - DHCP / ACL
  - Backup dữ liệu


## ✨ Tính năng chính

### ✅ Network Automation
- Routing:
  - BGP
  - OSPF
  - EIGRP
  - Static Route
- Interface configuration
- DHCP
- ACL

### ✅ Multi-Protocol
- SSH / Telnet
- NETCONF / RESTCONF

### ✅ UI/UX
- Dynamic Form (QML)
- Validation Dialog
- Toast / Notification
- Multi-device tabs


## 📚 Tài liệu dự án NetworkUI

Phần này tổng hợp các tài liệu Markdown quan trọng liên quan trực tiếp đến **kiến trúc hệ thống, QML, cơ sở dữ liệu và kế hoạch triển khai Routing**.


## 🇻🇳 1. Tài liệu chính (Tiếng Việt)

### 🔹 Kiến trúc & tổng quan
- [📄 Tổng quan dự án](docs/architecture/PROJECT_SUMMARY.md)  
  → Mô tả kiến trúc tổng thể (C++ + QML + Python), data flow và các module chính.

- [📄 Cấu trúc dự án](docs/architecture/PROJECT_STRUCTURE.md)  
  → Sơ đồ thư mục, vai trò từng thành phần và các file quan trọng.


### 🔹 Phân tích hệ thống
- [📄 Phân tích QML](docs/analysis/QML_ANALYSIS.md)  
  → Chi tiết từng file QML: vai trò, bindings, signal/event, tương tác backend.

- [📄 Phân tích Database (data.sql)](docs/analysis/DATA_SQL_ANALYSIS.md)  
  → Schema, quan hệ bảng, đánh giá thiết kế và các điểm cần lưu ý.


### 🔹 Runtime & Build
- [📄 Generated Files](docs/architecture/GENERATED_FILES.md)  
  → Danh sách file sinh ra trong quá trình build/runtime, mục đích và thời điểm tạo.


### 🔹 Kế hoạch triển khai
- [📄 Routing Backend + UI Plan](docs/plans/ROUTING_BACKEND_PLAN_VI.md)  
  → Thiết kế chi tiết backend + UI cho Routing theo hướng UX tối ưu.


## 🌍 2. Tài liệu tham chiếu (English)

- [PROJECT_SUMMARY_EN](docs/architecture/PROJECT_SUMMARY_EN.md)
- [PROJECT_STRUCTURE_EN](docs/architecture/PROJECT_STRUCTURE_EN.md)
- [QML_ANALYSIS_EN](docs/analysis/QML_ANALYSIS_EN.md)
- [GENERATED_FILES_EN](docs/architecture/GENERATED_FILES_EN.md)
- [ROUTING_BACKEND_PLAN_EN](docs/plans/ROUTING_BACKEND_PLAN_EN.md)


## 📖 3. Thứ tự đọc đề xuất

Để hiểu dự án nhanh và có hệ thống:

1. [PROJECT_SUMMARY](docs/architecture/PROJECT_SUMMARY.md)
2. [PROJECT_STRUCTURE](docs/architecture/PROJECT_STRUCTURE.md)
3. [QML_ANALYSIS](docs/analysis/QML_ANALYSIS.md)
4. [DATA_SQL_ANALYSIS](docs/analysis/DATA_SQL_ANALYSIS.md)
5. [ROUTING_BACKEND_PLAN_VI](docs/plans/ROUTING_BACKEND_PLAN_VI.md)
6. [GENERATED_FILES](docs/architecture/GENERATED_FILES.md)


## 📝 4. Ghi chú

- Các tài liệu tập trung vào:
  - Hiện trạng hệ thống
  - Phân tích thiết kế
  - Định hướng triển khai

- Không tự động thay đổi source code trong quá trình đọc.

- Nội dung liên quan đến **PythonEnvManager** đã được loại bỏ để đảm bảo tài liệu tập trung và rõ ràng hơn.


## ⚙️ Cài đặt & chạy

### 🔹 Backend

```bash
cd backend
python -m venv venv

# Windows
venv\Scripts\activate

# Linux/Mac
source venv/bin/activate

pip install -r requirements.txt
python build_db.py
```


### 🔹 Frontend

```bash
cd frontend
mkdir build
cd build

cmake ..
cmake --build .
```


## 🧪 Dữ liệu test

* Thư mục `mock/`
* Chứa:

  * JSON cấu hình mẫu
  * Test input cho routing, DHCP, interface


## 🛣️ Roadmap

* [ ] Hoàn thiện Routing UI ↔ Backend sync
* [ ] Topology visualization
* [ ] Real-time monitoring
* [ ] RBAC (Role-based access control)
* [ ] Plugin system cho vendor


## ⚠️ Ghi chú

* Dự án đang trong giai đoạn **development**
* Một số module:

  * Đang test
  * Chưa tối ưu
  * Có thể thay đổi kiến trúc
