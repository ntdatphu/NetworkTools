# Evaluation Criteria

Tài liệu này đề xuất tiêu chí đánh giá cho đề tài nghiên cứu khoa học dựa trên dự án `NetworkTools`.

## Mục tiêu đánh giá

Đánh giá nhằm trả lời các câu hỏi:

1. Hệ thống có giúp quản lý thiết bị mạng tập trung hơn không?
2. Hệ thống có giảm thao tác thủ công khi nhập/lưu cấu hình không?
3. Hệ thống có giảm lỗi nhập liệu/cấu hình không?
4. Hệ thống có hỗ trợ quan sát trạng thái và sự kiện tốt hơn không?
5. Hệ thống có đủ nền tảng để mở rộng sang tự động hóa cấu hình và giám sát an ninh không?

## Nhóm tiêu chí 1: Quản lý tập trung

| Tiêu chí | Cách đo | Kết quả kỳ vọng |
|---|---|---|
| Quản lý thiết bị theo host | Thêm/sửa/xóa thiết bị | Dữ liệu nhất quán, không trùng host |
| Liên kết cấu hình theo thiết bị | Kiểm tra các bảng cấu hình theo host | Cấu hình được gắn đúng thiết bị |
| Tìm kiếm/hiển thị thiết bị | Thao tác trên UI | Người dùng dễ tìm và thao tác |

## Nhóm tiêu chí 2: Tự động hóa cấu hình

| Tiêu chí | Cách đo | Kết quả kỳ vọng |
|---|---|---|
| Chuẩn hóa dữ liệu cấu hình | Nhập cùng một loại cấu hình qua form | Dữ liệu lưu đúng schema |
| Giảm thao tác thủ công | So sánh số bước thao tác với cấu hình thủ công | Số bước giảm hoặc dễ kiểm soát hơn |
| Giảm lỗi nhập liệu | Kiểm tra validation và dữ liệu lưu | Hạn chế thiếu trường/sai format |
| Tái sử dụng dữ liệu | Load lại cấu hình đã lưu | Dữ liệu có thể xem/sửa lại |

## Nhóm tiêu chí 3: Database và tính nhất quán

| Tiêu chí | Cách đo | Kết quả kỳ vọng |
|---|---|---|
| Khởi tạo database | Chạy app khi chưa có DB | DB được tạo thành công |
| Mở database đã tồn tại | Chạy lại app với DB cũ | Dữ liệu không mất |
| Ràng buộc khóa ngoại | Xóa thiết bị có dữ liệu liên quan | Không để dữ liệu mồ côi |
| Migration/ensure schema | Chạy với DB cũ | Bổ sung cột/bảng cần thiết nếu có logic hỗ trợ |

## Nhóm tiêu chí 4: UI/UX

| Tiêu chí | Cách đo | Kết quả kỳ vọng |
|---|---|---|
| Dễ hiểu | Người dùng mới thao tác theo kịch bản | Hoàn thành được tác vụ cơ bản |
| Phản hồi trạng thái | Quan sát toast/status/list update | Có phản hồi sau thao tác |
| Tính nhất quán giao diện | So sánh các form/module | Component, spacing, màu sắc thống nhất |
| Khả năng mở rộng | Thêm module/form mới | Có thể tái sử dụng component/layout |

## Nhóm tiêu chí 5: Giám sát và cảnh báo

| Tiêu chí | Cách đo | Kết quả kỳ vọng |
|---|---|---|
| Theo dõi trạng thái cơ bản | Kiểm tra network/status bar | Có thông tin trạng thái runtime cơ bản |
| Logs/alerts panel | Kiểm tra UI panel | Có nền tảng hiển thị cảnh báo |
| Sự kiện bất thường | Mô phỏng lỗi kết nối/lỗi thao tác | Có thể ghi nhận/hiển thị hoặc định hướng xử lý |

## Nhóm tiêu chí 6: Hiệu quả nghiên cứu

| Tiêu chí | Cách đo | Kết quả kỳ vọng |
|---|---|---|
| Thời gian thao tác | Đo thời gian trước/sau | Thao tác qua hệ thống nhanh hơn hoặc dễ kiểm soát hơn |
| Số bước thao tác | Đếm số bước | Giảm thao tác lặp lại |
| Số lỗi | Ghi nhận lỗi nhập liệu/cấu hình | Giảm lỗi nhờ form/validation |
| Khả năng mở rộng | Phân tích kiến trúc | Có thể thêm module mới mà không phá cấu trúc hiện tại |

## Biểu mẫu ghi kết quả thử nghiệm

| Mã test | Tác vụ | Thời gian thủ công | Thời gian qua hệ thống | Số lỗi thủ công | Số lỗi qua hệ thống | Nhận xét |
|---|---|---:|---:|---:|---:|---|
| TC-DEV-01 | Thêm thiết bị | | | | | |
| TC-DHCP-01 | Thêm DHCP pool | | | | | |
| TC-ROUTE-01 | Thêm static route | | | | | |
| TC-ACL-01 | Thêm ACL rule | | | | | |
| TC-NAT-01 | Thêm NAT config | | | | | |

## Cách trình bày trong báo cáo

Trong báo cáo NCKH, nên trình bày kết quả theo cấu trúc:

1. Mục tiêu đánh giá.
2. Môi trường thử nghiệm.
3. Kịch bản thử nghiệm.
4. Bảng kết quả.
5. Nhận xét.
6. Hạn chế.
7. Hướng phát triển.
