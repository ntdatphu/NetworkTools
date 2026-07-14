# Phím tắt đã triển khai trong desktop app

Danh sách này chỉ ghi phím tắt có `Shortcut` thật trong QML thuộc `app/` ngày 2026-07-14. Các tổ hợp dự kiến được để ở cuối tài liệu.

## 1. Toàn ứng dụng/cửa sổ

| Phím | Hành vi thực tế | Nơi khai báo |
|---|---|---|
| `Ctrl+Alt+T` | Mở terminal hệ điều hành tại thư mục `app/`; không phải Console Serial và không tự SSH tới device đang chọn. | `Main.qml` |
| `Ctrl+B` | Ẩn/hiện sidebar, khôi phục chiều rộng đã nhớ trong phiên. | `Main.qml` |

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
| Add YANG config | `Enter`/`Return` | Add nếu nút đang enabled. |
| Add YANG config | `Esc` | Đóng alert hoặc dialog. |

`Ctrl+Shift+N` vừa mở Batch dialog ở Devices panel vừa submit trong dialog. Cần kiểm tra ambiguity/focus khi cải thiện shortcut manager.

## 6. Chưa triển khai

Các shortcut sau có trong backlog nhưng **chưa tồn tại trong code**:

- `Ctrl+R`: reload feature hiện tại;
- `Ctrl+S`: save form hiện tại;
- `Ctrl+1..9`, `Ctrl+0`: Activity Bar/feature navigation;
- `Ctrl+Shift+P`: mở View & Push;
- shortcut riêng cho Console Serial;
- shortcut cho Logs hoặc SFTP (hai item này cùng Console Serial đang hiển thị ở trạng thái coming-soon/disabled, chưa có Content Area).

Khi triển khai, cần một action/command registry ở cấp `Main` để tránh mỗi form tạo Shortcut trùng nhau và để disable theo `UiState.windowLock`, focus của input và dirty state.
