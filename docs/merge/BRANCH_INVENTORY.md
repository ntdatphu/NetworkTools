# Kiểm kê nhánh

Mốc so sánh: `frontend/test` tại `1c82650`. `Behind` là commit chỉ có ở nhánh
nền; `Ahead` là commit chỉ có ở ref được kiểm kê. Số file `app/` không tính
`app/uv.lock`.

## Toàn bộ ref hiện có sau fetch/prune

| Ref | Commit | Behind | Ahead | File `app/` | Python | QML | SVG | File test |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| `frontend/test` | `1c82650` | 0 | 0 | 335 | 77 | 145 | 50 | 15 |
| `origin/merge-v-p` | `1c82650` | 0 | 0 | 335 | 77 | 145 | 50 | 15 |
| `frontend/merges` (nhánh đích) | `HEAD` | 0 | 2 | 382 | 104 | 165 | 50 | 18 |
| `frontend/merge` | `a100303` | 0 | 1 | 368 | 95 | 160 | 50 | 17 |
| `merge/frontend/test` | `3afb640` | 0 | 1 | 368 | 95 | 160 | 50 | 17 |
| `feature/tools-extension-nqv` | `7335f48` | 0 | 10 | 445 | 109 | 170 | 94 | 18 |
| `origin/feature/tools-extension-nqv` | `7335f48` | 0 | 10 | 445 | 109 | 170 | 94 | 18 |
| `origin/sftp` | `5dbd17a` | 8 | 3 | 391 | 84 | 147 | 94 | 11 |
| `origin/main` | `3a3d251` | 26 | 4 | 293 | 67 | 128 | 37 | 6 |
| `origin/Chong_cua_Miku` | `f298cc3` | 26 | 5 | 293 | 67 | 128 | 37 | 6 |
| `origin/backup-main-before-merge` | `23ca9bf` | 65 | 5 | 257 | 51 | 122 | 33 | 0 |
| `origin/refactor/frontend-beta` | `da26e83` | 36 | 1 | 290 | 63 | 128 | 37 | 4 |
| `frontend/changes` | `d4b8aae` | 15 | 0 | 311 | 67 | 133 | 50 | 9 |
| `origin/frontend/changes` | `69be753` | 17 | 0 | 311 | 67 | 133 | 50 | 9 |
| `origin/nqv-acl` | `fda2c5e` | 22 | 0 | 311 | 76 | 135 | 37 | 7 |
| `origin/nqv-nat` | `e5b6f4a` | 23 | 0 | 299 | 71 | 128 | 37 | 6 |
| `nqv-nat` | `4d9035d` | 24 | 0 | 299 | 71 | 128 | 37 | 6 |
| `main` | `1018544` | 26 | 0 | 293 | 67 | 128 | 37 | 6 |
| `test-nqv` | `4b8f6ae` | 27 | 0 | 293 | 67 | 128 | 37 | 6 |
| `origin/Fix_Loi` | `57e0d80` | 77 | 0 | 241 | 43 | 118 | 32 | 0 |

Nhánh đích cuối có 382 file trong `app/`: 104 Python, 165 QML, 50 SVG và 18
file test. Phần tăng sau checkpoint `c6dc6df` là Device Logs, Tool Catalog và
test tương ứng.

## Nhánh nguồn chính

`feature/tools-extension-nqv` là hậu duệ trực tiếp của `frontend/test` với 10
commit riêng. Diff so với nền:

- 138 file thay đổi;
- 110 file mới, 28 file sửa;
- khoảng 13.651 dòng thêm, 108 dòng xóa;
- thêm SFTP, Logs/capture, Switching, installer và thay CLI/SSH.

Commit riêng:

| Commit | Nội dung quan sát |
|---|---|
| `734e868`, `43c97b0`, `5dbd17a` | Tích hợp, sửa SFTP và host lạ. |
| `89fd398`, `07ea9e2` | Packet capture/Logs và chỉnh UI. |
| `03429d9` | Màu/icon SFTP. |
| `1483cd0` | Switching, installer công cụ, thay CLI. |
| `0a70d06`, `7335f48` | Native SSH và compatibility thuật toán cũ. |

Nhánh này có ý tưởng hữu ích nhưng trộn nhiều concern trong một chuỗi commit,
dùng package sai chính tả, asset riêng lớn, blocking work và thay đổi bảo mật.
Vì vậy không được merge nguyên commit.

## Nhánh có commit riêng nhưng không nhận

| Ref | Khác biệt chính | Kết luận |
|---|---|---|
| `origin/sftp` | Bản SFTP sớm: 72 file, 3.937 dòng thêm, phần lớn là icon và package `sftpCient`. | Chỉ dùng làm lịch sử nguồn; bản viết lại dựa trên contract hiện tại. |
| `origin/main` | Đổi/di chuyển backend/API, sync DHCP. | Package path/schema không khớp cây hiện tại. |
| `origin/Chong_cua_Miku` | Đổi backend thành `backend_cua_kien`, thêm môi trường. | Rename không chuyển đồng bộ import/schema end-to-end. |
| `origin/backup-main-before-merge` | 6 file về Interface/OSPF sync, sample config, DB nhị phân. | Import sai vị trí và dùng tên bảng legacy/non-canonical. |
| `origin/refactor/frontend-beta` | Xóa helper DHCP, thay DB nhị phân. | Không có lát cắt độc lập phù hợp để nhận. |

## Nhánh đã là tổ tiên

Các ref có `Ahead = 0` đã nằm trong lịch sử `frontend/test`; merge lại chỉ tạo
conflict hoặc duplicate: `frontend/changes`, `origin/frontend/changes`,
`origin/nqv-acl`, `origin/nqv-nat`, `nqv-nat`, `main`, `test-nqv`,
`origin/Fix_Loi`.

## Ref đã bị prune

Sau `git fetch --all --prune`:

- `origin/frontend/beta/dhcp`
- `origin/test-nqv`

không còn tồn tại trên remote và không được dùng làm nguồn merge.
