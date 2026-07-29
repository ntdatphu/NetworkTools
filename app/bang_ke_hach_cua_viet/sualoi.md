## Kết luận đề xuất

Không nên chỉ đổi:

```text
-1 → "delete"
 0 → "pending"
 1 → "success"
```

vì trong dự án hiện tại, cột `success` đang mang **hai ý nghĩa hoàn toàn khác nhau**:

1. Trong `t01_devices`, `success` biểu diễn **trạng thái kết nối/session của thiết bị**.
2. Trong các bảng Routing, DHCP, ACL, NAT…, `success` biểu diễn **trạng thái đồng bộ cấu hình**.

Schema hiện vẫn khai báo `t01_devices.success INTEGER DEFAULT 0`.  Trong `DeviceRepository`, `success = 0` được gọi là `waiting`, còn `success = 1` được xem là thiết bị đang kết nối; khi ứng dụng đóng, các thiết bị `success = 1` được reset về `0`.

Trong khi đó, tài liệu schema quy định với các bản ghi cấu hình:

* `-1`: chờ xóa trên thiết bị.
* `0`: chờ push.
* `1`: đã đồng bộ.
* `3`: bỏ qua trong một số luồng đặc biệt.

Vì vậy, phương án chính xác nhất là **đổi cả tên cột lẫn giá trị**.

---

# 1. Bộ trạng thái mới đề xuất

## 1.1. Trạng thái thiết bị

Đổi:

```sql
t01_devices.success
```

thành:

```sql
t01_devices.connection_status
```

| Giá trị cũ | Giá trị mới    | Ý nghĩa chính xác                                        |
| ---------: | -------------- | -------------------------------------------------------- |
|       `-1` | `disconnected` | Thiết bị đã ngắt kết nối hoặc session đã đóng            |
|        `0` | `waiting`      | Chưa kết nối, đang chờ người dùng hoặc tác vụ mở session |
|        `1` | `connected`    | Đã kết nối và có session hoạt động                       |

Không nên dùng từ `success` cho thiết bị vì thiết bị không phải “thành công”; nó đang ở một **trạng thái kết nối**.

Schema đề xuất:

```sql
connection_status TEXT NOT NULL DEFAULT 'waiting'
    CHECK (
        connection_status IN (
            'disconnected',
            'waiting',
            'connected'
        )
    )
```

## 1.2. Trạng thái đồng bộ cấu hình

Đổi cột `success` trong các bảng Routing, DHCP, ACL, NAT, Interface… thành:

```sql
sync_status
```

| Giá trị cũ | Giá trị mới      | Ý nghĩa chính xác                                   |
| ---------: | ---------------- | --------------------------------------------------- |
|       `-1` | `pending_delete` | Chờ gửi lệnh `no ...`, sau đó xóa row khỏi DB       |
|        `0` | `pending_apply`  | Cấu hình mới hoặc đã sửa, đang chờ push             |
|        `1` | `synchronized`   | Cấu hình DB đã được áp dụng thành công lên thiết bị |
|        `3` | `skipped`        | Tác vụ được chủ động bỏ qua theo nghiệp vụ          |

Schema đề xuất:

```sql
sync_status TEXT NOT NULL DEFAULT 'pending_apply'
    CHECK (
        sync_status IN (
            'pending_apply',
            'pending_delete',
            'synchronized',
            'skipped'
        )
    )
```

Tên `pending_apply` chính xác hơn `pending` vì nó nói rõ bản ghi đang chờ **apply lên thiết bị**.

Tên `synchronized` chính xác hơn `success` hoặc `done` vì nó xác nhận trạng thái giữa DB và thiết bị đã đồng bộ.

---

# 2. Không nên dùng một enum chung

Không nên tạo:

```python
class SuccessStatus(...)
```

vì sẽ tiếp tục trộn hai miền nghiệp vụ.

Nên tạo hai enum riêng:

