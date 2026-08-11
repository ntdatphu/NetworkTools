# NetworkTools desktop app

Ứng dụng desktop PyQt6/QML để quản lý inventory, cấu hình và giám sát thiết bị mạng. QML module công khai vẫn là `UI`; Python cung cấp QObject/slot, feature service/repository/worker và adapter SQLite/network.

## Môi trường và lệnh

- Python 3.11+ (baseline hiện tại: 3.14.6)
- PyQt6 6.7–6.10 và dependency trong `pyproject.toml`

Khởi chạy tương tác, bao gồm kiểm tra `uv`, đồng bộ dependency,
thử build/kiểm tra Cython và chạy app:

```bash
./networktools.sh
```

Trên Windows:

```bat
networktools.bat
```

Cython chỉ là tăng tốc tùy chọn. Lệnh `setup`/`all` sẽ cảnh báo và
tiếp tục bằng `features.devices.sync._engine.py` nếu máy không có compiler
C/C++ hoặc policy hệ thống chặn module native. Lệnh `build` vẫn là kiểm tra
nghiêm ngặt và trả mã lỗi nếu không build/load được accelerator.

Trên Windows, `networktools.bat` tự nhận biết khi Application Control chặn
các module native bên trong wheel Cython và thử lại bằng compiler pure-Python
chính thức của Cython. Việc tạo file `.pyd` vẫn cần Microsoft Visual C++
14.0 trở lên và policy cho phép load file đó.

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
                                      └────→ bounded batch executor
                                             → session registry (khóa theo host)
                                             → infrastructure/network → device
```

| Lớp | Vai trò |
| --- | --- |
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
| --- | --- |
| `devices/` | inventory, đăng nhập, Connect/Get/Save config service và batch nhiều thiết bị |
| `interfaces/` | persistence và workspace cho interface router; switchport/SVI ở `switching` |
| `dhcp/` | pool, excluded address, helper address, preview/push DHCP |
| `routing/` | static/default route, OSPF, EIGRP và routing information |
| `fhrp/` | gateway dự phòng đa thiết bị bằng HSRP, VRRP và GLBP |
| `acl/` | ACL, rule, binding, collector/template và worker View & Push |
| `nat/` | static/dynamic NAT, PAT, NAT ACL, route-map và worker push |
| `switching/` | switchport, VLAN, SVI/L3, monitoring và View/Push Layer 2 Cisco IOS |
| `syslog/` | UDP/TCP listener, parser, batch writer, query và retention |
| `sftp/` | kết nối, duyệt file và hàng đợi truyền SFTP |
| `terminal/` | cửa sổ CLI độc lập do app quản lý, parser ANSI và stream Netmiko |
| `external_tools/` | catalog và metadata cho ứng dụng ngoài |
| `config_backup/` | lịch sử running-config theo thiết bị bằng Dulwich |
| `config_sync/` | policy đồng bộ router/switch, preview xung đột Manual Sys |

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
    ├── session_entry.py        # trạng thái, generation và khóa CLI theo host
    ├── session_registry.py     # owner vòng đời và tái sử dụng nhiều session
    ├── batch_executor.py       # worker pool giới hạn concurrency
    ├── command_runner.py       # chạy show/config command thống nhất
│   ├── config.py               # path/template/table contract cho worker
│   └── ping.py                 # ping adapter đa nền tảng
└── system/
    ├── network_info.py         # interface/IP/SSID phụ thuộc hệ điều hành
    └── resource_monitor.py     # probe RAM không phụ thuộc Qt
```

Infrastructure không chứa validation nghiệp vụ và không import QML.

### `UI/` — giao diện QML

| Đường dẫn | Vai trò |
| --- | --- |
| `qmldir` | khai báo module công khai `UI` và component export |
| `qml/app/` | cửa sổ chính và trạng thái window |
| `qml/features/` | màn hình ACL, DHCP, FHRP, Interfaces, NAT, Routing, Switching, Syslog |
| `qml/layout/`, `qml/panels/` | layout và panel cấp ứng dụng |
| `qml/shared/`, `components/` | component dùng lại, dialog và form control |
| `theme/` | theme state và design token |
| `resources/` | icon/resource đang có runtime consumer và license |

QML chỉ gọi QObject/slot được Python đăng ký; không chứa SQL hoặc logic kết nối/push thiết bị.

