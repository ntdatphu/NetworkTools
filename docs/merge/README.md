# Smart merge report: `frontend/merges`

## Mục tiêu và nhánh nền

Nhánh đích `frontend/merges` được tạo từ `frontend/test` tại commit `1c82650`
(`origin/merge-v-p`). Nguồn ý tưởng chính là
`feature/tools-extension-nqv` tại `7335f48`, nhưng không commit nào của nhánh
nguồn được merge nguyên khối.

Nguyên tắc:

1. `frontend/test` là chuẩn về kiến trúc, ngôn ngữ UI, theme token, component
   và hành vi hiện có.
2. Tính năng được nhận theo lát cắt độc lập; code nguồn chỉ là bằng chứng về ý
   tưởng và phạm vi.
3. Mỗi lát cắt phải khớp schema/runtime hiện tại, không chặn UI thread, có giới
   hạn tài nguyên và test hồi quy.
4. Không nhận file DB/capture nhị phân, dữ liệu máy cá nhân, bộ icon trùng lặp,
   rename package chưa hoàn chỉnh hoặc thay đổi hệ thống thiếu consent.

## Quy trình đã thực hiện

1. Fetch/prune toàn bộ local/remote refs.
2. Tính ahead/behind của mọi ref so với `frontend/test`.
3. Kiểm kê file `app/` của từng nhánh, không tính `app/uv.lock`.
4. Đọc commit và diff theo module, xác định dependency, schema, QML contract,
   lifecycle worker và rủi ro bảo mật/hiệu năng.
5. Tạo `frontend/merges`, nhận checkpoint đã kiểm nghiệm cho routing,
   Switching và SFTP.
6. Viết lại Device Logs và thay ý tưởng auto-installer bằng Tool Catalog an
   toàn.
7. Chạy QML smoke, contract test, backend test và full suite.

## Kết quả tích hợp

- OSPF/EIGRP dùng đúng bảng canonical và đóng SQLite connection đúng vòng đời.
- Switching workspace thống nhất với Feature Bar/SubFeatureBar và role SW2/SW3.
- SFTP workspace độc lập, xác nhận host key SHA-256, I/O tuần tự ngoài UI thread.
- Device Logs:
  - Activity Bar item đã hoạt động;
  - TShark probe/capture/decode chạy ngoài UI thread;
  - signal packet được gom lô;
  - giới hạn 1 giờ, 256 MiB, 250.000 packet/phiên;
  - model live tối đa 5.000 dòng, giữ tối đa 20 phiên;
  - xem được phiên đã lưu khi TShark không có mặt.
- External Tools:
  - giữ CLI theo SSH Client do người dùng cấu hình, gồm Xshell/PuTTY và các
    client được nhận diện;
  - thêm Tool Catalog nhận diện installed/configured/missing;
  - app chưa cài được giảm độ nổi bật;
  - chỉ mở allowlist trang chính thức, không chạy `winget` hay tự cài.

## Không tích hợp nguyên trạng

- `backend/log_core`, `logQml`: thay bằng `app/log_monitor` và QML dùng component
  hiện tại.
- `sftpCient`, `sftpCientQml`: thay bằng `sftp_client` và `UI/qml/sftp`.
- Khoảng 47 icon SFTP riêng: không nhận vì trùng hệ thống asset/theme hiện tại.
- Native OpenSSH/Telnet và ép SHA-1: loại vì làm mất lựa chọn External Tools và
  hạ cấp bảo mật.
- Auto-installer `winget`: thay bằng catalog read-only có hành động do người
  dùng chủ động.
- Rename toàn backend, DB nhị phân, sample running-config và sync module dùng
  import/schema legacy: loại.

## Tài liệu chi tiết

- [MERGE_PLAN.md](MERGE_PLAN.md): kế hoạch, cổng chất lượng và trạng thái.
- [BRANCH_INVENTORY.md](BRANCH_INVENTORY.md): quan hệ và khác biệt mọi nhánh.
- [APP_INVENTORY.md](APP_INVENTORY.md): kiểm kê `app/` theo ref và kiến trúc.
- [FEATURE_DECISIONS.md](FEATURE_DECISIONS.md): quyết định theo tính năng.
- [VALIDATION.md](VALIDATION.md): lệnh kiểm tra, kết quả và giới hạn đã biết.