```python
from enum import StrEnum


class ConnectionStatus(StrEnum):
    DISCONNECTED = "disconnected"
    WAITING = "waiting"
    CONNECTED = "connected"


class SyncStatus(StrEnum):
    PENDING_APPLY = "pending_apply"
    PENDING_DELETE = "pending_delete"
    SYNCHRONIZED = "synchronized"
    SKIPPED = "skipped"
```

Nếu muốn chuẩn bị cho trạng thái lỗi về sau:

```python
class SyncStatus(StrEnum):
    PENDING_APPLY = "pending_apply"
    APPLYING = "applying"
    PENDING_DELETE = "pending_delete"
    DELETING = "deleting"
    SYNCHRONIZED = "synchronized"
    FAILED = "failed"
    SKIPPED = "skipped"
```

Tuy nhiên, trong đợt migration đầu tiên, nên chỉ chuyển đúng các trạng thái đang tồn tại. Không nên thêm `applying`, `deleting`, `failed` nếu worker hiện chưa lưu những trạng thái này.

---

# 3. Bảng kế hoạch triển khai chi tiết

| Giai đoạn | Hạng mục              | Công việc cụ thể                                                                       | File/khu vực dự kiến                                     | Kết quả đầu ra                             |
| --------- | --------------------- | -------------------------------------------------------------------------------------- | -------------------------------------------------------- | ------------------------------------------ |
| 1         | Khóa quy ước          | Chốt hai miền trạng thái: `connection_status` và `sync_status`                         | `app/SCHEMA_LOGIC.md`                                    | Không còn khái niệm `success` dùng chung   |
| 1         | Chốt mapping thiết bị | `-1 → disconnected`, `0 → waiting`, `1 → connected`                                    | Tài liệu kiến trúc                                       | Mapping chính thức cho `t01_devices`       |
| 1         | Chốt mapping cấu hình | `-1 → pending_delete`, `0 → pending_apply`, `1 → synchronized`, `3 → skipped`          | Tài liệu schema                                          | Mapping chính thức cho bảng cấu hình       |
| 2         | Tạo enum              | Tạo `ConnectionStatus` và `SyncStatus` dưới dạng `StrEnum`                             | Ví dụ `app/domain/status.py` hoặc `app/shared/status.py` | Python không còn dùng số magic             |
| 2         | Tạo hằng QML          | Export các chuỗi trạng thái cho QML hoặc dùng singleton                                | `app/UI/qml/shared/`                                     | QML không viết chuỗi rải rác               |
| 3         | Migration DB thiết bị | Thêm `connection_status TEXT`, copy dữ liệu từ `success`, kiểm tra dữ liệu, xóa cột cũ | Migration SQLite                                         | `t01_devices` dùng trạng thái chữ          |
| 3         | Migration DB cấu hình | Với từng bảng có `success`, thêm `sync_status`, chuyển giá trị, rebuild table nếu cần  | Các schema Routing, DHCP, ACL, NAT…                      | Mọi bảng cấu hình dùng `sync_status`       |
| 3         | Ràng buộc dữ liệu     | Thêm `NOT NULL`, `DEFAULT`, `CHECK`                                                    | Các file `.sql`                                          | DB từ chối trạng thái không hợp lệ         |
| 3         | Kiểm tra dữ liệu lạ   | Tìm giá trị ngoài `-1,0,1,3` trước khi migration                                       | Script migration                                         | Không mất dữ liệu do mapping thiếu         |
| 4         | Repository thiết bị   | Đổi query đọc/ghi `success` thành `connection_status`                                  | `features/devices/repository.py`                         | Repository thiết bị dùng từ nghiệp vụ      |
| 4         | Service thiết bị      | Đổi `update_flag()` sang API chuyên biệt                                               | `features/devices/service.py`                            | Không còn truyền tên cột động              |
| 4         | Reset trạng thái      | Đổi reset thành `connection_status = 'waiting'`                                        | Device repository/service                                | Logic reset rõ ràng                        |
| 5         | Repository cấu hình   | Đổi mọi query `success = ?` thành `sync_status = ?`                                    | Routing/DHCP/ACL/NAT/Interface repositories              | SQL dùng trạng thái chữ                    |
| 5         | Logic replace         | Row cũ chuyển `pending_delete`, row mới `pending_apply`                                | Save/update services                                     | Giữ đúng vòng đời replace                  |
| 5         | Dispatcher            | Sau push thành công: `pending_apply → synchronized`; `pending_delete → DELETE`         | Các dispatcher                                           | Giữ nguyên nghiệp vụ hiện tại              |
| 5         | Worker                | Đổi điều kiện lấy task pending                                                         | Routing/DHCP/ACL/NAT workers                             | Worker không phụ thuộc magic number        |
| 6         | QML thiết bị          | Đổi điều kiện `success === 1` thành `connectionStatus === "connected"`                 | Sidebar, device tabs, context menu                       | UI đọc được như câu tiếng Anh              |
| 6         | QML cấu hình          | Đổi điều kiện `success === 0/1/-1` thành trạng thái chữ                                | Các form Routing/DHCP/ACL/NAT                            | Không còn số trạng thái trong QML          |
| 6         | Model role            | Đổi tên role expose sang QML                                                           | Python/C++ models                                        | `connectionStatus`, `syncStatus` rõ nghĩa  |
| 7         | Compatibility layer   | Tạm thời hỗ trợ đọc cả cột mới và cũ nếu cần                                           | Database adapter                                         | Có thể rollback trong giai đoạn chuyển đổi |
| 7         | Logging               | Log trạng thái bằng tên đầy đủ                                                         | Worker, dispatcher                                       | Log dễ đọc, dễ debug                       |
| 8         | Unit test             | Test mapping tất cả giá trị cũ sang mới                                                | `app/tests/`                                             | Migration có kiểm chứng                    |
| 8         | Integration test      | Test save, update, delete, push thành công, push thất bại                              | Routing/DHCP/ACL/NAT tests                               | Xác nhận vòng đời dữ liệu                  |
| 8         | UI test               | Kiểm tra danh sách host connected, waiting, disconnected                               | QML/manual test                                          | UI không lọc sai host                      |
| 9         | Cleanup               | Xóa compatibility code và mọi tham chiếu `success` cũ                                  | Toàn bộ `app/`                                           | Hoàn thành migration                       |
| 9         | Documentation         | Cập nhật schema logic và tài liệu developer                                            | `SCHEMA_LOGIC.md`, README liên quan                      | Thành viên mới hiểu trạng thái             |