Sidebar dùng `host/IP` làm định danh nghiệp vụ. `activeHost` (tab đang xem),
`selectedHosts` (tập chạy batch) và session đang mở là ba trạng thái độc lập.
Nhấn chuột phải vào host đầu tiên và chọn `Select multiple` để vào chế độ chọn;
sau đó click trái để thêm/bỏ từng host. Batch action nằm trong context menu,
không dùng checkbox hay toolbar cố định.
Đóng tab chỉ đóng editor, không đăng xuất. Connect, Get running-config và
Disconnect selected chạy qua batch backend (mặc định tối đa 5 host đồng thời);
kết quả và tiến độ được ánh xạ riêng theo host. Trên cùng một host, registry
tuần tự hóa thao tác CLI để không có hai worker cùng dùng một channel.
Menu thiết bị đang kết nối có **Save configuration** để lưu running-config thành
startup-config. Tác vụ chạy nền, dùng session hiện hữu và fail-closed nếu driver
không có capability `save_config`; app không tự mở kết nối ngầm.

### View & Push và tiến trình nền

- ACL Security, NAT/NAT ACL, DHCP, Routing, FHRP và Switching Layer 2 dùng chung `ViewPushButton`/`ViewPushDialog`; Routing Group/FHRP dùng dialog batch đa host dùng chung.
- Preview chỉ render cấu hình pending và không mở kết nối; Switching so sánh
  SHA-256 theo module, các feature cũ tiếp tục dùng cờ `success = 0/-1`.
- Push chạy nền, ưu tiên tái sử dụng session SSH/Telnet của tab thiết bị; thiết bị `dev = 1` chỉ mô phỏng và không đăng nhập.
- Tiến trình task hiển thị trực tiếp trong status bar. Notification history chỉ nhận kết quả cuối, không tạo loading toast.
- Router Interface có layout danh sách-trước/editor-sau và View & Push Cisco IOS
  cho cấu hình L3/WAN/Tunnel trong phạm vi ghi tại `features/interfaces/README.md`.
- Routing Group tự lọc connected network cho từng host. FHRP tự lọc interface
  chứa Default Gateway và hỗ trợ preview/push đồng thời cho các member đã chọn.

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
| --- | --- | --- |
| `dbManager` | `DatabaseManager` | CRUD, feature facade, preview/push và delegate đọc lịch sử config backup |
| `cli` | `TerminalHelper` | mở CLI nội bộ, facade batch/vòng đời session và `saveDeviceConfigAsync(host)`; API batch gồm `connectHostsAsync`, `getRunningConfigsAsync`, `disconnectHostsAsync`, `cancelBatch` |
| `networkMonitor` | `NetworkMonitor` | trạng thái mạng/RAM |
| `statusBarSettings` | `StatusBarSettings` | tùy chọn status bar |
| `themeSettings` | `ThemeSettings` | theme persistence |
| `windowSettings` | `WindowSettings` | window persistence |
| `AppPaths` | `AppPaths` | resource URL an toàn |
| `externalTools` | `ExternalToolsManager` | catalog/công cụ ngoài |
| `sftpController` | `SftpController` | SFTP workspace |
| `syslogManager` / `syslogSettings` | Syslog feature | listener/query/configuration |

CLI thiết bị không còn gọi PuTTY hay terminal của hệ điều hành. Feature bar,
menu chuột phải và `Ctrl+Alt+T` đều mở một `QPlainTextEdit` trong cửa sổ độc lập
do app sở hữu. Widget dùng source MIT `qtpyTerminal-main` đã điều chỉnh cho
external Netmiko transport, không fork shell/PTY; worker giữ khóa CLI theo host,
gom output mỗi 20 ms và Pyte chỉ render các dòng dirty. Đóng cửa sổ không hủy
session dùng chung của host.

## Trạng thái

DHCP, ACL, NAT, FHRP Cisco IOS, Switching Layer 2, Syslog, SFTP và Config Backup có persistence/worker chính; Routing đơn host, Router Interface nâng cao, Switching RESTCONF/full pull-sync, Devices và External Tools là `partial`. Switching hỗ trợ VLAN, switch port/EtherChannel, STP, VTP và L2 Security trên Cisco IOS qua SSH/Telnet; pull-sync hiện có VLAN, interface/trunk, EtherChannel và VTP status. Các giới hạn được ghi trong `features/switching/INTEGRATION_LIMITATIONS.md`. Terminal/session, settings, monitoring và path đã có owner riêng; facade database vẫn còn một số CRUD/import/routing cần tách tiếp. Backup cấu hình nằm tại `backup/<host>/cfg`, dùng Git object nội bộ qua Dulwich và không cần Git CLI. Xem `features/*/README.md` và Known gaps trong function map.
