# Test Scenarios

Tài liệu này đề xuất các kịch bản kiểm thử phục vụ đề tài nghiên cứu khoa học.

## Nguyên tắc kiểm thử

Mỗi kịch bản nên có:

- Mục tiêu kiểm thử.
- Dữ liệu đầu vào.
- Các bước thực hiện.
- Kết quả mong đợi.
- Tiêu chí đánh giá.

## Nhóm 1: Quản lý thiết bị

### TC-DEV-01: Thêm thiết bị mới

Mục tiêu:

- Kiểm tra khả năng thêm thiết bị vào hệ thống.

Dữ liệu:

- Host/IP.
- Device name.
- Method.
- Port.
- Username/password.
- OS/role.

Kết quả mong đợi:

- Thiết bị được lưu vào database.
- Thiết bị xuất hiện trên UI.
- Không tạo bản ghi trùng host nếu host là khóa chính.

### TC-DEV-02: Cập nhật thông tin thiết bị

Mục tiêu:

- Kiểm tra luồng sửa thông tin thiết bị.

Kết quả mong đợi:

- Dữ liệu được cập nhật đúng trong UI và database.
- Các bảng liên quan vẫn tham chiếu đúng host.

### TC-DEV-03: Xóa thiết bị

Mục tiêu:

- Kiểm tra cascade/delete behavior.

Kết quả mong đợi:

- Thiết bị bị xóa.
- Dữ liệu phụ thuộc không còn mồ côi.

## Nhóm 2: DHCP

### TC-DHCP-01: Thêm DHCP pool

Mục tiêu:

- Kiểm tra lưu cấu hình DHCP pool theo host.

Kết quả mong đợi:

- Pool được lưu đúng.
- Các trường network/subnet/default-router/DNS/lease hiển thị đúng.

### TC-DHCP-02: Thêm excluded address

Mục tiêu:

- Kiểm tra lưu dải IP loại trừ.

Kết quả mong đợi:

- Dải IP được lưu đúng host.
- UI cập nhật danh sách sau khi thêm.

## Nhóm 3: Routing

### TC-ROUTE-01: Thêm static route

Mục tiêu:

- Kiểm tra lưu static route.

Kết quả mong đợi:

- Route được lưu theo host.
- Các trường network, subnet mask, next hop, AD đúng.

### TC-ROUTE-02: Thêm default route

Mục tiêu:

- Kiểm tra lưu default route.

Kết quả mong đợi:

- Default route được lưu đúng host.
- UI hiển thị trạng thái lưu/cập nhật rõ ràng.

### TC-ROUTE-03: Cấu hình OSPF process

Mục tiêu:

- Kiểm tra lưu OSPF process và network statements.

Kết quả mong đợi:

- OSPF process được lưu.
- Network statements được liên kết đúng process.

### TC-ROUTE-04: Cấu hình EIGRP process

Mục tiêu:

- Kiểm tra lưu EIGRP process và network statements.

Kết quả mong đợi:

- EIGRP process được lưu.
- Network statements được liên kết đúng process.

## Nhóm 4: ACL và NAT

### TC-ACL-01: Thêm ACL rule

Mục tiêu:

- Kiểm tra lưu ACL rule theo loại ACL.

Kết quả mong đợi:

- Rule được lưu đúng loại.
- UI hiển thị danh sách rule chính xác.

### TC-NAT-01: Thêm NAT static/dynamic/PAT

Mục tiêu:

- Kiểm tra lưu cấu hình NAT.

Kết quả mong đợi:

- NAT config được lưu đúng.
- Dữ liệu liên kết đúng host và ACL/route-map nếu có.

## Nhóm 5: Runtime và database

### TC-DB-01: Khởi tạo database lần đầu

Mục tiêu:

- Kiểm tra database được tạo khi chưa có `device_network.db`.

Điều kiện:

- Xóa database runtime trước khi chạy.

Kết quả mong đợi:

- App gọi Python app kernel.
- Database được tạo từ `python_app_kenel/sql/main.sql`.
- App mở database thành công bằng QSQLITE.

### TC-DB-02: Mở database đã tồn tại

Mục tiêu:

- Kiểm tra app không khởi tạo lại database nếu file đã tồn tại.

Kết quả mong đợi:

- Dữ liệu cũ còn nguyên.
- Migration/ensure column chạy nếu cần.

## Nhóm 6: So sánh thao tác thủ công và qua hệ thống

### TC-EVAL-01: So sánh cấu hình DHCP thủ công và qua UI

Chỉ số đo:

- Số bước thao tác.
- Thời gian hoàn thành.
- Số lỗi nhập liệu.
- Khả năng kiểm tra lại cấu hình.

### TC-EVAL-02: So sánh cấu hình routing thủ công và qua UI

Chỉ số đo:

- Thời gian nhập cấu hình.
- Tính nhất quán dữ liệu.
- Khả năng tái sử dụng cấu hình theo host.

## Ghi chú

Các kịch bản trên là khung ban đầu. Khi chức năng triển khai cấu hình thật được hoàn thiện, cần bổ sung thêm:

- Kiểm thử sinh cấu hình CLI/API.
- Kiểm thử push cấu hình xuống lab device.
- Kiểm thử rollback hoặc đánh dấu thất bại.
- Kiểm thử log/alert khi có lỗi cấu hình.