---

# 4. Kế hoạch theo từng commit

Nên chia thành nhiều commit nhỏ, không thay toàn bộ trong một commit.

| Commit | Nội dung                                                   | Phạm vi                                  |
| ------ | ---------------------------------------------------------- | ---------------------------------------- |
| 1      | `docs: define connection and synchronization statuses`     | Cập nhật `SCHEMA_LOGIC.md`, chốt mapping |
| 2      | `refactor: add typed status enums`                         | Thêm `ConnectionStatus`, `SyncStatus`    |
| 3      | `db: migrate device connection status to text`             | Chỉ xử lý `t01_devices`                  |
| 4      | `refactor: migrate device repository to connection_status` | Device repository/service                |
| 5      | `ui: migrate device connection status bindings`            | Sidebar, DeviceTabs, context menu        |
| 6      | `db: migrate configuration sync statuses to text`          | Các bảng cấu hình                        |
| 7      | `refactor: migrate routing sync status`                    | Static, OSPF, EIGRP                      |
| 8      | `refactor: migrate dhcp sync status`                       | Pool, helper, excluded                   |
| 9      | `refactor: migrate acl and nat sync status`                | ACL, NAT                                 |
| 10     | `refactor: migrate interface and switching sync status`    | Interface, SVI, switching                |
| 11     | `test: cover textual status lifecycle`                     | Unit và integration tests                |
| 12     | `cleanup: remove legacy numeric success states`            | Xóa code tương thích                     |

Cách chia này giúp khi phát hiện lỗi ở một module, có thể revert riêng module đó mà không phá toàn bộ migration.

---

# 5. Migration cho `t01_devices`

