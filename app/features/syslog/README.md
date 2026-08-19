# Syslog

Trạng thái: **implemented** cho một UDP hoặc TCP listener cục bộ.

Feature sở hữu receiver socket có giới hạn, writer queue/batch, parser, repository,
retention, settings và cấu hình destination trên Cisco IOS/IOS-XE. QML nằm tại
`UI/qml/features/syslog/` cùng sidebar `UI/qml/sidebar/syslog/`; context công khai
là `syslogManager` và `syslogSettings`.

| File | Trách nhiệm |
| --- | --- |
| `receiver.py` | UDP/TCP socket loop, framing và giới hạn client/message |
| `pipeline.py` | Start/stop atomic receiver + writer, rollback khi bind lỗi |
| `writer.py` | Queue bounded, parse và SQLite batch |
| `source_resolver.py` | Cache TTL ánh xạ source IP sang device host |
| `parser.py`, `models.py` | PRI/timestamp/Cisco mnemonic và message model |
| `repository.py`, `schema.py` | Query, pagination, device mapping và migration |
| `settings.py` | QSettings và validation bind/advertised IP/port/retention |
| `command_builder.py`, `configurator.py` | Lệnh Cisco qua session hiện hữu |
| `manager.py` | QObject điều phối, model tối đa 2.000 row và shutdown |

Message malformed vẫn được lưu cùng raw text. TCP lưu cả frame cuối khi client
đóng kết nối mà không gửi newline; số client và queue đều có giới hạn. Pause chỉ
dừng render; Clear View không xóa DB. Retention mặc định 30 ngày và xóa theo
batch. Chưa có TLS, RELP, multi-listener hoặc alert engine.

Hướng dẫn chi tiết: [`../../docs/SYSTEM_LOGS.md`](../../docs/SYSTEM_LOGS.md).
Test nằm trong `tests/syslog/` cùng UI/QML contract.

Cấu hình thiết bị chạy như một transaction trên session dùng chung: kiểm tra
source-interface, phát hiện lỗi Cisco CLI, verify running-config, lưu sang
startup-config rồi verify persistence trước khi ghi `configured = 1`. Cancel chỉ
xóa destination do NetworkTools quản lý và cũng verify/save trước khi cập nhật DB;
các thiết lập logging global khác không bị xóa hoặc restore khi chưa có snapshot.
