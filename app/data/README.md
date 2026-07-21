# Runtime data

Thư mục mặc định cho SQLite runtime. Có thể đổi bằng `NETWORKTOOLS_DATA_DIR`. Không commit DB/WAL/journal/log/backup. Chạy `uv run main.py` để ứng dụng tự tạo database hoặc bổ sung schema còn thiếu; backup phải được quản lý ngoài Git và theo retention của môi trường triển khai.
