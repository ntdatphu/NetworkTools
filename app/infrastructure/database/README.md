# Database infrastructure

`paths.py` là nguồn path duy nhất. Schema chuẩn ở `schemas/device_network` và `schemas/info_collected`; builder đọc trực tiếp các file `.sql` theo thứ tự tên và không tạo thư mục/file SQL tổng hợp. DB runtime ở `data/`. Chạy `python scripts/build_databases.py`; builder ghi database tạm, kiểm tra integrity/foreign key rồi thay thế atomically. Migration tương lai đặt trong `migrations/`.
