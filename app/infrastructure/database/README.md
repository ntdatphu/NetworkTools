# Database infrastructure

`paths.py` là nguồn path duy nhất. Schema chuẩn ở `schemas/device_network` và `schemas/info_collected`; SQL tổng hợp được sinh vào `aggregates/`; DB runtime ở `data/`. Chạy `python scripts/build_databases.py`; builder ghi file tạm, kiểm tra integrity/foreign key rồi thay thế atomically. Migration tương lai đặt trong `migrations/`.
