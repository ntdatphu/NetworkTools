#import "../config/commands.typ": front-heading, todo

#front-heading[TÓM TẮT]

Đề tài xây dựng *NetworkTools*, một ứng dụng desktop hỗ trợ quản lý tập trung và tự động hóa một số tác vụ cấu hình thiết bị mạng Cisco IOS trong môi trường học tập và thực nghiệm. Hệ thống sử dụng giao diện Qt Quick/QML, bridge PyQt6, cơ sở dữ liệu SQLite và các worker Python để lưu trạng thái, sinh cấu hình, xem trước và đẩy cấu hình xuống thiết bị.

Phạm vi hiện tại tập trung vào quản lý thiết bị, kết nối và đồng bộ một phần trạng thái, DHCP, định tuyến tĩnh, OSPF, EIGRP, ACL, NAT/PAT cùng các tiện ích hỗ trợ. Một số module đã có UI và persistence nhưng chưa hoàn thiện luồng View & Push end-to-end. Tại thời điểm rà soát đề cương, bộ kiểm thử phát hiện 30 test; 28 test chức năng vượt qua và 2 test hợp đồng OSPF/EIGRP còn lỗi do không đồng bộ tên bảng schema.

Báo cáo trình bày cơ sở lý thuyết, kiến trúc hệ thống, thiết kế dữ liệu, quá trình xây dựng phần mềm, phương pháp kiểm thử và các hạn chế hiện tại. Kết quả được phân biệt rõ giữa chức năng đã triển khai, nền tảng đã có và các hướng phát triển dự kiến nhằm tránh xem mục tiêu hoặc schema chưa tích hợp là kết quả hoàn thành.

#todo[Cập nhật lại số liệu test, kết quả lab và số đo hiệu năng ở phiên bản báo cáo cuối cùng.]
