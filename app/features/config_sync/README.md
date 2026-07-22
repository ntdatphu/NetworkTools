# Config sync

Trạng thái: **implemented for router role `rou`**.

Feature này tích hợp pipeline đọc `running-config` vào app theo luồng:

1. `TerminalHelper` thu thập cấu hình từ thiết bị.
2. `ConfigBackupService` ghi snapshot và so sánh blob mới với `HEAD` bằng Dulwich.
3. `ConfigSyncService` chỉ gọi parser/writer SQLite khi role trong `t01_devices` là `rou` và snapshot có `changed = true`.

Thiết bị `sw2`, `sw3` và role khác vẫn có lịch sử backup, nhưng không chạy pipeline đồng bộ router. Snapshot không đổi vẫn tạo commit phục vụ audit, song không ghi lại database. Parser và transaction SQLite hiện được tái sử dụng từ `features.devices.sync_state`; service này chỉ sở hữu policy role/change, không sở hữu kết nối thiết bị, Git repository hoặc QML.
