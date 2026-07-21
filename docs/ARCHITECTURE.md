# Kiến trúc kỹ thuật toàn dự án NetworkTools

Ngày đối chiếu: **2026-07-14**.

Tài liệu này mô tả toàn repository. Phần `app/` được kiểm chứng sâu tới runtime/test; các thành phần ngoài `app/` được đối chiếu ở chế độ chỉ đọc theo code, import, đường dẫn, schema, script và điểm vào hiện có.

## 1. Bản đồ kiến trúc

```text
Người dùng
  │
  ├─ Desktop: app/UI (QML/Qt Quick)
  │      │ context properties + signal/slot
  │      ▼
  │   app/core (PyQt6 bridge, task/session, settings)
  │      ├─ app/backend (repository/CRUD cục bộ)
  │      ├─ app/database → app/*.db
  │      └─ app/network_code → SSH/NETCONF/RESTCONF hoặc dev-mode
  │
  └─ API dự kiến: api_server.py (FastAPI)
         │
         ▼
      backend cua kien/PyCode
         ├─ dispatcher/worker/template
         ├─ sync/login/topology/security/AI
         └─ backend DB + thiết bị mạng

mock/  ── fixture/config mẫu cho phát triển và thử nghiệm
latex/, report/ ── nguồn báo cáo nghiên cứu của toàn dự án
docs/  ── kiến trúc, contract, audit và backlog
```

Sơ đồ trên phân biệt **kiến trúc dự án dự kiến** với **kết nối runtime đã hoạt động**. Hiện desktop có đường chạy độc lập trong `app/`; API và `backend cua kien/` là thành phần backend thật của dự án nhưng contract kết nối của chúng đang lỗi, nên chưa thể vẽ một mũi tên “đã tích hợp” từ desktop sang API/backend.

## 2. Hai lớp mang tên backend

| Thành phần | Vai trò đúng | Trạng thái kết nối hiện tại |
|---|---|---|
| `app/backend/` | Repository/normalize/CRUD chạy trong tiến trình desktop. | Được `app/core` gọi trực tiếp. |
| `backend cua kien/` | Backend dự án: dispatcher, worker mạng, sync, topology, security, AI, schema/template. | `app/main.py` không import trực tiếp; `api_server.py` dự kiến làm gateway nhưng import/path đang lệch. |

`app/backend.py` chỉ là facade export QObject service cho QML. Không gọi nó là backend server và không dùng nó để thay thế `backend cua kien/` trong tài liệu toàn dự án.

## 3. Runtime desktop trong `app/`

### 3.1 Khởi động

`app/main.py`:

1. tạo `QApplication`;
2. build database còn thiếu;
3. tạo `QQmlApplicationEngine`;
4. đưa `app/` vào QML import path;
5. đăng ký context properties;
6. tải `engine.loadFromModule("UI", "Main")`.

Ứng dụng dùng **PyQt6**, không dùng PySide6.

### 3.2 Dịch vụ QML

| Context property | Class | Vai trò |
|---|---|---|
| `dbManager` | `core.database.DatabaseManager` | Device CRUD, Routing/DHCP/ACL/NAT, backup, info và View/Push. |
| `cli` | `core.runtime.TerminalHelper` | Terminal, ping, session, command, running-config, connect/sync. |
| `networkMonitor` | `core.runtime.NetworkMonitor` | Network type/name và RAM cho Status Bar. |
| `statusBarSettings` | `core.runtime.StatusBarSettings` | Lưu cấu hình Status Bar bằng `QSettings`. |
| `themeSettings` | `core.runtime.ThemeSettings` | Theme/accent/sidebar persistence. |
| `windowSettings` | `core.runtime.WindowSettings` | Geometry/maximized state. |
| `AppPaths` | `core.runtime.AppPaths` | Resolve resource thành local URL. |
| `externalTools` | `core.runtime.ExternalToolsManager` | CRUD/mở SSH client, terminal và DB browser; nhận diện default application + app gợi ý trên Windows/Linux, giữ một app active mỗi loại, validate executable và chặn `{password}` trong argv. |

### 3.3 QML shell và lifecycle

