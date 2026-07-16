# Kế hoạch smart merge

## Cổng chất lượng

Một tính năng chỉ được nhận khi:

- có ranh giới module và ownership rõ;
- dùng schema, naming, theme token và component của `frontend/test`;
- không chạy network/disk/process blocking trên UI thread;
- có cancel/shutdown hoặc timeout hữu hạn;
- có giới hạn CPU/RAM/disk/retention nếu xử lý dữ liệu liên tục;
- không hạ cấp bảo mật hoặc thay đổi Windows khi chưa có hành động rõ của người
  dùng;
- có backend test, QML smoke hoặc contract test phù hợp.

## Các giai đoạn

| Giai đoạn | Nội dung | Trạng thái |
|---|---|---|
| 1 | Fetch/prune và xác định base/upstream. | Hoàn thành |
| 2 | Ahead/behind, commit inventory và file inventory mọi nhánh. | Hoàn thành |
| 3 | Tạo `frontend/merges` từ `frontend/test`. | Hoàn thành |
| 4 | Sửa canonical persistence OSPF/EIGRP. | Hoàn thành |
| 5 | Viết lại Switching theo role, transaction và component hiện tại. | Hoàn thành |
| 6 | Viết lại SFTP với host-key verification và serialized worker. | Hoàn thành |
| 7 | Viết lại Device Logs bất đồng bộ, bounded và có retention. | Hoàn thành |
| 8 | Thay auto-installer bằng Tool Catalog read-only, official URL allowlist. | Hoàn thành |
| 9 | Đồng bộ Activity Bar, Main, Settings, qmldir và icon inventory. | Hoàn thành |
| 10 | Full test, compile, lock check, whitespace/security scan. | Hoàn thành |
| 11 | Chốt tài liệu và commit nhánh đích. | Hoàn thành |

## Thứ tự tích hợp được chọn

Routing được sửa trước vì là lỗi schema nền và ảnh hưởng dữ liệu. Switching
được thêm tiếp vì độc lập ở local desired state. SFTP được tách thành workspace
độc lập để tránh kéo package/asset cũ vào UI. Logs được làm sau khi lifecycle,
backpressure và retention có thiết kế rõ. Tool Catalog được làm cuối vì tận dụng
khả năng nhận diện External Tools đã có mà không tạo một installer thứ hai.

## Quy tắc merge tiếp theo

Mọi nhánh cộng tác mới cần được đánh giá bằng cùng quy trình:

1. fetch và ghi commit SHA;
2. tính ahead/behind;
3. diff theo feature boundary, không theo tên người/nhánh;
4. so schema/API/QML contract với `frontend/merges`;
5. viết test mô tả hành vi muốn giữ;
6. port hoặc viết lại lát cắt tối thiểu;
7. full suite trước khi commit.
