#import "../config/commands.typ": appendix-heading

#appendix-heading[PHỤ LỤC C. KIỂM THỬ VÀ MINH CHỨNG]

Các minh chứng cần bổ sung trước khi nộp:

- Ảnh tổng quan ứng dụng và quản lý thiết bị.
- Sơ đồ kiến trúc và luồng View & Push.
- ERD rút gọn đúng schema hiện hành.
- Ảnh DHCP, Routing, ACL, NAT và Interface.
- Log test sau khi sửa routing schema.
- Topology và file lab.
- Kết quả lệnh `show` trước/sau push.
- Bảng đo thời gian và tỷ lệ thành công.
- Kiểm thử Windows/Linux.
- Phân công và đóng góp thành viên.

Trọng tâm bảo vệ nên là luồng tích hợp đã có bằng chứng: *quản lý thiết bị → lưu desired state → preview → push → cập nhật trạng thái*, minh họa bằng DHCP, Static Routing hoặc NAT. Topology/static route đa router chỉ nên chọn làm điểm nổi bật khi đã tích hợp vào `app/`, có UI, test và demo lab ổn định.