- `UI/qml/app/Main.qml`: window shell, notification, Activity Bar, sidebar, tabs, Feature Bar, Content Area và Status Bar.
- `UI/qml/content/ContentArea.qml`: lazy-load view lần đầu rồi giữ instance sống.
- `UI/qml/devices/DeviceTabs.qml`: tab theo IP và đóng session khi đóng tab.
- `UI/qml/panels/PanelSideBar.qml`: Devices, Settings và Database tables.

Lazy-load giảm chi phí khởi động nhưng RAM tăng theo số view đã mở; view cache cũng có thể cũ sau sync nền. Cần lifecycle `reloadData(reason)`, invalidation và dirty-state guard như backlog beta.

### 3.4 Database bridge và task

Luồng local CRUD:

```text
QML form → app/core slot → app/backend repository → app/device_network.db
         ← result/bool   ← normalize/transaction ←
```

`BackgroundTask`/`QThread` xử lý connect/sync, command, running-config và View/Push. `DeviceSessionRegistry` tái sử dụng connector theo host. Riêng `NetworkMonitor` vẫn probe đồng bộ trên main thread mỗi 3 giây và là rủi ro responsiveness.

### 3.5 View & Push desktop

`app/core/view_push.py` hiện điều phối:

- Static/OSPF/EIGRP qua `app/network_code/routing`;
- DHCP qua `app/network_code/dhcp`.

`dev = 1` tạo kết quả mô phỏng mà không mở session thật; `dev = 0` cần connector thật. ACL/NAT/Interface chưa có View & Push controller trong runtime desktop.

## 4. Backend dự án trong `backend cua kien/`

### 4.1 Luồng dự kiến

```text
API/CLI
  → dispatcher (routing/interface/dhcp/nat/security)
    → đọc pending rows và device inventory từ SQLite
      → render Jinja hoặc tạo payload YANG
        → Nornir/Netmiko/NAPALM/NETCONF/RESTCONF
          → thiết bị
    ← cập nhật success/xóa row + JSON report
```

Backend còn có các luồng độc lập:

- login/probe nhận diện hostname, OS và role;
- sync parse running-config rồi đối chiếu Interface/OSPF/DHCP;
- topology quét CDP và sinh Draw.io XML;
- SaveMemories lưu cấu hình;
- packet sniffer dùng PyShark/Scapy;
- AI_Config gọi Ollama, tạo lệnh và có thể push song song tới console.

### 4.2 Contract đường dẫn hiện tại

`PyCode/share/config.py` tìm `.env`, sau đó hard-code:

```text
BACKEND_DIR = <project>/backend
DB_RELATIVE_PATH mặc định = backend/PyCode/share/database/device_network.db
TMP_DIR = <project>/backend/Tmp
BACKUP_DIR = <project>/app/backup
```

Repository thật không có `backend/`, chỉ có `backend cua kien/`, và không có `.env` được commit. Vì vậy config không thể coi là portable hoặc chạy ngay sau clone. Việc ghi `app/backup` cũng tạo coupling ghi chéo từ backend vào vùng desktop mà chưa có interface/version contract.

### 4.3 Contract import hiện tại

- `api_server.py` và `PyCode/sync/*` import `backend.PyCode...`;
- các module khác import `PyCode...` hoặc sibling như `worker_switch`;
- thư mục `backend cua kien/` không thể được import bằng tên dotted `backend cua kien`.

Cần chọn một package name hợp lệ và dùng thống nhất qua packaging/config, thay vì phụ thuộc `sys.path` và working directory.

### 4.4 Contract schema hiện tại

Backend có ba nguồn tên bảng không đồng nhất:

| Nguồn | Quy ước | Kết quả kiểm tra |
|---|---|---|
| `backend cua kien/sql/*.sql` | `devices`, `ospf_processes`, ... | 74 bảng không prefix. |
| `backend cua kien/PyCode/share/config.py::DB_TABLES` | `t01_devices`, `t04_ospf_processes`, ... | 42 tên được map; **0/42** tồn tại trong schema backend. |
| `app/database/schema/*.sql` | `t01_devices`, `t04_ospf_processes`, ... | 72 bảng; gần với map, nhưng hai tên interface OSPF/EIGRP trong map vẫn là legacy. |

