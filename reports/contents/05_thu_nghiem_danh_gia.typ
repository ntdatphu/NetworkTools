#import "../config/tables.typ": report-table

#pagebreak(weak: true)
= Thử nghiệm và đánh giá

== Mục tiêu và môi trường

Khi chốt báo cáo cần ghi cấu hình máy, hệ điều hành, phiên bản Python/Qt, commit, image Cisco IOS, EVE-NG/GNS3 và topology sử dụng trong thử nghiệm.

== Kiểm thử tự động

Các nhóm test hiện được định hướng gồm:

- Persistence: DHCP, ACL, NAT.
- Routing database contract.
- Dev-mode và worker safety.
- UI contract.
- QML smoke/load.

Tại thời điểm rà soát đề cương, 30 test được phát hiện; 28 test chức năng vượt qua và 2 test hợp đồng OSPF/EIGRP thất bại do code truy cập `t04_ospf_interface_settings` và `t04_eigrp_interface_settings` không tồn tại trong schema hiện hành. Số liệu này phải được chạy lại trước khi nộp báo cáo.


== Kịch bản kiểm thử hệ thống

Nhằm đánh giá toàn diện khả năng sinh lệnh và thực thi tự động của công cụ, quá trình kiểm thử được thiết kế xoay quanh 4 kịch bản (cluster) trọng tâm. Các kịch bản này mô phỏng sát với yêu cầu vận hành thực tế tại phòng thực hành mạng:

=== Kịch bản 1: Cấu hình Hạ tầng Chuyển mạch và Bảo mật Lớp 2 (Switching & L2 Security Cluster)
/ Mục tiêu: Kiểm thử khả năng thiết lập phân đoạn mạng (VLAN), đồng bộ miền (VTP), gom kênh truyền (EtherChannel) và phòng thủ tấn công nội bộ (DHCP Snooping, DAI).
/ Thao tác thực thi (UI): Khai báo VLAN 10, 20, cấu hình trunking và bật tính năng bảo mật trên SW1, SW3.
/ Xác minh (Verify): Chạy lệnh `show vlan brief`, `show etherchannel summary`, và `show ip dhcp snooping binding`.

=== Kịch bản 2: Dịch vụ IP động và Định tuyến liên vùng (IP Services & Routing Cluster)
/ Mục tiêu: Kiểm thử khả năng cấu hình giao diện Lớp 3, cấp phát IP tự động qua DHCP Server và thiết lập định tuyến động OSPF để liên thông toàn mạng.
/ Thao tác thực thi (UI): Tạo DHCP Pool trên Router/Switch L3, cấu hình OSPF Area 0 cho các interface.
/ Xác minh (Verify): Kiểm tra trạng thái cấp phát bằng `show ip dhcp binding` và kiểm tra bảng định tuyến bằng `show ip route ospf`.

=== Kịch bản 3: Chính sách kiểm soát truy cập và Lọc gói tin (Advanced ACL Cluster)
/ Mục tiêu: Kiểm thử khả năng sinh và đẩy tập lệnh cho các loại danh sách kiểm soát truy cập từ cơ bản đến nâng cao.
/ Thao tác thực thi (UI): Thiết lập Standard ACL, Extended ACL, đặc biệt là các quy tắc phức tạp như Dynamic ACL (Lock-and-Key) hoặc Reflexive ACL trên Router ranh giới.
/ Xác minh (Verify): Sử dụng lệnh `show access-lists` và kiểm tra trạng thái phiên lọc gói tin thực tế bằng cách truyền lưu lượng thử nghiệm.

=== Kịch bản 4: Biên dịch địa chỉ mạng và Dự phòng Gateway (NAT & Resilience Cluster)
/ Mục tiêu: Kiểm thử tính năng biên dịch địa chỉ (PAT / NAT Overload) kết hợp với giao thức dự phòng cổng mặc định (HSRP).
/ Thao tác thực thi (UI): Cấu hình dải NAT Pool / PAT kèm interface inside/outside, sau đó thiết lập nhóm HSRP (Group Virtual IP) trên hai thiết bị Router/Switch.
/ Xác minh (Verify): Kiểm tra bảng dịch địa chỉ `show ip nat translations` và trạng thái dự phòng gateway bằng `show standby brief`.

== Đo hiệu năng

Đo thời gian thao tác thủ công và bằng ứng dụng cho 1, 5 và 10 thiết bị; thời gian preview/push; tỷ lệ thành công; CPU/RAM nếu có ý nghĩa. Không điền số giả định vào phần kết quả.

== Đánh giá

*Ưu điểm:* UI tập trung, cấu trúc module, preview/pending state, test dev-mode và database schema rộng.

*Hạn chế:* phạm vi Cisco IOS, secret dạng rõ, parser phụ thuộc CLI, schema routing đang lệch test, mức hoàn thiện không đồng đều, chưa có rollback và chưa kiểm thử quy mô lớn.
