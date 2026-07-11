# Bộ tài liệu UI beta

Ngày cập nhật: 2026-07-12

Phạm vi hiện tại: `refactor/frontend-beta` tại `f27ad97`, đối chiếu với `frontend-beta` tại `9e808c4`.

Thư mục này là source of truth cho việc đánh giá, thiết kế và tiếp tục phát triển UI beta. Mục tiêu của bộ tài liệu là tách rõ bốn câu hỏi khác nhau: **hiện trạng là gì**, **giao diện nên vận hành theo pattern nào**, **từng Feature/SubFeature cần thay đổi ra sao**, và **thực hiện theo thứ tự nào**.

## Cách đọc đề xuất

1. Đọc [change.md](change.md) để biết nhánh refactor đã thay đổi gì so với `frontend-beta`, cùng các ưu/nhược điểm và giới hạn còn lại.
2. Đọc [UI_BETA_PLAN.md](UI_BETA_PLAN.md) để xem hiện trạng UI, capability, nguyên tắc thiết kế, backlog, roadmap và quality gate.

## Vai trò từng tài liệu

| Tài liệu | Trả lời câu hỏi | Khi nào cập nhật |
|---|---|---|
| [change.md](change.md) | Nhánh refactor khác nhánh gốc ở đâu, đánh đổi gì và cần làm gì tiếp? | Khi baseline hoặc phạm vi so sánh thay đổi |
| [UI_BETA_PLAN.md](UI_BETA_PLAN.md) | Hiện trạng, audit, pattern, capability, backlog, roadmap và quality gate | Khi capability, quyết định UX hoặc trạng thái work item thay đổi |

## Quan điểm thiết kế

Không dùng một “mẫu màn hình chuẩn” duy nhất cho toàn bộ sản phẩm. Routing theo process hierarchy, ACL theo rule ordering, DHCP theo entity list, Monitor theo dashboard và Settings theo catalog có mô hình tư duy khác nhau. Ép chúng vào cùng một bố cục sẽ làm UI giống nhau về hình thức nhưng khó dùng.

Sự thống nhất nên nằm ở các lớp sau:

- Theme token, typography, spacing, icon và motion.
- Feature header, device context, capability banner và trạng thái request.
- Validation, dirty state, save/preview/push semantics.
- Empty/loading/error/read-only/unsupported state.
- Keyboard, focus, accessibility, localization và responsive rules.
- List/table metadata, dialog shell và notification/task feedback.

Phần nội dung có thể chọn một trong nhiều họ giao diện theo workflow. Quy tắc chọn, capability matrix và roadmap được mô tả trong [UI_BETA_PLAN.md](UI_BETA_PLAN.md).

## Quy tắc duy trì

- Mọi nhận định về capability phải trỏ được tới backend/controller hiện tại; không suy ra từ việc form trông hoàn chỉnh.
- “Có UI”, “có local CRUD”, “có preview” và “có push end-to-end” là bốn mức khác nhau.
- Mọi Feature/SubFeature mới phải có pattern family, owner dữ liệu, capability level, validation matrix và test plan trước khi code form.
- Không thêm abstraction chung nếu chưa có ít nhất hai consumer thật; table/policy/process abstraction nên có ba consumer hoặc một pilot chứng minh được contract.
- Thay đổi code làm kết luận tài liệu sai phải cập nhật tài liệu trong cùng PR.
- File trong `md_by_old/` chỉ là tài liệu lịch sử, không phải source of truth cho UI beta hiện tại.

## Ghi chú tên nhánh và nguồn sự thật

Tên nhánh hiện có là `refactor/frontend-beta` (đúng chính tả). `change.md` là báo cáo so sánh canonical và `UI_BETA_PLAN.md` là nguồn sự thật cho kế hoạch UI. Những file trong `md_by_old/` là tài liệu lịch sử và không được dùng để suy luận capability hiện tại.
