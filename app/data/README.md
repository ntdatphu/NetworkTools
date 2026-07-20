# Runtime data

Thư mục mặc định cho SQLite runtime. Có thể đổi bằng `NETWORKTOOLS_DATA_DIR`. Không commit DB/WAL/journal/log/backup. Tái tạo DB bằng `python scripts/build_databases.py`; backup phải được quản lý ngoài Git và theo retention của môi trường triển khai.