SQLite không phải lúc nào cũng hỗ trợ thay đổi constraint trực tiếp thuận tiện. Phương án an toàn là tạo bảng mới.

```sql
PRAGMA foreign_keys = OFF;

BEGIN TRANSACTION;

CREATE TABLE t01_devices_new (
    host              TEXT PRIMARY KEY,
    device_name       TEXT,
    method            TEXT,
    portnumber        INTEGER,
    username          TEXT,
    password          TEXT,
    os                TEXT,
    role              TEXT,
    device_type       TEXT DEFAULT 'unknown',

    connection_status TEXT NOT NULL DEFAULT 'waiting'
        CHECK (
            connection_status IN (
                'disconnected',
                'waiting',
                'connected'
            )
        ),

    dev               INTEGER NOT NULL DEFAULT 0
        CHECK (dev IN (0, 1))
);

INSERT INTO t01_devices_new (
    host,
    device_name,
    method,
    portnumber,
    username,
    password,
    os,
    role,
    device_type,
    connection_status,
    dev
)
SELECT
    host,
    device_name,
    method,
    portnumber,
    username,
    password,
    os,
    role,
    device_type,
    CASE success
        WHEN -1 THEN 'disconnected'
        WHEN 0 THEN 'waiting'
        WHEN 1 THEN 'connected'
        ELSE 'waiting'
    END,
    COALESCE(dev, 0)
FROM t01_devices;

DROP TABLE t01_devices;

ALTER TABLE t01_devices_new
RENAME TO t01_devices;

COMMIT;

PRAGMA foreign_keys = ON;
```

Trước khi migration, phải chạy:

```sql
SELECT success, COUNT(*)
FROM t01_devices
GROUP BY success;
```

Nếu có giá trị khác `-1`, `0`, `1`, không nên tự động map về `waiting` ngay. Nên ghi log và dừng migration để kiểm tra.

---

# 6. Migration mẫu cho bảng cấu hình

Ví dụ bảng `static_routes`:

```sql
CREATE TABLE static_routes_new (
    id INTEGER PRIMARY KEY,
    host TEXT NOT NULL,

    -- Các cột cấu hình khác...

    sync_status TEXT NOT NULL DEFAULT 'pending_apply'
        CHECK (
            sync_status IN (
                'pending_apply',
                'pending_delete',
                'synchronized',
                'skipped'
            )
        )
);

INSERT INTO static_routes_new (
    id,
    host,
    sync_status
)
SELECT
    id,
    host,
    CASE success
        WHEN -1 THEN 'pending_delete'
        WHEN 0 THEN 'pending_apply'
        WHEN 1 THEN 'synchronized'
        WHEN 3 THEN 'skipped'
        ELSE 'pending_apply'
    END
FROM static_routes;
```

Với dữ liệu cấu hình, cũng cần kiểm tra trước:

```sql
SELECT success, COUNT(*)
FROM static_routes
GROUP BY success;
```

---

# 7. Refactor `DeviceRepository`

Hiện `update_flag()` nhận tên cột động và ép tất cả giá trị về `int`.  Sau migration, thiết kế này không còn phù hợp.

Không nên giữ:

```python
update_flag(host, "success", 1)
```

Nên tách thành API rõ nghiệp vụ:

```python
from domain.status import ConnectionStatus


def update_connection_status(
    self,
    host: str,
    status: ConnectionStatus,
) -> bool:
    with closing(self._connect()) as connection:
        cursor = connection.execute(
            """
            UPDATE t01_devices
            SET connection_status = ?
            WHERE host = ?;
            """,
            (status.value, host.strip()),
        )
        connection.commit()
        return cursor.rowcount > 0
```

Reset:

```python
def reset_to_waiting(self, host: str) -> bool:
    with closing(self._connect()) as connection:
        cursor = connection.execute(
            """
            UPDATE t01_devices
            SET connection_status = ?,
                dev = 0
            WHERE host = ?;
            """,
            (
                ConnectionStatus.WAITING.value,
                host.strip(),
            ),
        )
        connection.commit()
        return cursor.rowcount > 0
```

