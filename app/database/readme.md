````markdown
# NetworkTools SQLite Database Builder

Dự án chia cơ sở dữ liệu thành hai file SQLite độc lập:

| Nhóm | SQL tổng hợp | SQLite database |
|---|---|---|
| Cấu hình thiết bị và mạng | `device_network.sql` | `device_network.db` |
| Dữ liệu thu thập từ thiết bị | `info_collected.sql` | `info_collected.db` |

Các file tổng hợp và database được tạo tự động từ những file SQL nhỏ trong hai thư mục:

```text
schema/
info_collected/
````

Không chỉnh sửa trực tiếp:

```text
device_network.sql
info_collected.sql
device_network.db
info_collected.db
```

Hãy chỉnh sửa các file SQL nguồn rồi chạy lại script build.

---

## 1. Cấu trúc thư mục

```text
.
├── build_databases.ps1
├── build_databases.sh
├── README.md
├── schema
│   ├── 01_core_devices.sql
│   ├── 02_interface_router_l3.sql
│   ├── 03_dhcp_helper.sql
│   ├── 04_routing.sql
│   ├── 05_security_nat.sql
│   ├── 06_l2_switching.sql
│   └── 07_vrf.sql
└── info_collected
    ├── 08_info_routing_table.sql
    ├── 09_info_dhcp.sql
    ├── 10_info_acl.sql
    └── 11_info_nat.sql
