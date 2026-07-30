# Network infrastructure

`running_config_collector.py` owns Cisco running-config collection. It enters
configuration mode, disables paging, buffers channel chunks, and completes only
when the exact configuration prompt returns; partial output is never returned.

Nơi đặt connector, registry session, bounded batch executor, ping adapter và
command runner dùng chung. Connector phải che giấu thư viện transport.

`DeviceSessionRegistry` là owner duy nhất của session theo host. Mỗi
`SessionEntry` giữ state, generation, thời điểm sử dụng và `operation_lock`;
`execute()` tuần tự hóa mọi thao tác trên cùng CLI channel nhưng các host khác
vẫn chạy song song. Session đóng khi Disconnect, app shutdown hoặc lifecycle
thiết bị yêu cầu; đóng/chuyển tab không đóng session.

`features/terminal/worker.py` dùng chính `execute()` và giữ khóa trong toàn bộ
thời gian cửa sổ CLI tương tác đang mở. Vì vậy input terminal không thể xen vào
push cấu hình trên cùng host; terminal của các host khác vẫn chạy song song.
Registry trả warning trước khi tạo connector cho host `Up (Dev)` hoặc protocol
không hỗ trợ, và chỉ gọi operation sau khi xác nhận connector còn sống.

`BatchExecutor` giới hạn mặc định 5 worker, cô lập exception theo host và chỉ
cancel tác vụ chưa bắt đầu tại safe boundary. Không log password/private key;
lỗi trả về dạng có cấu trúc. Worker feature không tạo cache session riêng.

`DeviceConnector.collect_running_config()` chỉ thu thập output; feature `config_backup` quyết định path, ghi file và commit. `save_running_config()` là adapter tương thích cho interactive CLI cũ.
