# Kiểm kê nhánh

Mốc so sánh là `frontend/test` tại `1c82650`. “Behind” là số commit chỉ có ở
nhánh nền; “Ahead” là số commit chỉ có ở nhánh được kiểm kê.

## Nhánh đích và nhánh tương đương

| Ref | Behind | Ahead | Kết luận |
|---|---:|---:|---|
| `frontend/test` | 0 | 0 | Nhánh nền cục bộ. |
| `origin/merge-v-p` | 0 | 0 | Upstream thực tế của nhánh nền. |
| `frontend/merge` | 0 | 1 | Nhánh đích sau smart merge, giữ toàn bộ thay đổi trong một commit tích hợp có kiểm nghiệm. |
| `merge/frontend/test` | 0 | 1 | Bản smart-merge cục bộ đã kiểm nghiệm; commit `3afb640` được tái sử dụng theo kiểu no-commit rồi xác minh lại trên nhánh đích. |

## Nhánh có commit riêng cần đánh giá

| Ref | Commit đầu nhánh | Behind | Ahead | Khác biệt chính | Quyết định |
|---|---|---:|---:|---|---|
| `origin/feature/tools-extension-nqv` | `7335f48` | 0 | 10 | SFTP, packet capture/log, Switching, installer `winget`, thay đổi CLI/SSH; 138 file, khoảng 13.651 dòng thêm. | Không merge commit. Lấy ý tưởng và viết lại OSPF, Switching, SFTP; loại phần còn lại. |
| `origin/sftp` | `5dbd17a` | 8 | 3 | Bản SFTP độc lập ban đầu, 72 file và bộ icon lớn. | Dùng làm lịch sử nguồn; lấy phiên bản mới hơn trên tools branch làm tham chiếu rồi viết lại. |
| `origin/main` | `3a3d251` | 26 | 4 | Đổi/di chuyển backend và API, sync DHCP. | Không merge vì package path/schema không khớp cây hiện tại. |
| `origin/Chong_cua_Miku` | `f298cc3` | 26 | 5 | Đổi backend thành `backend_cua_kien`, thêm `pyproject.toml`/`uv.lock`. | Loại: đổi tên thư mục không giải quyết import/schema end-to-end. |
| `origin/backup-main-before-merge` | `23ca9bf` | 65 | 5 | Sync Interface/OSPF, sample config, thay đổi DB nhị phân. | Loại: import sai vị trí và dùng tên bảng legacy/non-canonical. |
| `origin/refactor/frontend-beta` | `da26e83` | 36 | 1 | Xóa helper DHCP và thay DB nhị phân. | Không có tính năng độc lập phù hợp để nhận. |

### Commit riêng của `feature/tools-extension-nqv`

| Commit | Nội dung quan sát |
|---|---|
| `734e868`, `43c97b0`, `5dbd17a` | Tích hợp và sửa SFTP. |
| `89fd398`, `07ea9e2` | Packet capture/log và điều chỉnh giao diện. |
| `03429d9` | Màu/icon SFTP. |
| `1483cd0` | Switching, installer công cụ ngoài, thay đổi CLI. |
| `0a70d06`, `7335f48` | Sửa SSH/CLI theo hướng gọi native client và bật thuật toán cũ. |

### Vấn đề cụ thể trên các nhánh bị loại

- `backup-main-before-merge` import
  `network_code.interface.sync_interface` trong khi module thực nằm ở vị trí
  khác, đồng thời dùng các tên như `interface_name`, `ospf_processes` thay vì
  schema có prefix hiện tại.
- `origin/main` có thay đổi DHCP helper đúng về mặt ý tưởng, nhưng nằm trong
  một backend/API chưa khớp package path và trả trạng thái tác vụ nền trước khi
  có kết quả thực.
- `Chong_cua_Miku` chỉ đổi vị trí/thư mục backend; các hợp đồng import và DB
  chưa được chuyển đồng bộ.
- `refactor/frontend-beta` mang DB nhị phân vào diff và không cung cấp lát cắt
  tính năng có thể kiểm thử độc lập.

## Nhánh đã là tổ tiên của nhánh nền

Các ref dưới đây có `Ahead = 0`; tính năng của chúng đã nằm trong
`frontend/test`, nên merge lại chỉ tạo nhiễu hoặc conflict:

| Ref | Behind | Trạng thái |
|---|---:|---|
| `origin/nqv-acl` | 22 | ACL đã được tích hợp. |
| `origin/nqv-nat` | 23 | NAT đã được tích hợp. |
| `nqv-nat` | 24 | Local ref cũ hơn remote và là tổ tiên. |
| `origin/Fix_Loi` | 77 | Các sửa NAT/refactor đã đi vào lịch sử nhánh nền. |
| `origin/frontend/changes` | 17 | UI/UX đã được tích hợp. |
| `frontend/changes` | 15 | Local ref có thêm commit so với remote nhưng vẫn là tổ tiên nhánh nền. |
| `main` | 26 | Local `main` cũ hơn `origin/main` và là tổ tiên nhánh nền. |
| `test-nqv` | 27 | Local ref cũ, remote đã bị prune. |

## Ref đã bị prune

Sau `git fetch --all --prune`, các remote ref không còn trên origin:

- `origin/frontend/beta/dhcp`
- `origin/test-nqv`

Chúng không được dùng làm nguồn merge sau khi remote xác nhận đã xóa.
