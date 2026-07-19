# Devices

## Phạm vi và trạng thái

Quản lý inventory, credential metadata, vai trò và import/export thiết bị. **partial**: public QML contract đang ổn định qua `dbManager`, nhưng CRUD còn trong facade `core/database.py`.

## Contract và dữ liệu

- QML: `qml/sidebar/new_device`, `qml/panels/DevicesPanel.qml`, `qml/devices`.
- API: add/update/delete/list/import/export và signal reload của `DatabaseManager`.
- Database: đọc/ghi `t01_devices`; host phải không rỗng/duy nhất, port hợp lệ; thao tác batch phải transaction/rollback.
- Worker: không áp dụng; session dùng `infrastructure.network`.

## Luồng, test và backlog

QML → facade slot → service/repository đích → SQLite. Save/Edit reload sidebar; Cancel không ghi DB. Test bootstrap/UI contract hiện bảo vệ contract. Backlog: tách `repository.py`, `service.py`, `slots.py`; thêm rollback/import validation độc lập.