Do đó chưa có bằng chứng backend đang dùng một DB contract tự nhất quán. Trước khi nối API/desktop phải chọn schema authority, version hóa/migrate và có integration test dùng cùng một database fixture.

## 5. API gateway

`api_server.py` khai báo endpoint POST:

- `/api/v1/network/dhcp`;
- `/api/v1/network/sync`;
- `/api/v1/network/interfaces`;
- `/api/v1/network/ospf`, `/eigrp`, `/static`;
- `/api/v1/network/acl`, `/nat`.

Các endpoint dùng FastAPI `BackgroundTasks` để gọi dispatcher. Tuy nhiên API chưa chạy được từ cây hiện tại vì package import `backend` không tồn tại; manifest backend cũng thiếu `fastapi`, `uvicorn`, `python-dotenv`. API chưa có authentication/authorization, request model typed, idempotency, task ID, status endpoint hay error propagation từ worker. Phản hồi `status: success` hiện chỉ có nghĩa tác vụ đã được xếp/gọi, không chứng minh push thiết bị thành công.

## 6. Dữ liệu, fixture và báo cáo

### `mock/`

Payload/config mẫu giúp phát triển parser/template và tái hiện yêu cầu mạng. Nhiều file là tập hợp thử nghiệm lớn, có credential mẫu và contract cũ; phải validate/redact trước khi đưa vào test tự động. Script `mock/nqv/build_sql.*` hiện không chạy tại chỗ vì thiếu hai thư mục nguồn mà script yêu cầu.

### `latex/` và `report/`

- `latex/` là pipeline báo cáo modular được README gốc chỉ định; build bằng XeLaTeX/latexmk.
- `report/` là nguồn báo cáo thứ hai có bìa và placeholder.

Hai cây này không tham gia runtime mạng nhưng là deliverable của dự án. Số liệu capability, test và kiến trúc trong báo cáo phải lấy từ docs đã kiểm chứng, không từ placeholder hoặc claim cũ.

## 7. Ranh giới bảo mật và hiệu năng

### Bảo mật

- Desktop và backend đều đang lưu/đọc password plaintext trong SQLite.
- Nhiều request RESTCONF dùng `verify=False`; NETCONF dùng `hostkey_verify=False`.
- API chưa có auth; packet-sniffer/Telnet credential capture là công cụ nhạy cảm.
- AI-generated commands có thể được push song song tới tối đa 15 thiết bị sau một prompt xác nhận chung.
- Backup/running-config có thể chứa secret nhưng chưa có permission/retention policy.

### Hiệu năng và độ tin cậy

- Desktop: NetworkMonitor có thể block UI; Routing Info fetch/copy/render toàn bộ row.
- Backend: nhiều dispatcher dùng `fetchall()` và payload toàn khối; chưa có queue bền vững/backpressure/task status.
- Topology dùng queue list với `pop(0)` và thao tác mạng tuần tự; scale kém khi topology lớn.
- File report/Tmp dùng tên cố định hoặc relative working directory, dễ ghi đè khi chạy đồng thời.
- Nhiều request không đặt timeout; lỗi có thể treo worker hoặc trả success API trước khi biết kết quả thật.

## 8. Thứ tự tích hợp đề xuất

1. Chốt package name/path hợp lệ cho `backend cua kien/` mà vẫn giữ nhãn vai trò ở cấp thư mục hoặc metadata.
2. Chốt một schema authority và migration; loại bỏ contract 0/42 giữa `DB_TABLES` và SQL backend.
3. Tạo manifest dependency/backend entry point tái lập được; thêm FastAPI/Uvicorn/dotenv nếu API là đường chính.
4. Tạo integration test: API → dispatcher → DB fixture → fake worker → trạng thái tác vụ.
5. Thêm auth, typed request/response, task ID/status/cancel, timeout và idempotency.
6. Sau đó mới nối desktop với API hoặc quyết định giữ hai runtime độc lập có contract dữ liệu rõ ràng.

Chi tiết lỗi và bằng chứng nằm tại [CODE_AUDIT.md](CODE_AUDIT.md). Backlog UI desktop nằm tại [beta/PENDING_CHANGES_UI_UX.md](beta/PENDING_CHANGES_UI_UX.md).
