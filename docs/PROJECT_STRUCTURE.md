# Cấu trúc dự án NetworkTools

Tài liệu này tập trung vào runtime trong `app/`; các thư mục prototype/report ngoài `app/` không được coi là nguồn thực thi của desktop application.

## 1. Cây thư mục runtime

```text
app/
├── main.py                    # Entry point PyQt6
├── backend.py                 # Facade export class/context service
├── pyproject.toml             # Python >=3.11, dependencies và script entry
├── core/
│   ├── database.py            # DatabaseManager và device/routing/info slots
│   ├── *_slots.py             # DHCP, ACL, NAT mixin
│   ├── database_paths.py      # Canonical DB paths
│   ├── runtime.py             # Session, OS integration, settings, monitor
│   ├── background_task.py     # QObject chạy trong QThread
│   └── view_push.py           # Routing/DHCP preview & push controller
├── backend/
│   ├── dhcp/                  # DHCP + Interface repository
│   ├── route/                 # Static, OSPF, EIGRP repository
│   ├── acl/                   # ACL repository
│   ├── nat/                   # NAT repository
│   ├── syslog_server/         # Syslog listener, parser, writer và Qt facade
│   ├── external_tools/        # Helper DB legacy/độc lập
│   └── DB_browser_default/    # QtWidgets browser legacy
├── network_code/
│   ├── login/                 # Connector, session sync parser
│   ├── routing/               # Dispatcher, worker, OSPF API, templates
│   ├── dhcp/                  # Dispatcher, worker, Jinja template
│   ├── PyCode/share/config.py # Mapping tên bảng cho worker
│   └── sql/                   # Snapshot schema legacy
├── database/
│   ├── schema/                # Nguồn schema device_network
│   ├── info_collected/        # Nguồn schema collector
│   ├── device_network.sql     # Output tổng hợp
│   ├── info_collected.sql     # Output tổng hợp
│   └── build_databases.py     # Builder an toàn
├── UI/
│   ├── qmldir                 # Module UI và component exports
│   ├── qml/                   # Screen/view/dialog
│   ├── components/            # Base/standard/layout components
│   ├── theme/                 # Singleton, state và design token
│   ├── resources/             # SVG/PNG/ICO
│   └── *.sql                  # Snapshot legacy, không dùng lúc runtime
├── tests/                     # unittest + QML smoke/harness; tests/syslog riêng
└── template/EXdevices.xlsx    # Mẫu import thiết bị
```

Database runtime `app/device_network.db`, `app/info_collected.db`, `app/external_tools.db`, backup, log, `.venv` và cache là artifact cục bộ bị ignore; chúng không phải mã nguồn.

## 2. Nguồn sự thật theo lĩnh vực

| Lĩnh vực | Nguồn sự thật |
|---|---|
| QML module/component | `app/UI/qmldir` + file dưới `app/UI/` |
| Device/routing bridge | `app/core/database.py` |
| Runtime/session/settings | `app/core/runtime.py` |
| DHCP/ACL/NAT slots | `app/core/*_slots.py` |
| Business repository | `app/backend/` |
| Push/connector | `app/network_code/` |
| Schema cấu hình | `app/database/schema/*.sql` |
| Schema dữ liệu thu thập | `app/database/info_collected/*.sql` |
| Capability đã kiểm chứng | `docs/CODE_AUDIT.md` và test trong `app/tests/` |

Không dùng `app/README.md`, `app/SCHEMA_LOGIC.md`, các file `network_code/*.md` hay snapshot SQL legacy để suy luận trạng thái mới nhất nếu chúng mâu thuẫn với code/test.

## 3. Cấu trúc QML

```text
UI/qml/
├── app/        # Main, StatefulWindow
├── layout/     # ActivityBar, StatusBar
├── panels/     # Devices/Settings/Database sidebar
├── devices/    # Device tabs
├── feature/    # Feature bar
├── content/    # Content router, Information, Settings, DB Browser
├── dhcp/
├── routing/
├── acl/
├── nat/
├── interface/
├── syslog/     # Workspace, table, filter, details và settings System Logs
├── sidebar/    # Có sidebar/syslog cho item/context/configuration dialog
└── shared/
```

`ContentArea` lazy-load view ở lần truy cập đầu. Routing/DHCP/NAT tiếp tục lazy-load subtab nặng; instance đã load được giữ sống.

## 4. Tài liệu dự án

```text
docs/
├── ARCHITECTURE.md
├── PROJECT_STRUCTURE.md
├── DATABASE_SCHEMA.md
├── UI_COMPONENTS.md
├── SYSTEM_LOGS.md
├── SHORTCUTS.md
├── USAGE_GUIDE.md
├── CODE_AUDIT.md
└── beta/
    ├── schema.md
    ├── PENDING_CHANGES_UI_UX.md
    ├── CHANGES_PENDING.md
    └── ARCHITECTURE.md
```

Tài liệu `beta/` là kế hoạch/refactor đang tiến hành; tài liệu cấp `docs/` mô tả runtime đã kiểm chứng.

## 5. Thư mục ngoài runtime

Repository hiện còn `latex/`, `report/`, `mock/`, `backend cua kien/`, `api_server.py` và các file báo cáo/tìm kiếm ở root. Chúng phục vụ báo cáo, mẫu dữ liệu hoặc prototype riêng; chúng không được `app/main.py` import trong luồng desktop runtime đã kiểm chứng.
