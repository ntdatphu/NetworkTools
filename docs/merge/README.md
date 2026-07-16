# Smart merge report: `frontend/merge`

## Mục tiêu

Nhánh `frontend/merge` được tạo từ `frontend/test` tại commit `1c82650`
(`origin/merge-v-p`). Việc tích hợp được thực hiện theo tính năng và hợp đồng
kiến trúc, không merge nguyên commit hay nguyên cây thư mục từ các nhánh nguồn.

Quy trình áp dụng:

1. Fetch/prune toàn bộ ref và tính quan hệ ahead/behind so với `frontend/test`.
2. Kiểm kê commit, file thay đổi, tính năng và hợp đồng DB/UI của từng nhánh.
3. Chạy baseline test trên nhánh đích và test riêng nhánh có nhiều tính năng.
4. Phân loại từng tính năng: đã có sẵn, nhận trực tiếp về ý tưởng, viết lại,
   hoãn hoặc loại bỏ.
5. Tích hợp theo lát cắt nhỏ, thêm test hồi quy, sau đó chạy full suite.

## Kết quả tích hợp

- Sửa persistence OSPF/EIGRP để dùng đúng bảng chuẩn
  `t04_router_iface_ospf` và `t04_router_iface_eigrp`.
- Thêm workspace Switching theo role SW2/SW3:
  - Switch Ports, Routed Ports, VLAN, SVI;
  - Port Security, Storm Control;
  - Port Counters, MAC Table;
  - tái sử dụng DHCP Server/Relay và ACL ở SW3;
  - chỉ lưu local SQLite, chưa tự push xuống thiết bị.
- Thêm SFTP workspace độc lập:
  - duyệt local/remote, upload/download, hàng đợi và tiến độ;
  - tạo thư mục, đổi tên, xóa có xác nhận;
  - xác nhận SSH host key bằng fingerprint SHA-256;
  - toàn bộ I/O chạy ngoài UI thread và được tuần tự hóa cho Paramiko.

## Không tích hợp

- Packet capture/Log dựa trên TShark.
- Thay External Tools CLI bằng OpenSSH/Telnet và ép thuật toán SHA-1.
- Trình cài công cụ hệ thống tự động bằng `winget`.
- Các lần đổi tên toàn bộ backend hoặc di chuyển API chưa hoàn chỉnh.
- Sync OSPF/Interface từ nhánh backup dùng import và tên bảng không còn hợp lệ.
- File DB nhị phân, sample running-config và tài liệu kế hoạch cá nhân.

## Tài liệu chi tiết

- [BRANCH_INVENTORY.md](BRANCH_INVENTORY.md): quan hệ và khác biệt từng nhánh.
- [FEATURE_DECISIONS.md](FEATURE_DECISIONS.md): quyết định theo tính năng.
- [VALIDATION.md](VALIDATION.md): baseline, kiểm nghiệm nhánh nguồn và kết quả test.
