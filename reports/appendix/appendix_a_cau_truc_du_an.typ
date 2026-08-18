#import "../config/commands.typ": appendix-heading, todo

#appendix-heading[PHỤ LỤC A. CẤU TRÚC DỰ ÁN]

Cây thư mục trọng tâm của runtime desktop:

```text
app/
├── ui/
├── core/
├── services/
├── network_code/
├── database/
└── tests/
```

Báo cáo cuối cùng nên bổ sung bảng ánh xạ:

```text
QML → slot/bridge → backend → table SQLite → worker/template
```

#todo[Điền tên module thật, file nguồn và bảng dữ liệu theo commit chốt báo cáo.]
