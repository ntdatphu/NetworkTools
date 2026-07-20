# Features

Mỗi thư mục sở hữu một chức năng. Chỉ tạo `slots.py`, `service.py`, `repository.py`, `worker.py`, `models.py`, `parser.py` khi thật sự dùng. Dependency chuẩn: `slots → service → repository/worker → infrastructure`; feature không sửa bảng của feature khác ngoài contract công bố.

`config_backup/` sở hữu lịch sử `running-config` bằng repository Git Dulwich riêng cho từng host; facade `dbManager` chỉ ủy quyền các slot đọc sang service này.
