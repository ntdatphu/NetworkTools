# System Logs (Syslog)

Cập nhật ngày **2026-07-18**. Tài liệu này mô tả tính năng Syslog đã tích hợp vào
desktop app; **System Logs** không phải màn hình **Device Logs** dùng TShark.

## 1. Luồng runtime

```text
Thiết bị UDP/TCP
    → SyslogReceiver
    → SyslogWriter (queue có giới hạn)
    → Syslog parser
    → SyslogRepository / info_collected.db
    → SyslogManager (Qt context)
    → SyslogWorkspace / DataTable
```

`app/main.py` tạo một `SyslogManager`, đăng ký `syslogManager` và
`syslogSettings` cho QML, rồi gọi `shutdown()` khi ứng dụng thoát. Listener chỉ
tự bật khi setting `enabledOnStartup` được bật; lỗi auto-start được ghi ra stderr
thay vì làm hỏng quá trình tải UI.

Receiver hỗ trợ UDP hoặc TCP, còn writer tách parse/ghi SQLite khỏi thread nhận.
Queue có giới hạn để tránh tăng RAM không kiểm soát; chỉ số dropped được đưa lên
control bar. Repository dùng connection ngắn hạn và đóng handle rõ ràng để không
khóa file SQLite trên Windows.

## 2. Dữ liệu và retention

Nguồn schema là `app/database/info_collected/12_info_syslog.sql`; bản tổng hợp
`app/database/info_collected.sql` phải giữ parity với nguồn này.

| Bảng | Vai trò |
|---|---|
| `t12_syslog_messages` | Message đã parse cùng raw message, source, protocol, facility và severity. |
| `t12_syslog_device_state` | Trạng thái cấu hình Syslog theo thiết bị/destination/transport/port. |

Message nằm trong `info_collected.db`; dữ liệu định danh thiết bị trong
`device_network.db` chỉ được đọc. Retention mặc định 30 ngày và chạy theo batch
khi listener khởi động. **Clear View** không xóa database.

## 3. Hợp đồng frontend

- Activity Bar dùng `AppAssets.navigationSyslog`; không chứa literal SVG path.
- `PanelSideBar` hiển thị `SyslogDevicesPanel`, hỗ trợ search, chọn host và context
  menu cấu hình/hủy cấu hình thiết bị.
- `SyslogWorkspace` dùng `WorkspaceHeader`, `SyslogControlBar`,
  `SyslogFilterBar` và họ `DataTable*` chung.
- Settings dùng `FormSection` và các standard controls; thay đổi listener đang
  chạy cần restart để có hiệu lực.
- Workspace được lazy-load một lần, giữ tối đa 2.000 row trong model và lấy dữ
  liệu theo page 200 row. Pause chỉ dừng render; Resume reload để bù message.
- Consumer backend đều chịu được context property `null`, nhờ đó QML vẫn tải
  được trong preview/smoke test.

## 4. Cấu hình thiết bị

Context menu ở sidebar dựng command cấu hình cho Cisco IOS/IOS-XE qua session
đang có. Destination sử dụng advertised IP, protocol và port đã chọn trong
Settings; bind IP chỉ điều khiển socket local. Command builder validate IP,
transport, port và source interface trước khi gửi. Hệ điều hành thiết bị chưa
được hỗ trợ trả về lỗi rõ ràng và không ghi trạng thái configured giả.

## 5. Kiểm chứng

Các test trong `app/tests/syslog/` dùng `unittest` và bao phủ parser, command
builder, configurator, UDP/TCP receiver, writer/manager variants, repository,
settings validation và QML harness. Contract chung trong
`app/tests/test_ui_contracts.py` khóa việc dùng component chuẩn, lazy loader và
mapping resource tập trung; QML smoke kiểm tra workspace vẫn tải khi backend
không có.