Shutdown:

```python
def reset_connected_to_waiting(self) -> int:
    with closing(self._connect()) as connection:
        cursor = connection.execute(
            """
            UPDATE t01_devices
            SET connection_status = ?
            WHERE connection_status = ?;
            """,
            (
                ConnectionStatus.WAITING.value,
                ConnectionStatus.CONNECTED.value,
            ),
        )
        connection.commit()
        return max(cursor.rowcount, 0)
```

---

# 8. Refactor logic đồng bộ cấu hình

Vòng đời hiện tại trong tài liệu là:

```text
INSERT mới        → 0
Push thành công   → 1
Đánh dấu xóa      → -1
Worker xóa xong   → DELETE row
```

Sau migration:

```text
INSERT mới
    → pending_apply

Push thành công
    → synchronized

Người dùng sửa theo cơ chế replace
    → row cũ: pending_delete
    → row mới: pending_apply

Worker xử lý row pending_delete thành công
    → DELETE row khỏi DB
```

Query cũ:

```sql
SELECT *
FROM static_routes
WHERE success IN (0, -1);
```

Query mới:

```sql
SELECT *
FROM static_routes
WHERE sync_status IN (
    'pending_apply',
    'pending_delete'
);
```

Update cũ:

```sql
UPDATE static_routes
SET success = 1
WHERE id = ?;
```

Update mới:

```sql
UPDATE static_routes
SET sync_status = 'synchronized'
WHERE id = ?;
```

Delete dispatcher:

```python
if row.sync_status == SyncStatus.PENDING_DELETE:
    repository.delete(row.id)
elif row.sync_status == SyncStatus.PENDING_APPLY:
    repository.mark_synchronized(row.id)
```

---

# 9. Những nơi phải rà trong `app`

Từ cấu trúc hiện tại, ít nhất cần rà các nhóm sau:

| Nhóm                     | Kiểu sử dụng cần tìm                                  |
| ------------------------ | ----------------------------------------------------- |
| `features/devices`       | `success = 0`, `success = 1`, reset session, lọc host |
| `core/database`          | Query danh sách thiết bị theo trạng thái              |
| `core/terminal.py`       | Cập nhật trạng thái khi connect/disconnect            |
| `features/routing`       | Static Route, OSPF, EIGRP pending/push/delete         |
| `features/dhcp`          | Pool, helper, excluded address                        |
| `features/acl`           | ACL cha, rule con, binding                            |
| `features/nat`           | NAT DB, NAT ACL, route-map, interface                 |
| `features/interfaces`    | Load, save, collect, push                             |
| `features/switching`     | SVI, switchport và View & Push                        |
| `features/syslog`        | Lọc thiết bị đang connected                           |
| `core/view_push.py`      | Kết quả push và cập nhật DB                           |
| `UI/qml/sidebar/devices` | Badge, context menu, danh sách connected              |
| `UI/qml/features`        | Điều kiện bật Save/Push, trạng thái row               |
| `tests`                  | Các fixture đang insert `success` số                  |
| `SCHEMA_LOGIC.md`        | Toàn bộ tài liệu trạng thái                           |

Tài liệu hiện liệt kê một số lượng lớn bảng Routing, DHCP, ACL và NAT đang xử lý chủ yếu dựa vào `success`, vì vậy migration phải được thực hiện theo module.

---

# 10. Chiến lược tương thích tạm thời

Để tránh đổi DB và code cùng lúc rồi ứng dụng không chạy, có thể dùng giai đoạn chuyển tiếp.

## Giai đoạn A: dual-read

Repository đọc ưu tiên cột mới:

```python
def normalize_sync_status(value: object) -> SyncStatus:
    mapping = {
        -1: SyncStatus.PENDING_DELETE,
        0: SyncStatus.PENDING_APPLY,
        1: SyncStatus.SYNCHRONIZED,
        3: SyncStatus.SKIPPED,
        "pending_delete": SyncStatus.PENDING_DELETE,
        "pending_apply": SyncStatus.PENDING_APPLY,
        "synchronized": SyncStatus.SYNCHRONIZED,
        "skipped": SyncStatus.SKIPPED,
    }

    try:
        return mapping[value]
    except KeyError as exc:
        raise ValueError(f"Unknown sync status: {value!r}") from exc
```

