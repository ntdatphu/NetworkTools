# NetworkTools database

`app/database/` là nguồn duy nhất cho schema; hai SQLite database runtime nằm cạnh
`app/main.py`. Module UI/backend/worker không được tự tạo bảng, chạy SQL legacy
hoặc suy ra đường dẫn từ current working directory.

## Database chính thức

| Mục đích | Nguồn module | SQL tổng hợp | Database runtime |
|---|---|---|---|
| Cấu hình thiết bị, interface, DHCP, Routing, ACL/NAT, L2, VRF | `schema/*.sql` | `device_network.sql` | `app/device_network.db` |
| Dữ liệu collector | `info_collected/*.sql` | `info_collected.sql` | `app/info_collected.db` |

Luồng build tường minh:

```text
schema/*.sql → device_network.sql → build_databases.py → device_network.db
info_collected/*.sql → info_collected.sql → build_databases.py → info_collected.db
```

Startup dùng cùng modular source để tạo riêng file `.db` còn thiếu nhưng **không
ghi lại hai aggregate SQL được version-control**. Chỉ lệnh
`database/build_databases.py` tường minh mới đồng thời sinh aggregate và runtime
database. Quy tắc này ngăn lần khởi động đầu sau merge làm dirty worktree hoặc lấy
modular schema lệch để ghi đè source đã review.

Chỉ sửa các file module SQL. `device_network.sql`, `info_collected.sql` và hai file `.db` là output được sinh lại bởi builder.

## Build

Linux/Fedora, chạy từ bất kỳ thư mục làm việc nào:

```bash
python3 /path/to/app/database/build_databases.py
```

Windows PowerShell:

```powershell
py C:\path\to\app\database\build_databases.py
```

Nếu không có `py`, dùng `python`. Builder đọc/ghi UTF-8, sắp xếp tự nhiên các file `NN_*.sql`, tạo file tạm, bật foreign key, chạy `integrity_check` và `foreign_key_check`, đóng connection rồi mới thay output. Vì vậy không có logic build riêng cho shell/PowerShell.

Builder không phụ thuộc current working directory. Hai file SQL tổng hợp nằm trong
`app/database/`; hai file `.db` runtime luôn nằm trong `app/`, cạnh `main.py`.

Khi ứng dụng khởi động, nó kiểm tra cả hai file `.db`. File nào còn thiếu sẽ được
builder tự tạo im lặng từ schema tương ứng. Database đã tồn tại không bị build lại
hoặc ghi đè, hai aggregate SQL cũng không bị sửa, nhờ đó dữ liệu người dùng và
worktree được giữ nguyên.

## Runtime và quy tắc đường dẫn

Đường dẫn chuẩn nằm trong `core/database_paths.py`, được suy ra từ `Path(__file__).resolve()`:

- `DEVICE_NETWORK_DB = app/device_network.db`;
- `INFO_COLLECTED_DB = app/info_collected.db`;
- hai đường dẫn SQL cũng trỏ vào `app/database/`.

Startup gọi builder để tạo đúng database còn thiếu trước khi khởi tạo
`DatabaseManager`. `DatabaseManager` sau đó vẫn chỉ kiểm tra file và các bảng bắt
buộc; nó không gọi `sqlite3.connect()` để vô tình sinh DB rỗng và không chạy
`CREATE TABLE`/migration. Mỗi connection runtime bật `foreign_keys`, có timeout
ngắn và được đóng tại module/thread đã mở nó.

`network_code/database_paths.json` chỉ truyền đường dẫn chuẩn cho worker cũ; fallback
của worker cũng trỏ vào DB trong `app/`, không còn trỏ
`UI/main_numbered_tables.sql`.

## Migration

Kết luận: **Loại bỏ migrations**.

Repository không có migration runner, schema-version table hay `PRAGMA user_version`; startup và builder cũng không gọi migration. `schema/04_routing.sql` đã chứa schema đích hợp nhất và database được build mới. File `migrations/001_merge_routing_interface_settings.sql` rời rạc vì vậy đã bị loại bỏ để không tạo một cơ chế nâng cấp giả.

Nếu sản phẩm sau này cần bảo toàn database người dùng qua nhiều phiên bản, phải bổ sung một migration system hoàn chỉnh (version, thứ tự, transaction, rollback, idempotency và test trên bản sao dữ liệu) trước khi thêm migration mới. Không chạy SQL migration cũ thủ công trên DB hiện tại.

## Routing Save/Load/Push

Luồng Save/Load:

```text
QML Form → DatabaseManager slot → validation/normalization
         → backend/route service → SQLite transaction
SQLite → backend/route loader → QVariant model → QML Form
```

OSPF/EIGRP per-interface chỉ dùng `t04_router_iface_ospf` và `t04_router_iface_eigrp`. UI tiếp tục trao đổi `interface_name`; backend ánh xạ bắt buộc `(host, interface_name)` sang `t02_interface_name.iface_id`. Save cha/con nằm trong cùng transaction, load JOIN tên interface, và unique `(iface_id, process_id)` ngăn Save lặp tạo row trùng.

Push Routing thực hiện:

1. kiểm tra host và database;
2. đọc pending theo đúng host/module;
3. worker xác minh `dev` theo fail-closed;
4. `dev = 1` mô phỏng thành công mà không mở session thật; `dev = 0` dùng session thật;
5. không push khi không có task/lệnh pending;
6. chỉ khi report thành công mới cập nhật/xóa các row được tracking;
7. report thất bại giữ `success <= 0` và pending để thử lại.

`dev` không phải username/role và không tự reset sau push. `success` dùng `-1` (chờ xóa), `0` (chờ thêm/cập nhật), `1` (đã áp dụng). `action_Cfg` là chuỗi bit của EIGRP process và phải giữ nguyên kiểu TEXT 7 bit.

## Kiểm tra database

```bash
sqlite3 device_network.db "PRAGMA integrity_check; PRAGMA foreign_key_check;"
sqlite3 info_collected.db "PRAGMA integrity_check; PRAGMA foreign_key_check;"
sqlite3 device_network.db ".tables"
```

Kết quả `integrity_check` hợp lệ là `ok`; `foreign_key_check` không trả row.

## Backup và phục hồi

Đóng ứng dụng/DB Browser trước khi sao lưu để tránh lock trên Windows. Dùng SQLite backup API hoặc copy `device_network.db` khi không còn connection mở. Không chạy builder lên database chứa dữ liệu cần giữ: builder tạo database mới và thay output sau khi validation thành công. Luôn backup trước khi rebuild hoặc thử chuyển đổi dữ liệu.

Các snapshot legacy như `UI/main.sql`, `UI/main_numbered_tables.sql`, `network_code/sql/` và `database/main_numbered_tables new.sql` không phải nguồn runtime và không được dùng để khởi tạo DB.
