# Bộ tài liệu UI beta

Ngày cập nhật: 2026-07-10

Thư mục này là source of truth cho việc đánh giá, thiết kế và tiếp tục phát triển UI beta. Mục tiêu của bộ tài liệu là tách rõ bốn câu hỏi khác nhau: **hiện trạng là gì**, **giao diện nên vận hành theo pattern nào**, **từng Feature/SubFeature cần thay đổi ra sao**, và **thực hiện theo thứ tự nào**.

## Cách đọc đề xuất

1. Đọc [changes.md](changes.md) để biết nhánh refactor đã thay đổi gì so với `frontend-beta` và những giới hạn còn lại.
2. Đọc [UI_AUDIT_REPORT.md](UI_AUDIT_REPORT.md) để hiểu các phát hiện và rủi ro hiện trạng.
3. Đọc [UI_PATTERN_SYSTEM.md](UI_PATTERN_SYSTEM.md) để hiểu vì sao không dùng một layout duy nhất cho mọi feature và contract nào vẫn phải thống nhất.
4. Đọc [FEATURE_UI_DESIGN_PLAN.md](FEATURE_UI_DESIGN_PLAN.md) để xem đánh giá và đề xuất cụ thể cho từng Feature/SubFeature.
5. Dùng [CONTINUATION_ROADMAP.md](CONTINUATION_ROADMAP.md) để chọn thứ tự triển khai và quality gate.
6. Cập nhật trạng thái công việc trong [SCHEMA_for_UI.md](SCHEMA_for_UI.md).

## Vai trò từng tài liệu

| Tài liệu | Trả lời câu hỏi | Khi nào cập nhật |
|---|---|---|
| [changes.md](changes.md) | Nhánh refactor khác nhánh gốc ở đâu? | Khi baseline hoặc phạm vi so sánh thay đổi |
| [UI_AUDIT_REPORT.md](UI_AUDIT_REPORT.md) | Hiện trạng có vấn đề và bằng chứng gì? | Khi một kết luận audit được xác minh lại |
| [UI_PATTERN_SYSTEM.md](UI_PATTERN_SYSTEM.md) | Các họ giao diện và contract chung là gì? | Khi thêm/sửa pattern hoặc shared component contract |
| [FEATURE_UI_DESIGN_PLAN.md](FEATURE_UI_DESIGN_PLAN.md) | Từng feature đang có gì và nên thiết kế thế nào? | Khi scope, backend capability hoặc quyết định UX thay đổi |
| [CONTINUATION_ROADMAP.md](CONTINUATION_ROADMAP.md) | Làm gì trước, phụ thuộc gì và nghiệm thu ra sao? | Mỗi khi bắt đầu/kết thúc một phase hoặc đổi ưu tiên |
| [SCHEMA_for_UI.md](SCHEMA_for_UI.md) | Item nào đang mở, bị chặn hay đã hoàn tất? | Trong cùng PR với code thay đổi |

## Quan điểm thiết kế

Không dùng một “mẫu màn hình chuẩn” duy nhất cho toàn bộ sản phẩm. Routing theo process hierarchy, ACL theo rule ordering, DHCP theo entity list, Monitor theo dashboard và Settings theo catalog có mô hình tư duy khác nhau. Ép chúng vào cùng một bố cục sẽ làm UI giống nhau về hình thức nhưng khó dùng.

Sự thống nhất nên nằm ở các lớp sau:

- Theme token, typography, spacing, icon và motion.
- Feature header, device context, capability banner và trạng thái request.
- Validation, dirty state, save/preview/push semantics.
- Empty/loading/error/read-only/unsupported state.
- Keyboard, focus, accessibility, localization và responsive rules.
- List/table metadata, dialog shell và notification/task feedback.

Phần nội dung có thể chọn một trong nhiều họ giao diện theo workflow. Quy tắc chọn được mô tả trong [UI_PATTERN_SYSTEM.md](UI_PATTERN_SYSTEM.md).

## Quy tắc duy trì

- Mọi nhận định về capability phải trỏ được tới backend/controller hiện tại; không suy ra từ việc form trông hoàn chỉnh.
- “Có UI”, “có local CRUD”, “có preview” và “có push end-to-end” là bốn mức khác nhau.
- Mọi Feature/SubFeature mới phải có pattern family, owner dữ liệu, capability level, validation matrix và test plan trước khi code form.
- Không thêm abstraction chung nếu chưa có ít nhất hai consumer thật; table/policy/process abstraction nên có ba consumer hoặc một pilot chứng minh được contract.
- Thay đổi code làm kết luận tài liệu sai phải cập nhật tài liệu trong cùng PR.
- File trong `md_by_old/` chỉ là tài liệu lịch sử, không phải source of truth cho UI beta hiện tại.

## Ghi chú tên nhánh

Yêu cầu sử dụng tên `refactor/frontend-beta`, nhưng ref hiện có trong repository tại thời điểm lập tài liệu là `refactor/fronend-beta`. Các tài liệu giữ tên ref thực tế khi mô tả Git và dùng “nhánh refactor” khi nói về định hướng sản phẩm.
