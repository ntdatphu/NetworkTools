# Devices

## Phạm vi và trạng thái

Quản lý inventory, credential metadata, vai trò và import/export thiết bị. **partial**: `repository.py`, `login_service.py` và `service.py` đã sở hữu tra cứu đăng nhập và trạng thái dùng chung với terminal; CRUD/import QML còn trong facade `core/database/manager.py`.

## Contract và dữ liệu

- QML: `qml/sidebar/new_device`, `qml/panels/DevicesPanel.qml`, `qml/devices`.
- API: add/update/delete/list/import/export và signal reload của `DatabaseManager`; terminal nhận `DeviceLoginService`/`DeviceService` qua composition root. `DeviceRepository.get_role()` là contract đọc role cho policy đồng bộ running-config.

`role` là nguồn phân loại duy nhất (`rou`, `sw2`, `sw3`). `device_type` được
giữ như cột tương thích và luôn suy ra từ role (`rou → router`); startup chuẩn
hóa an toàn các bản ghi legacy đã nhận dạng được.
- Database: đọc/ghi `t01_devices`; host phải không rỗng/duy nhất, port hợp lệ; thao tác batch phải transaction/rollback.
- Worker: không áp dụng; session dùng `infrastructure.network`.

## Luồng, test và backlog

QML → facade slot → service/repository đích → SQLite. Save/Edit reload sidebar; Cancel không ghi DB. Test bootstrap/UI contract hiện bảo vệ contract. Backlog: chuyển toàn bộ inventory/YANG/import sang service hiện có, thêm `import_service.py` và các slot delegate mỏng với rollback/import validation độc lập.
