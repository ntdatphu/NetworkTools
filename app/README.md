# NetworkTools desktop app

Ứng dụng desktop PyQt6/QML để quản lý inventory, cấu hình và giám sát thiết bị mạng. QML module công khai vẫn là `UI`; Python cung cấp QObject/slot, feature service/repository/worker và adapter SQLite/network.

## Môi trường và lệnh

- Python 3.11+ (baseline hiện tại: 3.14.6)
- PyQt6 6.7–6.10 và dependency trong `pyproject.toml`

Khởi chạy tương tác, bao gồm kiểm tra `uv`, đồng bộ dependency, build/kiểm tra
Cython và chạy app:

```bash
./networktools.sh
```

Trên Windows:

```bat
networktools.bat
```

Chạy thẳng khi môi trường đã sẵn sàng:

```bash
./networktools.sh run
```

Các lệnh sau chỉ dành cho phát triển/kiểm thử:

```bash
uv run python scripts/validate_structure.py
uv run python -m unittest discover -s tests
```

DB runtime mặc định được tạo trong `data/`; đặt `NETWORKTOOLS_DATA_DIR` để dùng thư mục khác. Không commit DB/WAL/journal, backup, log, cache, credential hay private key. Preview/dev mode không được mở kết nối thật.

## Kiến trúc

```text
UI/QML → core facade/feature slots → service → repository → SQLite
                                      └────→ worker → infrastructure/network → device
```

| Lớp | Vai trò |
|---|---|
| `UI/` | module QML `UI`, shell/layout/shared và `qml/features` |
| `core/` | facade/context contract dùng chung; không thêm nghiệp vụ mới |
| `features/` | code, worker, template và tài liệu theo chức năng |
| `infrastructure/database/` | path, connection, schema và migration |
| `infrastructure/network/` | connector, session registry, command runner |
| `scripts/` | build DB và kiểm tra cấu trúc |
| `tests/` | unit, integration, QML harness và fixture |

Quy tắc đầy đủ ở [ARCHITECTURE_RULES.md](ARCHITECTURE_RULES.md); ánh xạ UI/Python/DB/device và trạng thái ở [FUNCTION_MAP.md](bang_ke_hach_cua_viet/FUNCTION_MAP.md).

## Bố trí thư mục `app/`

```text
app/
├── main.py                     # entry point PyQt6/QML
├── app_facade.py               # tập hợp public object dùng khi bootstrap
├── core/                       # context object và dịch vụ dùng chung
├── features/                   # nghiệp vụ theo từng chức năng mạng
├── infrastructure/             # adapter SQLite và kết nối thiết bị
├── UI/                         # module QML, component, theme, resource
├── data/                       # dữ liệu runtime, không commit database
├── templates/                  # template import/export cho người dùng
├── scripts/                    # công cụ build và kiểm tra cấu trúc
└── tests/                      # unit, integration và QML smoke test
```

### `core/` — cầu nối ứng dụng

`core` giữ contract dùng chung mà QML gọi qua các context object. `runtime.py` hiện chỉ là shim import tương thích có hạn đến 2026-10-20; implementation thật nằm ở `app_paths.py`, `settings.py`, `monitoring.py`, `terminal.py`, `external_tools.py` và `tasks.py`. `core/database/` duy trì import công khai `from core.database import DatabaseManager` trong khi các nhóm slot tiếp tục được chuyển sang feature. Không đặt repository, SQL hay template lệnh thiết bị mới trong `core`.

### `features/` — code theo chức năng

| Thư mục | Chức năng |
|---|---|
| `devices/` | inventory, thông tin đăng nhập và đồng bộ trạng thái thiết bị |
| `interfaces/` | persistence và workspace cho interface router; switchport/SVI ở `switching` |
| `dhcp/` | pool, excluded address, helper address, preview/push DHCP |
| `routing/` | static/default route, OSPF, EIGRP và routing information |
| `acl/` | ACL, rule, binding, collector/template và worker View & Push |
| `nat/` | static/dynamic NAT, PAT, NAT ACL, route-map và worker push |
| `switching/` | switchport, VLAN, SVI/L3, monitoring và View/Push Layer 2 Cisco IOS |
| `syslog/` | UDP/TCP listener, parser, batch writer, query và retention |
| `sftp/` | kết nối, duyệt file và hàng đợi truyền SFTP |
| `external_tools/` | catalog và metadata cho ứng dụng ngoài |
| `config_backup/` | lịch sử running-config theo thiết bị bằng Dulwich |

Mỗi feature tự sở hữu repository, validation, worker, parser và template khi cần. Luồng phụ thuộc không đi trực tiếp từ feature này vào bảng dữ liệu riêng của feature khác.

### `infrastructure/` — adapter kỹ thuật

