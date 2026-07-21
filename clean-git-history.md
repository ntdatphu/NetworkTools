# Nhiệm vụ: Viết lại commit message trong Git history (KHÔNG đổi code)

## Bối cảnh

Repo này có nhiều commit với message vô nghĩa (VD: "fix", "wip", "asdf").
Cần viết lại message theo chuẩn Conventional Commits, **giữ nguyên toàn bộ nội dung code**.
Đây là thao tác rewrite history, phải làm cẩn thận theo đúng các bước dưới đây, KHÔNG được bỏ qua bước nào.

## Phạm vi commit cần xử lý

Range: `<ĐIỀN_RANGE_Ở_ĐÂY>`   (ví dụ: `main-backup-20260721..main`, hoặc `HEAD~30..HEAD`)

## QUY TẮC BẮT BUỘC (không được vi phạm)

1. **Không được force-push** dưới bất kỳ hình thức nào. Dừng lại sau khi rewrite xong ở local, để tôi tự kiểm tra và push tay.
2. **Không được squash/gộp commit.** Số lượng commit phải giữ nguyên như cũ — chỉ đổi message, không đổi code, không gộp/xóa commit.
3. **Không được sửa nội dung code trong bất kỳ commit nào.** Sau khi xong, `git diff <backup-branch>..<branch-hiện-tại>` phải hoàn toàn rỗng.
4. **Phải tạo backup trước khi bắt đầu**, đặt tên `backup-git-cleanup-<ngày-hôm-nay>`.
5. **Xử lý theo từng lô nhỏ** (khoảng 15-20 commit/lần), dừng lại sau mỗi lô để tôi xem qua trước khi tiếp tục lô sau.
6. Nếu gặp conflict hoặc bất kỳ tình huống không chắc chắn nào khi rebase → **DỪNG LẠI ngay, không tự ý resolve**, báo cáo lại cho tôi tình trạng hiện tại và các lệnh cần chạy tiếp (`git rebase --continue` / `git rebase --abort`).

## Chuẩn message cần áp dụng

Format: `<type>(<scope tùy chọn>): <mô tả ngắn gọn>`

Các `type` hợp lệ: `feat`, `fix`, `refactor`, `docs`, `chore`, `test`, `style`, `perf`, `build`, `ci`

Ví dụ:

- `fix(auth): xử lý lỗi token hết hạn không refresh được`
- `feat(cart): thêm chức năng lưu giỏ hàng tạm`
- `chore: cập nhật dependency eslint lên v9`

## Các bước thực hiện

### Bước 1 — Backup

```bash
git branch backup-git-cleanup-$(date +%Y%m%d)
```

### Bước 2 — Xem danh sách commit cần xử lý

```bash
git log --oneline <RANGE>
```
In ra cho tôi xem danh sách này trước khi làm tiếp.

### Bước 3 — Với mỗi commit trong lô hiện tại

1. Xem diff: `git show <hash>`
2. Đọc hiểu thay đổi thực sự làm gì (đọc code, không chỉ đọc message cũ)
3. Viết message mới theo chuẩn ở trên
4. Dùng `git rebase -i <RANGE>`, đánh dấu commit cần sửa là `reword`, rồi thay message

### Bước 4 — Kiểm tra sau khi xong mỗi lô

```bash
git diff backup-git-cleanup-$(date +%Y%m%d)..HEAD
```

Phải rỗng (không có gì khác ngoài message). Nếu có khác biệt về code → DỪNG LẠI, báo tôi ngay.

### Bước 5 — Báo cáo

Sau mỗi lô, in ra:

- Danh sách commit đã đổi: message cũ → message mới
- Kết quả `git diff` (xác nhận rỗng)
- Hỏi tôi có muốn tiếp tục lô kế tiếp không

### Bước 6 — Khi xong toàn bộ range

KHÔNG tự động push. Dừng lại và nói cho tôi biết:

- Tổng số commit đã reword
- Nhắc tôi tự kiểm tra `git log` rồi tự chạy `git push --force-with-lease origin <branch>` khi tôi sẵn sàng
