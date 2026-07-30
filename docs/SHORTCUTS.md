# Phím tắt đã triển khai trong desktop app

Danh sách này chỉ ghi phím tắt có `Shortcut` thật trong QML thuộc `app/` ngày 2026-07-18. Các tổ hợp dự kiến được để ở cuối tài liệu.

## 1. Toàn ứng dụng/cửa sổ

| Phím | Hành vi thực tế | Nơi khai báo |
|---|---|---|
| `Ctrl+Alt+T` | Mở CLI của device đang có tab active bằng SSH Client đang bật trong External Tools; không mở terminal hệ điều hành. Shortcut chỉ khả dụng trong Devices khi có tab active. | `Main.qml` → `ExternalToolsManager.openDeviceCli()` |
| `Ctrl+B` | Ẩn/hiện sidebar, khôi phục chiều rộng đã nhớ trong phiên; dùng được trong System Logs và disabled trong workspace SFTP độc lập. | `Main.qml` |
| `Ctrl+R` | Reload Information khi view đang active, có host và không có reload đang chạy. | `CommandRegistry.qml` → `ContentArea` |
| `Ctrl+1` | Chuyển về Devices và hiện sidebar. | `CommandRegistry.qml` → `ActivityBar` |
| `Ctrl+2` | Mở/chuyển Database theo external-tools backend; disabled nếu backend này không khả dụng. | `CommandRegistry.qml` → `ActivityBar` |
| `Ctrl+3` | Chuyển tới Settings và hiện sidebar. | `CommandRegistry.qml` → `ActivityBar` |

Các command registry ở trên bị disable khi `UiState.windowLock` hoặc `TextInput`/`TextEdit` đang focus.

## 2. Device panel

Các phím dưới đây có hiệu lực khi Devices panel nhận context phù hợp; shortcut thao tác device bị tắt khi không có selection, window đang lock hoặc ô search đang focus.

| Phím | Hành vi |
|---|---|
| `Ctrl+N` | Mở New Device. |
| `Ctrl+Shift+N` | Mở Batch New Device. |
| `F2` | Edit device đang chọn. |
| `Del` | Mở luồng xoá device đang chọn. |
| `Ctrl+Alt+P` | Ping device có trạng thái `connected`. |
| `Ctrl+Alt+C` | Connect/sync device có trạng thái `waiting`. |
| `Ctrl+Alt+R` | Reset/reconnect device có trạng thái `disconnected`. |
| `Ctrl+Alt+Down` | Down (Dev) cho device `connected`. |
| `Ctrl+Alt+Up` | Up (Dev) cho device `waiting`. |

## 3. Device tabs

| Phím | Hành vi |
|---|---|
| `Ctrl+T` | Yêu cầu mở dialog New Device; không tạo SSH tab trực tiếp. |
| `Ctrl+W` | Đóng tab device hiện tại và gọi `cli.closeDeviceSession(host)`. |
| `Ctrl+Shift+T` | Khôi phục tab UI đóng gần nhất; không tự reconnect session. |
| `Ctrl+Tab` | Chọn tab kế tiếp. |
| `Ctrl+Shift+Tab` | Chọn tab trước. |

## 4. Information và Routing Config

| Phím | Hành vi |
|---|---|
| `Ctrl+F` | Focus và chọn nội dung ô tìm kiếm trong ConfigTextViewer đang hiển thị. |
| `Enter` | Khi focus ở ô tìm kiếm, chuyển tới kết quả tiếp theo. |
| `Shift+Enter` | Khi focus ở ô tìm kiếm, quay lại kết quả trước. |
| `Ctrl + lăn chuột` | Tăng/giảm font viewer trong giới hạn 9–40 px. |

Các shortcut này có context cửa sổ nhưng chỉ enabled khi viewer tương ứng đang visible; chúng chưa thuộc command registry toàn cục.

## 5. Dialog

| Ngữ cảnh | Phím | Hành vi |
|---|---|---|
| New Device | `Enter`/`Return` | Thực thi action hiện tại. |
| New Device | `Esc` | Đóng/cancel theo trạng thái dialog. |
| Batch New Device | `Ctrl+Enter` hoặc `Ctrl+Shift+N` | Submit batch khi dialog đang hiện. |
| Batch New Device | `Esc` | Cancel/đóng. |

`Ctrl+Shift+N` vừa mở Batch dialog ở Devices panel vừa submit trong dialog. Cần kiểm tra ambiguity/focus khi cải thiện shortcut manager.

## 6. Chưa triển khai

Các shortcut sau có trong backlog nhưng **chưa tồn tại trong code**:

- `Ctrl+S`: save form hiện tại;
- `Ctrl+4..9`, `Ctrl+0`: feature navigation chưa có capability contract;
- `Ctrl+Shift+P`: mở View & Push;
- shortcut riêng cho Console Serial;
- shortcut riêng cho Device Logs, System Logs hoặc SFTP; các item hiện chỉ điều hướng bằng Activity Bar.

Registry cấp `Main` đã có cho lát cắt đầu tiên; Save/View & Push và feature navigation vẫn phải chờ capability/dirty-state contract trước khi đăng ký.
