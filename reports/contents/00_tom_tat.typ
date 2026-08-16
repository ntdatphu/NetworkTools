#import "../config/commands.typ": front-heading, todo

#front-heading[TÓM TẮT]

Đề tài xây dựng *NetworkTools*, một ứng dụng desktop hỗ trợ quản lý tập trung và tự động hóa một số tác vụ cấu hình thiết bị mạng Cisco IOS trong môi trường học tập và thực nghiệm. Hệ thống sử dụng giao diện Qt Quick/QML, bridge PyQt6, cơ sở dữ liệu SQLite và các worker Python để lưu trạng thái, sinh cấu hình, xem trước và đẩy cấu hình xuống thiết bị.

Phạm vi hiện tại tập trung vào quản lý thiết bị, kết nối và đồng bộ một phần trạng thái, DHCP, STATIC, OSPF, EIGRP, ACL, NAT/PAT cùng các tiện ích hỗ trợ. Một số module đã có UI và duy trì kết nối nhưng chưa tiến hành thực hiện luồng View & Push end-to-end. 


