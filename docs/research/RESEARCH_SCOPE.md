# Research Scope

## Tên đề tài định hướng

**Nghiên cứu và xây dựng hệ thống quản lý tập trung, tự động hóa cấu hình và giám sát an ninh mạng.**

## Mục tiêu nghiên cứu

Đề tài hướng đến xây dựng một mô hình hệ thống hỗ trợ quản lý tập trung thiết bị mạng, lưu trữ cấu hình theo từng thiết bị và tạo nền tảng cho tự động hóa cấu hình, giám sát trạng thái và cảnh báo sự kiện bất thường.

## Phạm vi hệ thống hiện tại

Dự án hiện tập trung vào:

- Ứng dụng desktop Qt/QML.
- Quản lý danh sách thiết bị mạng.
- Lưu trữ dữ liệu cấu hình bằng SQLite.
- Các module cấu hình: interface, DHCP, routing, ACL, NAT.
- Python app kernel hỗ trợ khởi tạo database và một số tác vụ backend.

## Phạm vi nghiên cứu đề xuất

### 1. Quản lý tập trung

Nghiên cứu mô hình lưu trữ và quản lý thông tin thiết bị mạng theo `host`.

Nội dung:

- Thêm/sửa/xóa thiết bị.
- Lưu thông tin thiết bị.
- Gắn cấu hình theo từng thiết bị.
- Tổ chức dữ liệu bằng SQLite.

### 2. Tự động hóa cấu hình

Nghiên cứu cách chuẩn hóa dữ liệu cấu hình từ UI để phục vụ sinh hoặc triển khai cấu hình.

Nội dung:

- Interface configuration.
- DHCP configuration.
- Static routing.
- OSPF/EIGRP.
- ACL.
- NAT.

### 3. Giám sát và cảnh báo

Phạm vi hiện tại nên giới hạn ở mức nền tảng:

- Theo dõi trạng thái thiết bị/kết nối.
- Hiển thị logs/alerts panel.
- Định nghĩa loại sự kiện cần cảnh báo.
- Chuẩn bị cơ chế mở rộng cho phát hiện bất thường.

### 4. Đánh giá hiệu quả

Đề tài nên đánh giá bằng các tiêu chí đo được:

- Thời gian thao tác cấu hình.
- Số bước thao tác thủ công.
- Tỷ lệ lỗi nhập liệu/cấu hình.
- Khả năng quản lý tập trung theo thiết bị.
- Khả năng quan sát trạng thái và sự kiện.

## Ngoài phạm vi hiện tại

Các nội dung sau không nên cam kết là đã hoàn thiện nếu chưa có source/test tương ứng:

- SIEM hoàn chỉnh.
- Phát hiện tấn công nâng cao.
- Triển khai cấu hình thật cho mọi vendor.
- Multi-user/RBAC hoàn chỉnh.
- Monitoring thời gian thực đầy đủ ở mức production.

## Kết quả kỳ vọng

- Mô hình hệ thống quản lý mạng tập trung.
- Ứng dụng thử nghiệm có UI và database.
- Bộ schema lưu trữ cấu hình mạng.
- Bộ kịch bản kiểm thử.
- Báo cáo đánh giá kết quả theo tiêu chí rõ ràng.
