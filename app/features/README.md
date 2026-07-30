# Features

Mỗi thư mục sở hữu một chức năng. Chỉ tạo `slots.py`, `service.py`, `repository.py`, `worker.py`, `models.py`, `parser.py` khi thật sự dùng. Dependency chuẩn: `slots → service → repository/worker → infrastructure`; feature không sửa bảng của feature khác ngoài contract công bố.

`config_backup/` sở hữu lịch sử `running-config` bằng repository Git Dulwich riêng cho từng host; facade `dbManager` chỉ ủy quyền các slot đọc sang service này.

`config_sync/` sở hữu policy đồng bộ snapshot đã commit: chỉ role `rou` và chỉ khi Dulwich xác định nội dung thay đổi. Parser/writer SQLite không phụ thuộc QML hoặc lớp kết nối thiết bị.

`routing/` sở hữu Routing Group đa host và các protocol định tuyến. `fhrp/` sở
hữu toàn bộ validation/persistence/template/worker HSRP, VRRP, GLBP; cả hai chỉ
đọc contract interface đã công bố để lọc network/interface phù hợp.

`terminal/` sở hữu cửa sổ CLI độc lập, worker stream và adapter nối widget MIT
`qtpyTerminal-main` với Netmiko. Feature dùng session/khóa theo host do
infrastructure công bố, không khởi chạy terminal hoặc SSH client của hệ điều
hành.
