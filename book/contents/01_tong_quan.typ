#pagebreak(weak: true)

= Tổng quan về phần mềm NetworkTools

== Giới thiệu về phần mềm NetworkTools
NetworkTools là ứng dụng desktop được xây dựng nhằm hỗ trợ quản lý, cấu hình và giám sát các thiết bị mạng từ một môi trường làm việc tập trung. Thay vì thực hiện riêng lẻ các thao tác quản trị trên từng thiết bị mạng (ví dụ như Router hoặc Switch), người dùng có thể quản lý danh sách thiết bị, thiết lập kết nối, thu thập cấu hình, xây dựng cấu hình mong muốn và thực hiện các tác vụ quản trị thông qua một giao diện thống nhất.

NetworkTools là ứng dụng desktop được xây dựng nhằm hỗ trợ quản lý, cấu hình và giám sát các thiết bị mạng từ một môi trường làm việc tập trung. Thay vì thực hiện riêng lẻ các thao tác quản trị trên từng thiết bị mạng (ví dụ như Router hoặc Switch), người dùng có thể quản lý danh sách thiết bị, thiết lập kết nối, thu thập cấu hình, xây dựng cấu hình mong muốn và thực hiện các tác vụ quản trị thông qua một giao diện thống nhất.

== Mục tiêu của phần mềm
Mục tiêu của NetworkTools:
- Quản lý tập trung thiết bị mạng thay vì quản lý từng thiết bị riêng lẻ.
- Tự động hóa các tác vụ cấu hình thiết bị mạng, giảm thiểu thao tác thủ công và rủi ro sai sót. 
- Quy trình cấu hình có cấu trúc. Hỗ trợ kiểm tra trước khi triển khai cấu hình, giúp người quản trị có thể xem trước các thay đổi và xác nhận trước khi áp dụng thông qua cơ chế "View & Push".
- Theo dõi trạng thái thiết bị mạng và đồng bộ hóa dữ liệu cấu hình giữa cơ sở dữ liệu tập trung và trạng thái thực tế của thiết bị.
- Lưu lại lịch sử cấu hình và các thay đổi, giúp người quản trị có thể truy xuất lại các phiên bản cấu hình trước đó khi cần thiết.
- Tập trung các công cụ vận hành mạng như Syslog, SFTP, Terminal và Device Logs vào cùng một môi trường làm việc, giúp người quản trị dễ dàng truy cập và sử dụng.
- Hỗ trợ nghiên cứu, học tập và thực hành quản trị mạng trong môi trường phòng lab, giúp sinh viên làm quen với các công cụ và quy trình quản trị mạng hiện đại.

== Đối tượng sử dụng
NetworkTools phù hợp với các đối tượng sau:
- Sinh viên và giảng viên trong các khóa học về mạng máy tính, giúp họ thực hành quản trị mạng trong môi trường phòng lab.
- Người nghiên cứu về quản trị mạng, muốn thử nghiệm các công cụ và quy trình quản lý tập trung, desired state, đồng bộ cấu hình và tự động hóa cấu hình triển khai.
- Kỹ thuật viên hoặc quản trị viên mạng muốn thử nghiệm các công cụ quản lý tập trung và tự động hóa cấu hình trong môi trường mô phỏng trước khi triển khai trên thiết bị thực tế.

NetworkTools hiện đang tỏng giai đoạn phát triển và kiểm chứng trong môi trường nghiên cứu. Các tính năng của phần mềm không nên được hiểu là đã hoàn thiện hoặc sẵn sàng triển khai trong môi trường thực tế. Người dùng nên thận trọng và kiểm tra kỹ lưỡng trước khi áp dụng các thay đổi cấu hình trên thiết bị thực tế.

== Các chức năng chính

=== Quản lý thiết bị
NetworkTools cung cấp khả năng quản lý tập trung cho các thiết bị mạng. Người dùng có thể thêm, chỉnh sửa, xóa, tìm kiếm hoặc nhập hàng loạt danh sách thiết bị mạng, bao gồm các thông tin cơ bản như tên thiết bị, địa chỉ IP, loại thiết bị (Router/Switch); thực hiện Ping, Connect, Disconnect, Reconnect và thu thập `running-config`. Phần mềm hỗ trợ quản lý nhiều thiết bị cùng lúc, giúp người quản trị dễ dàng theo dõi và thao tác trên toàn bộ hệ thống mạng.

=== Quản lý Router
Các chức năng hiện có bao gồm: Router Interface, Static Routing, Default Route, OSPF, EIGRP, ACL, NAT, DHCP và FHRP.

=== Quản lý Switch
Các chức năng hiện có bao gồm: VLAN, Access Port, Trunk Port, Spanning Tree Protocol (STP), Port Security, EtherChannel, SVI, VTP, DHCP SnoopingSnooping, Dynamic ARP Inspection (DAI), Storm Control, ACL, và các tính năng khác.

=== Sao lưu và theo dõi cấu hình
NetworkTools cung cấp khả năng sao lưu và theo dõi cấu hình thiết bị mạng. Người dùng có thể lưu lại các phiên bản cấu hình, so sánh sự khác biệt giữa các phiên bản, và khôi phục cấu hình từ các phiên bản trước đó khi cần thiết. Điều này giúp người quản trị dễ dàng quản lý lịch sử thay đổi và đảm bảo tính nhất quán trong quá trình vận hành mạng.

=== Thu thập và giám sát thông tin mạng
System Logs: Tiếp nhận và lưu Syslog
Device Logs: Sử dụng TShark để thu thập và phân tích các gói tin mạng, giúp người quản trị theo dõi lưu lượng và phát hiện các vấn đề tiềm ẩn trong môi trường được cấp quyền.

=== Truyền tệp tin và Terminal
NetworkTools cung cấp khả năng truyền tệp tin thông qua giao thức SFTP, giúp người quản trị dễ dàng sao chép và quản lý các tệp tin cấu hình hoặc dữ liệu liên quan đến thiết bị mạng. Ngoài ra, phần mềm cũng tích hợp Terminal, cho phép người dùng truy cập trực tiếp vào thiết bị mạng để thực hiện các lệnh cấu hình hoặc kiểm tra trạng thái thiết bị.

=== Project và Workspace
NetworkTools tổ chức dữ liệu làm việc dưới dạn NetworkTools Project `.ntp`. Người dùng có thể tạo, mở, lưu và quản lý các dự án mạng riêng biệt, giúp phân tách các môi trường làm việc khác nhau, sử dụng mật khẩu để bảo vệ tùy chọn và quản lý snapshot/rollback.


