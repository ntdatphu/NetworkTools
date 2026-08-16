#import "../config/commands.typ": report-note

#pagebreak(weak: true)
= Tổng quan đề tài

== Bối cảnh và lý do chọn đề tài

Trong môi trường phòng thực hành mạng, cấu hình thiết bị thông qua giao diện dòng lệnh thường tạo ra nhiều thao tác lặp lại, khó theo dõi cấu hình mong muốn, dễ phát sinh lỗi cú pháp và thiếu một nơi quản lý tập trung. Đề tài lựa chọn hướng xây dựng một công cụ desktop để hỗ trợ quy trình quản trị và tự động hóa trong phạm vi phòng lab.

== Bài toán nghiên cứu

Ứng dụng hướng đến quy trình tích hợp:

#report-note[*Quản lý thiết bị → kết nối/thu thập → lưu trạng thái → tạo cấu hình mong muốn → preview → push → cập nhật kết quả.*]

== Mục tiêu

=== Mục tiêu tổng quát

Xây dựng nền tảng phần mềm desktop phục vụ quản lý và tự động hóa một số tác vụ cấu hình router Cisco IOS trong môi trường học tập và thực nghiệm.

=== Mục tiêu cụ thể

- Xây dựng UI QML và bridge PyQt6.
- Quản lý thiết bị và dữ liệu cấu hình bằng SQLite.
- Hỗ trợ kết nối, backup và đồng bộ một phần trạng thái thiết bị.
- Hoàn thiện luồng View & Push cho DHCP, Routing và NAT.
- Xây dựng persistence cho Interface và ACL làm nền tảng hoàn thiện push.
- Kiểm thử logic dữ liệu, UI contract, QML smoke và dev-mode.

== Đối tượng và phạm vi

- *Đối tượng:* router Cisco IOS trong lab; cấu hình interface, DHCP, routing, ACL và NAT.
- *Nền tảng:* Python 3.11+, PyQt6/QML, SQLite, Jinja2, Netmiko/Nornir; ưu tiên Windows và hướng đến Linux.
- *Ngoài phạm vi kết quả hiện tại:* quản lý doanh nghiệp quy mô lớn, HA, RBAC hoàn chỉnh, mã hóa secret, switching end-to-end, firewall, syslog và topology automation.

== Phương pháp nghiên cứu

Khảo sát nghiệp vụ; phân tích mã và lệnh IOS; thiết kế kiến trúc và schema; cài đặt theo module; kiểm thử tự động; thử nghiệm lab; so sánh với thao tác thủ công.

== Đóng góp và cấu trúc báo cáo

Đóng góp chính được xác định ở mức nền tảng tích hợp UI – DB – Worker, cơ chế quản lý trạng thái pending/success, dev-mode và thiết kế có khả năng mở rộng. Báo cáo được tổ chức thành sáu chương, từ tổng quan đến kết luận và hướng phát triển.