```

Sau khi build:

```text
.
├── device_network.sql
├── device_network.db
├── info_collected.sql
└── info_collected.db
```

---

## 2. Nguyên tắc phân chia database

### `device_network.db`

Chứa dữ liệu cấu hình do ứng dụng quản lý và có thể đẩy xuống thiết bị:

* thiết bị;
* thông tin đăng nhập;
* interface;
* DHCP;
* routing;
* ACL;
* NAT;
* switching;
* VRF;
* trạng thái `success`;
* cờ `action_Cfg`.

Nguồn SQL:

```text
schema/*.sql
```

Kết quả:

```text
device_network.sql
device_network.db
```

### `info_collected.db`

Chứa dữ liệu collector đọc từ thiết bị:

* routing table thực tế;
* DHCP bindings hoặc trạng thái DHCP;
* ACL thực tế;
* NAT translations;
* NAT statistics;
* các snapshot và output parser.

Nhóm này là dữ liệu read-only từ góc độ cấu hình và không dùng:

```text
success
action_Cfg
```

Nguồn SQL:

```text
info_collected/*.sql
```

Kết quả:

```text
info_collected.sql
info_collected.db
```

---

## 3. Thứ tự ghép SQL

Các file được ghép theo thứ tự tự nhiên của tên file:

```text
01_core_devices.sql
02_interface_router_l3.sql
...
09_info_dhcp.sql
10_info_acl.sql
11_info_nat.sql
```

Script hỗ trợ:

* tên file chứa khoảng trắng;
* số thứ tự lớn hơn 9;
* tự động nhận file `.sql` mới;
* không cần sửa script khi thêm file;
* chỉ đọc file `.sql` trực tiếp trong thư mục;
* không đọc thư mục con.

Ví dụ thêm file mới:

```text
info_collected/12_info_ospf_neighbors.sql
```

Lần build tiếp theo, file này tự động được ghép sau:

```text
11_info_nat.sql
```

Nên sử dụng tiền tố có ít nhất hai chữ số:

```text
01_
02_
03_
...
10_
11_
12_
```

---

## 4. Yêu cầu phần mềm

Cần cài SQLite command-line interface:

```text
sqlite3
```

### Fedora

```bash
sudo dnf install sqlite
```

Kiểm tra:

```bash
sqlite3 --version
```

### Ubuntu hoặc Debian

```bash
sudo apt update
sudo apt install sqlite3
```

### Windows

Cài `sqlite3.exe` và thêm thư mục chứa nó vào biến môi trường `PATH`.

Kiểm tra trong PowerShell:

```powershell
sqlite3 --version
```

---

## 5. Build trên Linux

Cấp quyền thực thi:

```bash
chmod +x build_databases.sh
```

Chạy:

```bash
./build_databases.sh
```

Script sẽ lần lượt:

1. kiểm tra `sqlite3`;
2. kiểm tra thư mục `schema`;
3. ghép `schema/*.sql` thành `device_network.sql`;
4. thử tạo database tạm;
5. chạy `PRAGMA integrity_check`;
6. thay database cũ bằng `device_network.db` mới;
7. ghép `info_collected/*.sql` thành `info_collected.sql`;
8. thử tạo database tạm;
9. chạy `PRAGMA integrity_check`;
10. thay database cũ bằng `info_collected.db` mới.

Nếu SQL lỗi, database cũ không bị thay thế.

---

## 6. Build trên Windows PowerShell

### PowerShell 7

```powershell
pwsh .\build_databases.ps1
```

### Windows PowerShell

Cho phép chạy script trong phiên hiện tại:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
```

Sau đó chạy:

```powershell
.\build_databases.ps1
```

Hoặc chạy trực tiếp:

```powershell
powershell -ExecutionPolicy Bypass -File .\build_databases.ps1
```

Script PowerShell ghi file SQL bằng UTF-8 không BOM.

---

## 7. Kết quả build

Khi thành công, script tạo bốn file:

```text
device_network.sql
device_network.db
info_collected.sql
info_collected.db
```

Kiểm tra danh sách bảng:

```bash
sqlite3 device_network.db ".tables"
sqlite3 info_collected.db ".tables"
```

Kiểm tra schema:

```bash
sqlite3 device_network.db ".schema"
sqlite3 info_collected.db ".schema"
```

Kiểm tra tính toàn vẹn:

```bash
sqlite3 device_network.db "PRAGMA integrity_check;"
sqlite3 info_collected.db "PRAGMA integrity_check;"
```

Kết quả hợp lệ:

```text
ok
```

---

## 8. Lưu ý quan trọng về khóa ngoại giữa hai database

SQLite không hỗ trợ `FOREIGN KEY` từ một file database sang bảng nằm trong file database khác.

Ví dụ sau không hoạt động đúng khi `t01_devices` chỉ nằm trong `device_network.db`:

```sql
CREATE TABLE t08_info_routing_table (
    id   INTEGER PRIMARY KEY AUTOINCREMENT,
    host TEXT NOT NULL,

    FOREIGN KEY (host)
        REFERENCES t01_devices(host)
        ON DELETE CASCADE
);
```

Mặc dù SQLite có thể tạo bảng trên, lúc `INSERT` vào `info_collected.db` có thể xuất hiện lỗi:

```text
no such table: main.t01_devices
```

Lệnh `ATTACH DATABASE` cũng không giải quyết được vấn đề này vì SQLite không cho phép khóa ngoại tham chiếu bảng trong database đã attach.

### Thiết kế được khuyến nghị

Trong các bảng thuộc `info_collected`, vẫn giữ:

```sql
host TEXT NOT NULL
```

nhưng bỏ khóa ngoại:

```sql
FOREIGN KEY (host) REFERENCES t01_devices(host)
```

Ví dụ:

```sql
CREATE TABLE t08_info_routing_table (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    host         TEXT NOT NULL,
    destination  TEXT NOT NULL,
    prefix_length INTEGER NOT NULL,
    collected_at TEXT NOT NULL DEFAULT (datetime('now'))
);
```

Tầng Python chịu trách nhiệm kiểm tra `host` tồn tại trong `device_network.db` trước khi ghi dữ liệu vào `info_collected.db`.

Ví dụ luồng xử lý:

```text
1. Mở device_network.db.
2. Kiểm tra host có trong t01_devices hay không.
3. Nếu host tồn tại, ghi dữ liệu collector vào info_collected.db.
4. Nếu host không tồn tại, từ chối ghi hoặc ghi log lỗi.
```

Không nên sao chép toàn bộ `t01_devices` sang `info_collected.db`, vì điều đó tạo hai nguồn dữ liệu thiết bị và có nguy cơ mất đồng bộ.

---

## 9. Mở đồng thời hai database bằng Python

```python
import sqlite3
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parent

DEVICE_DB = ROOT_DIR / "device_network.db"
INFO_DB = ROOT_DIR / "info_collected.db"


def host_exists(host: str) -> bool:
    with sqlite3.connect(DEVICE_DB) as connection:
        row = connection.execute(
            """
            SELECT 1
            FROM t01_devices
            WHERE host = ?
            LIMIT 1
            """,
            (host,),
        ).fetchone()

    return row is not None


def insert_collected_route(
    host: str,
    destination: str,
    prefix_length: int,
) -> None:
    if not host_exists(host):
        raise ValueError(
            f"Thiết bị {host!r} không tồn tại trong device_network.db"
        )

    with sqlite3.connect(INFO_DB) as connection:
        connection.execute(
            """
            INSERT INTO t08_info_routing_table (
                host,
                destination,
                prefix_length,
                protocol_code
            )
            VALUES (?, ?, ?, ?)
            """,
            (
                host,
                destination,
                prefix_length,
                "C",
            ),
        )


insert_collected_route(
    host="192.168.1.1",
    destination="192.168.1.0",
    prefix_length=24,
)
```

---

## 10. Mở đồng thời bằng `ATTACH DATABASE`

Có thể mở hai database trong cùng một kết nối để truy vấn kết hợp:

```sql
ATTACH DATABASE 'info_collected.db' AS info_db;

SELECT
    d.host,
    d.device_name,
    r.destination,
    r.prefix_length
FROM t01_devices AS d
LEFT JOIN info_db.t08_info_routing_table AS r
    ON r.host = d.host;
```

Cách này hỗ trợ `JOIN`, nhưng không tạo được khóa ngoại xuyên database.

Trong Python:

```python
import sqlite3

connection = sqlite3.connect("device_network.db")

connection.execute(
    "ATTACH DATABASE ? AS info_db",
    ("info_collected.db",),
)

rows = connection.execute(
    """
    SELECT
        d.host,
        d.device_name,
        r.destination,
        r.prefix_length
    FROM t01_devices AS d
    LEFT JOIN info_db.t08_info_routing_table AS r
        ON r.host = d.host
    """
).fetchall()

for row in rows:
    print(row)

connection.close()
```

---

## 11. Xóa và build lại

Không cần xóa database thủ công.

Chỉ cần chạy lại:

```bash
./build_databases.sh
```

hoặc:

```powershell
.\build_databases.ps1
```

Script tạo database tạm trước. Chỉ khi toàn bộ SQL hợp lệ và `integrity_check` trả về `ok`, database cũ mới bị thay thế.

---

## 12. Không đưa database sinh tự động lên Git

Có thể thêm vào `.gitignore`:

```gitignore
# Generated SQLite files
device_network.db
info_collected.db

# Generated combined SQL files
device_network.sql
info_collected.sql

# Temporary build databases
.*.tmp.db

# SQLite runtime files
*.db-journal
*.db-shm
*.db-wal
```

Nên commit:

```text
schema/*.sql
info_collected/*.sql
build_databases.sh
build_databases.ps1
README.md
```

Không cần commit các file được sinh tự động.

```
```
