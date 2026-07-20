# Config backup

Trạng thái: **implemented**.

Feature lưu lịch sử `running-config` bằng Dulwich, không gọi Git CLI và không ghi lịch sử vào SQLite. Mỗi host có repository riêng tại `backup/<host>/cfg`; file `running-config.txt` là bản mới nhất và mỗi lần thu thập thành công luôn tạo một commit, kể cả nội dung không đổi.

## Luồng và API

`TerminalHelper` yêu cầu `DeviceConnector.collect_running_config()`, chuyển nội dung cho `ConfigBackupService`, rồi mới đồng bộ interface/OSPF vào DB. Adapter `save_running_config()` cũ vẫn được giữ cho interactive CLI; code mới không dùng adapter này để quyết định nơi lưu.

Facade QML ổn định `dbManager` ủy quyền ba slot sang feature này:

- `getLatestRunningConfig(host)` đọc `HEAD`.
- `getRunningConfigHistory(host, limit)` trả commit mới nhất trước, giới hạn tối đa 500.
- `getRunningConfigAtCommit(host, commitId)` chỉ đọc blob từ commit reachable, không checkout và không thay đổi thiết bị.

Repository chuẩn hóa host, chặn traversal/ký tự điều khiển, ghi file tạm rồi `os.replace()`, và dùng lock riêng cho từng host trong tiến trình. Commit dùng author `NetworkTools <networktools@localhost>`, thời gian local dạng `dd/MM/yyyy HH:mm:ss`, cùng timezone trong metadata.

## Migration

Khi chưa có commit nhưng tồn tại `<host>_running-config.txt`, service import file thành commit `Import legacy backup - ...`, sau đó đổi tên file nguồn thành `.migrated`. Migration chạy lặp lại không tạo commit import trùng và không xóa bản cũ.

Không commit `backup/`, `.git` lồng bên trong, credential hoặc cấu hình thiết bị vào repository mã nguồn.