```text
infrastructure/
├── database/
│   ├── paths.py                # nguồn path DB/schema duy nhất
│   ├── connection.py           # connection và transaction SQLite
│   ├── schemas/                # module schema nguồn
│   ├── migrations/             # migration có version trong tương lai
│   └── browser/                # adapter trình duyệt SQLite tùy chọn
├── network/
    ├── connector.py            # factory/contract kết nối thiết bị
    ├── device_connector.py     # adapter Netmiko SSH/Telnet
    ├── session_registry.py     # vòng đời và tái sử dụng session
    ├── command_runner.py       # chạy show/config command thống nhất
│   ├── config.py               # path/template/table contract cho worker
│   └── ping.py                 # ping adapter đa nền tảng
└── system/
    ├── network_info.py         # interface/IP/SSID phụ thuộc hệ điều hành
    ├── process_launcher.py     # mở terminal/process ngoài
    └── resource_monitor.py     # probe RAM không phụ thuộc Qt
```

Infrastructure không chứa validation nghiệp vụ và không import QML.

### `UI/` — giao diện QML

| Đường dẫn | Vai trò |
|---|---|
| `qmldir` | khai báo module công khai `UI` và component export |
| `qml/app/` | cửa sổ chính và trạng thái window |
| `qml/features/` | màn hình ACL, DHCP, Interfaces, NAT, Routing, Switching, Syslog |
| `qml/layout/`, `qml/panels/` | layout và panel cấp ứng dụng |
| `qml/shared/`, `components/` | component dùng lại, dialog và form control |
| `theme/` | theme state và design token |
| `resources/` | icon/resource đang có runtime consumer và license |

QML chỉ gọi QObject/slot được Python đăng ký; không chứa SQL hoặc logic kết nối/push thiết bị.

### View & Push và tiến trình nền

- ACL Security, NAT/NAT ACL, DHCP, Routing và Switching Layer 2 dùng chung `ViewPushButton`/`ViewPushDialog`.
- Preview chỉ render cấu hình pending và không mở kết nối; Switching so sánh
  SHA-256 theo module, các feature cũ tiếp tục dùng cờ `success = 0/-1`.
- Push chạy nền, ưu tiên tái sử dụng session SSH/Telnet của tab thiết bị; thiết bị `dev = 1` chỉ mô phỏng và không đăng nhập.
- Tiến trình task hiển thị trực tiếp trong status bar. Notification history chỉ nhận kết quả cuối, không tạo loading toast.
- Interface Router đã có nút View & Push trong layout mới nhưng hiện trả về `Coming soon`, vì worker import từ backend mới hỗ trợ trường interface cơ bản và chưa an toàn cho toàn bộ L3/WAN/Tunnel đang lưu trong app.

### Dữ liệu, script và kiểm thử

- `data/`: chứa SQLite runtime; có thể đổi vị trí bằng `NETWORKTOOLS_DATA_DIR`.
- `templates/`: template XLSX hoặc file mẫu tải về; template lệnh nằm cạnh feature.
- `scripts/build_databases.py`: đọc trực tiếp schema modular theo thứ tự tên, kiểm tra integrity/foreign key rồi thay DB atomically; không tạo SQL aggregate.
- `scripts/validate_structure.py`: phát hiện README thiếu, QML path sai, runtime artifact bị track và thư mục legacy quay lại.
- `tests/unit/`: validation/model/repository nhỏ.
- `tests/integration/`: SQLite tạm và fake connector.
- `tests/qml/`: QML harness; các `test_qml_*` ở root thực hiện smoke/contract test.

## QML context properties

| Tên | Python | Vai trò |
|---|---|---|
| `dbManager` | `DatabaseManager` | CRUD, feature facade, preview/push và delegate đọc lịch sử config backup |
| `cli` | `TerminalHelper` | terminal và vòng đời session |
| `networkMonitor` | `NetworkMonitor` | trạng thái mạng/RAM |
| `statusBarSettings` | `StatusBarSettings` | tùy chọn status bar |
| `themeSettings` | `ThemeSettings` | theme persistence |
| `windowSettings` | `WindowSettings` | window persistence |
| `AppPaths` | `AppPaths` | resource URL an toàn |
| `externalTools` | `ExternalToolsManager` | catalog/công cụ ngoài |
| `sftpController` | `SftpController` | SFTP workspace |
| `syslogManager` / `syslogSettings` | Syslog feature | listener/query/configuration |

## Trạng thái

DHCP, ACL, NAT, Switching Layer 2, Syslog, SFTP và Config Backup có persistence/worker chính; Routing, Router Interface push, Switching RESTCONF/pull-sync, Devices và External Tools là `partial`. Switching hỗ trợ VLAN, switch port/EtherChannel, STP, VTP và L2 Security trên Cisco IOS qua SSH/Telnet; các giới hạn được ghi trong `features/switching/INTEGRATION_LIMITATIONS.md`. Terminal/session, settings, monitoring và path đã có owner riêng; facade database vẫn còn một số CRUD/import/routing cần tách tiếp. Backup cấu hình nằm tại `backup/<host>/cfg`, dùng Git object nội bộ qua Dulwich và không cần Git CLI. Xem `features/*/README.md` và Known gaps trong function map.
