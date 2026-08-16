# Syslog

Trạng thái: **implemented** cho một UDP hoặc TCP listener cục bộ.

Feature sở hữu receiver socket có giới hạn, writer queue/batch, parser, repository,
retention, settings và cấu hình destination trên Cisco IOS/IOS-XE. QML nằm tại
`UI/qml/features/syslog/` cùng sidebar `UI/qml/sidebar/syslog/`; context công khai
là `syslogManager` và `syslogSettings`.

| File | Trách nhiệm |
| --- | --- |
| `receiver.py` | UDP/TCP socket thread và lifecycle |
| `writer.py` | Queue bounded, parse và SQLite batch |
| `parser.py`, `models.py` | PRI/timestamp/Cisco mnemonic và message model |
| `repository.py`, `schema.py` | Query, pagination, device mapping và migration |
| `settings.py` | QSettings và validation bind/advertised IP/port/retention |
| `command_builder.py`, `configurator.py` | Lệnh Cisco qua session hiện hữu |
| `manager.py` | QObject điều phối, model tối đa 2.000 row và shutdown |

Message malformed vẫn được lưu cùng raw text. Pause chỉ dừng render; Clear View
không xóa DB. Retention mặc định 30 ngày và xóa theo batch. Chưa có TLS, RELP,
multi-listener hoặc alert engine.

Hướng dẫn chi tiết: [`../../../docs/SYSTEM_LOGS.md`](../../../docs/SYSTEM_LOGS.md).
Test nằm trong `tests/syslog/` cùng UI/QML contract.
