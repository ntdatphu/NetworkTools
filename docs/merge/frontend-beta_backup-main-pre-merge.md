# Đối chiếu trước merge: `frontend/beta` và `backup-main-before-merge`

- Thời điểm đánh giá: 2026-07-10 (Asia/Bangkok)
- Nhánh đích đang checkout: `frontend/beta`
- Commit nhánh đích: `dcf2308f191967a361813efcd848ddadcf13c5b5`
- Nhánh gốc xác nhận: `frontend/bugs-fixed` cũng trỏ tới `dcf2308f191967a361813efcd848ddadcf13c5b5`
- Nhánh nguồn hiện chỉ có remote-tracking ref: `origin/backup-main-before-merge`
- Commit nhánh nguồn: `77d55593a40053f44d4687816727ca1deda3ba7d`
- Merge-base: `1dd6f45f2c8282f162360687a00229963a91a96a`
- Worktree trước đánh giá: sạch (`## frontend/beta`)

## Hướng merge được chọn

Giữ `frontend/beta` làm nhánh đích và merge `origin/backup-main-before-merge` vào nhánh này. Lý do: yêu cầu xác định `frontend/beta` là nhánh phát triển từ `frontend/bugs-fixed`, worktree hiện cũng đang ở `frontend/beta`, và cách này giữ nguyên sáu commit sửa lỗi/tính năng frontend trong lịch sử nhánh đích.

## Lệnh chỉ đọc đã chạy trước khi thay đổi worktree

```powershell
git status --short --branch
git branch --all --verbose --no-abbrev
git log --graph --oneline --decorate --all -n 40
git merge-base frontend/beta origin/backup-main-before-merge
git merge-base frontend/bugs-fixed frontend/beta
git rev-list --left-right --count frontend/beta...origin/backup-main-before-merge
git log --left-right --cherry-pick --oneline frontend/beta...origin/backup-main-before-merge
git diff --shortstat 1dd6f45..frontend/beta -- app
git diff --shortstat 1dd6f45..origin/backup-main-before-merge -- app
git diff --shortstat frontend/beta..origin/backup-main-before-merge -- app
git diff --name-status frontend/beta..origin/backup-main-before-merge -- app
git diff --numstat frontend/beta..origin/backup-main-before-merge -- app
git diff --dirstat=files,0 frontend/beta..origin/backup-main-before-merge -- app
git merge-tree --trivial-merge 1dd6f45 frontend/beta origin/backup-main-before-merge
git show --stat --summary origin/merge/frontend-bugs-fixed_backup
```

## Kết quả định lượng trước merge

| Phép so sánh trong `app/` | Kết quả |
|---|---:|
| Merge-base → `frontend/beta` | 137 file; +6.338 / -2.125 dòng |
| Merge-base → nhánh backup | 48 file; +1.931 / -1.429 dòng |
| `frontend/beta` → nhánh backup | 139 file; +2.633 / -6.344 dòng |
| Commit riêng của `frontend/beta` | 6 |
| Commit riêng của nhánh backup | 7 |
| File được sửa ở cả hai phía | 37 |
| File có conflict nội dung dự báo | 29 |

`frontend/beta` có phạm vi thay đổi lớn hơn đáng kể và chứa chuỗi sửa lỗi/tính năng UI mới. Nhánh backup bổ sung DHCP push, cập nhật schema/SQL, tài liệu LaTeX và một số thay đổi routing. Vì vậy không phù hợp để chọn toàn bộ một phía; cần giữ kiến trúc frontend mới rồi tích hợp có chọn lọc phần backend/DHCP/routing của backup.

## Conflict nội dung dự báo trong `app/`

### UI/QML (4)

- `app/UI/components/standard/StandardSideBar.qml`
- `app/UI/qml/panels/DevicesPanel.qml`
- `app/UI/qml/routing/ospf/OspfNetworksSection.qml`
- `app/UI/qml/sidebar/devices/DeviceContextMenu.qml`

### Backend DHCP (5)

- `app/backend/dhcp/common.py`
- `app/backend/dhcp/excluded.py`
- `app/backend/dhcp/helper.py`
- `app/backend/dhcp/interfaces.py`
- `app/backend/dhcp/pool.py`

### Backend routing (12)

- `app/backend/route/eigrp/child_sync.py`
- `app/backend/route/eigrp/child_writers.py`
- `app/backend/route/eigrp/common.py`
- `app/backend/route/eigrp/load.py`
- `app/backend/route/eigrp/process_store.py`
- `app/backend/route/eigrp/save.py`
- `app/backend/route/ospf/common.py`
- `app/backend/route/ospf/load.py`
- `app/backend/route/ospf/process_compare.py`
- `app/backend/route/ospf/process_store.py`
- `app/backend/route/ospf/save.py`
- `app/backend/route/static_route.py`

### Core/runtime (2)

- `app/core/database.py`
- `app/core/runtime.py`

### Network workers/API (6)

- `app/network_code/dhcp/main.py`
- `app/network_code/dhcp/worker_dhcp.py`
- `app/network_code/PyCode/share/config.py`
- `app/network_code/routing/main.py`
- `app/network_code/routing/ospf_api.py`
- `app/network_code/routing/worker_routing.py`

## Tiêu chí giải conflict trước khi merge

1. Giữ cơ chế task nền/progress toast của `frontend/beta` để tránh chặn UI thread.
2. Giữ API và tên signal nhất quán từ QML qua `runtime.py`, database và worker; không chọn từng hunk tách rời nếu làm đứt chuỗi gọi.
3. Tích hợp DHCP push, schema và routing mới từ backup khi không làm mất validation, trạng thái `success/action_Cfg` hoặc sửa lỗi đã có ở beta.
4. Ưu tiên truy vấn theo batch/cache, tránh mở kết nối DB và gọi thiết bị lặp trong vòng lặp UI.
5. Xóa code cũ chỉ khi đã xác nhận không còn import/reference; giữ tài nguyên mới của cả hai nhánh khi không trùng chức năng.
6. Sau merge phải kiểm tra marker conflict, compile Python, import chính, QML syntax/reference, schema SQLite và các test/build sẵn có.

## Nguồn tham khảo bổ sung

Remote có merge commit cũ `6663d6d` (`origin/merge/frontend-bugs-fixed_backup`). Commit này chỉ được dùng để đối chiếu các quyết định đã từng thử; không được dùng làm kết quả mặc định vì yêu cầu hiện tại cần tự đánh giá lại hiệu suất, lỗi và tính năng.

## Trạng thái tài liệu

Đây là snapshot **trước merge**. Quyết định theo từng conflict, thay đổi tối ưu bổ sung và kết quả kiểm thử sẽ được ghi tiếp vào tài liệu hậu kiểm trong cùng thư mục.
