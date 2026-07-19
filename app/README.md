# NetworkTools desktop app

Ứng dụng desktop PyQt6/QML để quản lý inventory, cấu hình và giám sát thiết bị mạng. QML module công khai vẫn là `UI`; Python cung cấp QObject/slot, feature service/repository/worker và adapter SQLite/network.

## Môi trường và lệnh

- Python 3.11+ (baseline hiện tại: 3.14.6)
- PyQt6 6.7–6.10 và dependency trong `pyproject.toml`

```bash
uv sync
uv run python scripts/build_databases.py
uv run python main.py
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

Quy tắc đầy đủ ở [ARCHITECTURE_RULES.md](ARCHITECTURE_RULES.md); ánh xạ UI/Python/DB/device và trạng thái ở [FUNCTION_MAP.md](FUNCTION_MAP.md).

## QML context properties

| Tên | Python | Vai trò |
|---|---|---|
| `dbManager` | `DatabaseManager` | CRUD, feature facade, preview/push |
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

DHCP, ACL, NAT, Syslog và SFTP có persistence/worker chính; Routing và Switching là `partial`; Devices/Interfaces còn facade cần tách nhỏ. README từng feature không khẳng định hoàn tất nếu chưa có test. Xem `features/*/README.md` và Known gaps trong function map.