## Giai đoạn B: dual-write

Trong một phiên bản ngắn hạn:

```sql
UPDATE static_routes
SET
    success = 1,
    sync_status = 'synchronized'
WHERE id = ?;
```

## Giai đoạn C: chỉ dùng cột mới

Sau khi test toàn bộ:

* Ngừng ghi `success`.
* Xóa `success` khỏi schema.
* Xóa compatibility mapping.
* Thêm test đảm bảo chuỗi `"success"` không còn xuất hiện với nghĩa trạng thái DB.

Vì dự án hiện còn trong quá trình phát triển, có thể bỏ dual-write và migration trực tiếp nếu database runtime có thể build lại từ schema. Nhưng dữ liệu người dùng hiện tại phải được backup trước.

---

# 11. Bộ test bắt buộc

| Test                  | Dữ liệu đầu vào                | Kết quả mong đợi                       |
| --------------------- | ------------------------------ | -------------------------------------- |
| Device migration `-1` | `success = -1`                 | `connection_status = disconnected`     |
| Device migration `0`  | `success = 0`                  | `connection_status = waiting`          |
| Device migration `1`  | `success = 1`                  | `connection_status = connected`        |
| Sync migration `-1`   | `success = -1`                 | `sync_status = pending_delete`         |
| Sync migration `0`    | `success = 0`                  | `sync_status = pending_apply`          |
| Sync migration `1`    | `success = 1`                  | `sync_status = synchronized`           |
| Sync migration `3`    | `success = 3`                  | `sync_status = skipped`                |
| Giá trị không hợp lệ  | `success = 2`                  | Migration báo lỗi hoặc ghi rõ ngoại lệ |
| Save mới              | Tạo cấu hình                   | Row là `pending_apply`                 |
| Push thành công       | Worker report success          | Row thành `synchronized`               |
| Push thất bại         | Worker report failed           | Row giữ `pending_apply`                |
| Delete request        | Người dùng xóa cấu hình        | Row thành `pending_delete`             |
| Delete thành công     | Worker gửi `no ...` thành công | Row bị xóa                             |
| Delete thất bại       | Worker lỗi                     | Row giữ `pending_delete`               |
| App shutdown          | Device `connected`             | Chuyển thành `waiting`                 |
| Dev mode              | Push mô phỏng thành công       | `pending_apply → synchronized`         |
| Mixed batch           | Host dev và host thật          | Trạng thái từng host cập nhật độc lập  |

Tài liệu hiện đã có test cho dev mode, bao gồm việc chuyển `success = 0` sang `1` và xóa row `success = -1`; các test này cần được đổi sang `pending_apply`, `synchronized` và `pending_delete`.

---

# 12. Tiêu chí hoàn thành

Migration chỉ được xem là hoàn thành khi:

* Không còn cột `success` trong schema runtime của `app`.
* Không còn SQL dạng `success = -1`, `success = 0`, `success = 1`.
* Không còn Python/QML so sánh trạng thái bằng số.
* `t01_devices` chỉ sử dụng `connection_status`.
* Các bảng cấu hình chỉ sử dụng `sync_status`.
* Enum là nguồn định nghĩa duy nhất trong Python.
* QML sử dụng tên trạng thái rõ ràng.
* Toàn bộ test Save, Push, Delete, Dev mode và shutdown đều đạt.
* `SCHEMA_LOGIC.md` được cập nhật cùng commit cuối.

## Bộ tên cuối cùng nên dùng

```text
Thiết bị:
disconnected
waiting
connected

Đồng bộ cấu hình:
pending_apply
pending_delete
synchronized
skipped
```

Đây là bộ tên rõ nghĩa nhất với logic đang tồn tại tại commit `da60c91f3a9e7d97fc363b0f3e3973178d464636`.
