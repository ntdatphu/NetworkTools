# Routing

Đối chiếu: **2026-08-16**.

Routing Group thay thế workflow Clone trong QML. Popup bốn bước chọn nhiều host
đang connected, nhập Process ID/AS Number và Router ID riêng cho từng host,
nhập tham số chung, sau đó chọn network/area. `group_repository.py` tính network
từ IP/mask của `t02_interface_name`; backend kiểm tra lại ownership để QML không
thể lưu network không thuộc host. Save & Push lưu từng host độc lập, giữ kết quả
partial và mở batch preview trước khi gửi lệnh.

`clone_service.py` và các clone slot chỉ còn là compatibility API cho automation
cũ; không còn được export/khởi tạo bởi QML runtime mới.

OSPF Process có `AuthenticationCFG`: bật tùy chọn này áp dụng
message-digest authentication cho các area của process (tạo area 0 nếu chưa có
area). OSPF Router Interface được chia lại thành identity, adjacency và
authentication; payload hỗ trợ priority, plain/message-digest và auth key.

Feature điều phối Static, OSPF, EIGRP và routing information. Trạng thái
**partial**: CRUD/preview/push đã ở namespace feature; Routing Group đã có
service/repository riêng, các protocol đơn host vẫn còn adapter cần tách tiếp.
QML entry `UI/qml/features/routing/RoutingView.qml`; DB `t04_*`. Preview không kết
nối, push dùng session registry. Xem README thư mục con.
