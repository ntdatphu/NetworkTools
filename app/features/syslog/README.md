# Cisco Syslog

Trạng thái: **implemented** cho một UDP hoặc TCP listener cục bộ, parser ưu tiên
Cisco IOS/IOS-XE, persistence SQLite và cấu hình destination trên thiết bị.

Luồng phụ thuộc:

```text
QML → qt/manager.py → application/server_service.py
                         ├─ transport → application writer/processor → parsing
                         │                                      ↓
                         │                                 persistence
                         └─ device_config service → worker → Cisco session
```

| Package | Trách nhiệm |
| --- | --- |
| `domain/` | Data object thuần Python |
| `transport/` | UDP/TCP socket, client limit và newline framing |
| `parsing/` | PRI, sequence/timestamp và Cisco system-message header |
| `application/` | Server lifecycle, queue/batch, processor, resolver, retention |
| `persistence/` | Message, device-state và read-only device lookup repository |
| `device_config/` | Pure command builder, verifier, Cisco worker và service |
| `qt/` | QML adapter; không parse, chạy SQL hoặc thao tác Cisco session |

Các module cũ như `parser.py`, `repository.py`, `manager.py` vẫn là compatibility
entry point để không phá import hiện hữu. `SyslogRepository` cũng là facade tương
thích, nhưng công việc SQLite thật được giao cho ba repository chuyên trách.

Parser lưu riêng:

- `syslog_pri`, `syslog_facility` từ `<PRI>`;
- `cisco_facility`, `cisco_subfacility`, `severity`, `mnemonic` từ Cisco header;
- `sequence_number`, `device_time`, `clock_unsynchronized` từ Cisco prefix.

Message sai định dạng vẫn được lưu cùng raw text. TCP lưu frame cuối khi client
đóng mà không có newline; message size, client count và writer queue đều bounded.
Shutdown dừng receiver trước rồi flush queue. Retention mặc định 30 ngày và xóa
theo batch. Migration chỉ thêm cột/index, đồng thời ánh xạ cột `facility` cũ mà
không xóa dữ liệu.

Cấu hình Cisco chạy như transaction: kiểm tra source-interface, apply, verify
running-config, lưu startup-config, verify persistence rồi mới ghi trạng thái DB.
Cancel chỉ xóa destination do NetworkTools quản lý.

Chưa hỗ trợ RFC6587 octet-counting, TLS, RELP, multi-listener hoặc alert engine.
Chi tiết vận hành: [`../../docs/SYSTEM_LOGS.md`](../../docs/SYSTEM_LOGS.md).
Test nằm trong `tests/syslog/`, gồm cả các nhóm parsing, transport, application,
persistence và device configuration.
