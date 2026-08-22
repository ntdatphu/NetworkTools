# Cisco Syslog Server workflow

Đối chiếu: **2026-08-22**.

Syslog được tổ chức theo các tầng độc lập:

```text
QML
 ↓
Qt manager
 ↓
SyslogServerService
 ├─ Receiver → Framer → Writer → Processor → Parser/Resolver → MessageRepository
 └─ Device config service → Cisco worker/verifier → DeviceStateRepository
```

`qt/manager.py` chỉ giữ signal/property/slot, lịch chạy tác vụ nền và chuyển đổi
QML variant. Lifecycle listener, query, retention và thao tác thiết bị đi qua
`application/server_service.py`. Các module tại cấp `features/syslog/*.py` được
giữ làm compatibility entry point cho code cũ.

## Ingestion

Receiver sở hữu một UDP hoặc TCP listener. Transport giới hạn kích thước message
và số TCP client; `LineFramer` tách stream theo LF và trả frame cuối khi peer đóng
kết nối. Writer dùng bounded queue, xử lý theo batch trên thread riêng và không
biết Cisco CLI. Khi dừng, pipeline đóng socket trước rồi chờ writer flush queue.

`SyslogProcessor` gọi parser và TTL-cached source resolver. Parser lần lượt xử lý:

1. RFC PRI (`syslog_pri`, `syslog_facility`, severity fallback).
2. Cisco sequence number và timestamp, gồm milliseconds và dấu `*` báo clock có
   thể chưa đồng bộ.
3. Cisco header `%FACILITY[-SUBFACILITY]-SEVERITY-MNEMONIC`.

Cisco severity trong message header được ưu tiên hơn PRI severity. PRI facility
không bao giờ ghi đè Cisco facility. Message malformed vẫn có `parse_status=raw`
và được lưu nguyên văn.

## Persistence và migration

SQLite được chia thành `MessageRepository`, `DeviceStateRepository` và
`DeviceLookupRepository`. Ingestion vẫn dùng `sqlite3.executemany()` và WAL.
Migration thêm các cột mới bằng `ALTER TABLE` khi cần, giữ cột compatibility
`facility`, và backfill dữ liệu cũ sang facility tương ứng. Không có bảng hoặc row
cũ nào bị xóa.

## Cisco device configuration

Command builder và verifier là pure function. Worker là thành phần duy nhất thao
tác Cisco connection. Service kiểm tra thiết bị connected/đúng OS, tìm hoặc nhận
source-interface, apply command, verify running-config, save, verify
startup-config, sau đó mới cập nhật device-state repository. Cancel chỉ gỡ đúng
destination do ứng dụng quản lý.

## Giới hạn hiện tại

TCP đang dùng newline framing; RFC6587 octet-counting và TLS chưa được bật. Module
chưa hướng tới Syslog đa hãng, RELP, SIEM hay alert engine phức tạp.
