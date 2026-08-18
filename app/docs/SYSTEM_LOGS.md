# Syslog Server workflow

Đối chiếu: **2026-08-18**.

Luồng runtime là `QML → SyslogManager → SyslogPipeline → Receiver/Writer →
Repository`. `SyslogManager` chỉ giữ contract Qt, query bất đồng bộ và điều phối
cấu hình thiết bị. `SyslogPipeline` đảm bảo receiver socket và writer queue được
start/stop như một đơn vị: nếu bind/listen thất bại thì receiver và writer đều
được rollback.

Receiver nhận một listener UDP hoặc TCP có giới hạn kích thước message và số TCP
client. Writer dùng bounded queue, parse message trên một thread và ghi SQLite
theo batch. `DeviceHostResolver` cache ánh xạ source IP trong 30 giây để tránh
query inventory cho từng packet; cache được xóa khi đổi workspace database.

Thứ tự stop là socket trước, sau đó flush writer queue. Message lỗi định dạng vẫn
được lưu ở dạng raw. Nếu queue đầy hoặc xử lý/ghi DB thất bại, dropped counter
tăng và UI nhận `errorOccurred`; callback UI lỗi sau khi DB đã commit không bị
tính nhầm là dropped.

Thiết bị Cisco IOS/IOS-XE chỉ được cấu hình destination sau khi listener đang ở
trạng thái `listening`. Cấu hình dùng session registry hiện hữu, yêu cầu source
interface đã đồng bộ hoặc nhập thủ công, và lưu trạng thái riêng theo host/server/
protocol/port.
