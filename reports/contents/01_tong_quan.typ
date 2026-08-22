#pagebreak(weak: true)
= Tổng quan đề tài

== Bối cảnh và lý do chọn đề tài
Trong bối cảnh công nghệ mạng máy tính ngày càng phát triển, việc quản trị và vận hành hạ tầng đòi hỏi sự chính xác và tính đồng bộ cao. Tuy nhiên, trong môi trường học tập và các phòng thực hành (lab) hiện nay, việc cấu hình thiết bị (Router, Switch) chủ yếu vẫn được thực hiện thủ công thông qua Giao diện dòng lệnh (CLI - Command Line Interface). Phương pháp truyền thống này bộc lộ nhiều hạn chế: tạo ra các thao tác lặp đi lặp lại nhàm chán, rủi ro sai sót cú pháp cao, khó khăn trong việc kiểm soát sự sai lệch cấu hình (Configuration Drift) và thiếu một cơ sở dữ liệu tập trung để lưu trữ trạng thái của toàn bộ hệ thống mạng.

Bên cạnh đó, xu hướng Tự động hóa mạng (Network Automation) và Quản lý hạ tầng bằng mã (Infrastructure as Code) đang trở thành tiêu chuẩn mới trong ngành công nghiệp. Việc áp dụng ngôn ngữ lập trình vào quản trị mạng không chỉ giúp tiết kiệm thời gian mà còn nâng cao độ tin cậy. Xuất phát từ nhu cầu thực tiễn đó, đề tài lựa chọn hướng nghiên cứu và xây dựng một hệ thống quản lý tập trung cung cấp giao diện inventory nhằm hỗ trợ quy trình quản trị, tập trung hóa dữ liệu và tự động hóa các tác vụ cấu hình thiết bị mạng, qua đó giúp sinh viên làm quen với tư duy quản trị mạng hiện đại.

== Bài toán nghiên cứu
Vấn đề cốt lõi mà đề tài cần giải quyết là xây dựng một quy trình khép kín nhằm chuyển đổi từ mô hình cấu hình thủ công, phân tán sang mô hình quản lý tập trung dựa trên dữ liệu (Data-driven). Ứng dụng hướng đến việc tự động hóa luồng quy trình nghiệp vụ được thiết kế chặt chẽ theo các giai đoạn tuần tự sau:

+ *Quản lý và Khởi tạo:* Khai báo định danh thiết bị, địa chỉ IP và thiết lập các thông số xác thực.
+ *Thu thập trạng thái (Sync):* Thiết lập phiên giao tiếp an toàn, bóc tách (parse) cấu hình đang chạy (Running Configuration) từ thiết bị để lưu trữ vào cơ sở dữ liệu làm trạng thái cơ sở (Baseline).
+ *Định nghĩa cấu hình (Desired State):* Người quản trị thiết lập các thông số nghiệp vụ mới thông qua giao diện đồ họa (GUI). Dữ liệu này được lưu trữ tạm thời với trạng thái chờ (Pending).
+ *Xem trước và Thực thi (View & Push):* Hệ thống sử dụng engine Jinja2 để kết xuất dữ liệu thành các tập lệnh CLI chuẩn xác. Người quản trị được phép kiểm duyệt (Preview) mã lệnh trước khi các luồng thực thi nền (Worker) đẩy lệnh xuống thiết bị.
+ *Xác minh và Cập nhật:* Đánh giá phản hồi từ thiết bị; nếu không có lỗi phát sinh, hệ thống tự động cập nhật trạng thái đồng bộ vào cơ sở dữ liệu.

== Mục tiêu
=== Mục tiêu tổng quát
Xây dựng hoàn thiện một nền tảng phần mềm desktop (NetworkTools) phục vụ công tác quản lý tập trung và tự động hóa các tác vụ cấu hình trên thiết bị định tuyến và chuyển mạch Cisco IOS, đáp ứng được các kịch bản triển khai mạng từ cơ bản đến nâng cao tại phòng lab.

=== Mục tiêu cụ thể
- *Về giao diện và trải nghiệm:* Xây dựng giao diện đồ họa trực quan bằng framework Qt Quick/QML kết hợp với cầu nối PyQt6, đảm bảo tính đáp ứng khi chạy các tác vụ nền.
- *Về dữ liệu và quản lý phiên bản:* Thiết kế cơ sở dữ liệu SQLite cục bộ; ứng dụng thư viện Dulwich quản lý phiên bản cấu hình theo chuẩn Git.
- *Về logic nghiệp vụ:* Hoàn thiện luồng tự động hóa View & Push cho các tính năng cốt lõi và nâng cao: Định tuyến (Static, OSPF, EIGRP); Dịch vụ IP (DHCP, NAT/PAT, FHRP); Chuyển mạch (VLAN, Trunking, EtherChannel, STP, VTP) và các cơ chế bảo mật (Standard/Extended/Dynamic/Reflexive ACL, DHCP Snooping, DAI).
- *Về vận hành đồng bộ:* Tích hợp terminal CLI nhúng (Alacritty) có gắn hook vòng đời phiên làm việc, tự động kích hoạt tiến trình đồng bộ cấu hình.

== Đối tượng và phạm vi
- *Đối tượng nghiên cứu:* Tập trung vào thiết bị Router và Switch chạy Cisco IOS trên môi trường mô phỏng (vIOS L3/L2 trên EVE-NG). Phân hệ nghiệp vụ bao phủ từ Lớp 2 (Switching, L2 Security) lên Lớp 3 (Routing, IP Services).
- *Nền tảng công nghệ:* Python (3.11+), PyQt6/QML, SQLite, Jinja2, Netmiko/Nornir, Paramiko và Dulwich.
- *Giới hạn đề tài:* Kết quả nghiên cứu hiện tại được tối ưu cho môi trường lab; chưa bao gồm các kiến trúc dự phòng sẵn sàng cao phân tán (HA Cluster), phân quyền người dùng (RBAC) hay cơ chế quản lý khóa bí mật chuyên dụng (Secret Vault). Về giao thức mạng, hệ thống chưa hỗ trợ thiết bị đa hãng (Multi-vendor), chưa tích hợp giao thức định tuyến liên miền (BGP) và các công nghệ Data Center (như VXLAN, EVPN); các hạng mục này được định hướng phát triển trong các phiên bản tiếp theo.