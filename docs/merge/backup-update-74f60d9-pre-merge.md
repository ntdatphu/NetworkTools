# Đối chiếu cập nhật backup `74f60d9` trước merge

- Thời điểm kiểm tra: 2026-07-10 (Asia/Bangkok)
- Nhánh đích: `frontend/beta` tại `d145a379b6928945898024bfbf017901bcbdeb01`
- Backup đã merge lần trước: `77d55593a40053f44d4687816727ca1deda3ba7d`
- Tip mới sau `git fetch`: `origin/backup-main-before-merge` tại `74f60d9c955ee7836c8a2a2a3e94b5f03e3d294e`
- Merge-base với nhánh đích: `77d55593a40053f44d4687816727ca1deda3ba7d`
- Quan hệ lịch sử: tip mới là hậu duệ trực tiếp của backup cũ.
- Worktree trước phân tích: sạch.

## Commit mới trên backup

1. `dcb7243` — tích hợp Database Browser.
2. `ae7fccf` — cập nhật ACL/API.
3. `2389920` — sửa NAT route-map.
4. `57e0d80` — refactor/fix NAT.
5. `74f60d9` — merge `Fix_Loi` vào backup.

Tổng patch mới: 38 file, +1.467 / -1.899 dòng. Trong `app/`, thay đổi chính gồm Database Browser, cấu hình External Tools, `ExternalToolsManager`, icon/database panels và di chuyển API server ra root. Ngoài `app/`, patch sửa NAT/ACL và loại các file cấu hình thử nghiệm cũ.

## Dự báo conflict trước merge

### Conflict nội dung (5)

- `app/main.py`
- `app/UI/qml/app/Main.qml`
- `app/UI/qml/content/ContentArea.qml`
- `app/UI/qml/panels/PanelSideBar.qml`
- `app/UI/qmldir`

### Modify/delete cần quyết định (1)

- `app/network_code/api_server.py`: nhánh đích đã sửa file; backup di chuyển và mở rộng thành `api_server.py` ở root.

### File được sửa ở cả hai phía nhưng dự kiến auto-merge (4)

- `app/core/runtime.py`
- `app/UI/qml/content/SettingsView.qml`
- `app/UI/qml/layout/ActivityBar.qml`
- `app/network_code/routing/main.py`

## Tiêu chí xử lý

1. Giữ signal thiết bị 4 tham số, connect/push async, `session_provider`, timeout và cleanup session hiện có trên `frontend/beta`.
2. Tích hợp Database Browser và External Tools mà không làm mất Logs/Alerts, settings và layout hiện tại.
3. Chấp nhận API server mới ở root vì dùng đúng package `backend.PyCode` và bổ sung endpoint ACL/NAT; loại bản cũ dưới `app/network_code` sau khi xác nhận không còn caller.
4. Chỉ giữ cờ trạng thái thiết bị `dev`; không phục hồi `admin` từ backup.
5. Không commit `app/external_tools.db`: đây là DB runtime được `ExternalToolsManager` tự tạo. Thêm ignore thay vì lưu binary mutable.
6. Giữ sửa lỗi NAT/ACL từ `Fix_Loi`, sau đó chạy parse/import và test phù hợp; không gọi thiết bị thật.
7. Sau merge phải tải QML offscreen, kiểm tra migration/schema, Database Browser/External Tools trên DB tạm và quét marker conflict/diff whitespace.

## Lệnh kiểm tra chính

```powershell
git fetch --prune origin backup-main-before-merge Fix_Loi
git merge-base frontend/beta origin/backup-main-before-merge
git merge-base --is-ancestor 77d5559 origin/backup-main-before-merge
git log --graph --oneline 77d5559..origin/backup-main-before-merge
git diff --stat 77d5559..origin/backup-main-before-merge
git diff --name-status 77d5559..origin/backup-main-before-merge -- app
git merge-tree --trivial-merge 77d5559 frontend/beta origin/backup-main-before-merge
```
