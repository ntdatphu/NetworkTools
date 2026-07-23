# Dialog inventory and standard

## Inventory hiện tại

| Component | Loại | Vai trò | Sai khác cần xử lý |
|---|---|---|---|
| `NewDevice.qml` | Frameless `Window` | Add/Edit device | Mẫu tham chiếu |
| `BatchNewDevice.qml` | Frameless `Window` | Batch add | Đã gần mẫu tham chiếu |
| `AddYangcfg.qml` | Frameless `Window` | Add YANG credentials | Đã gần mẫu tham chiếu |
| `CustomAlert.qml` | Frameless `Window` | Alert | Cần giữ semantic alert nhưng đồng bộ title/actions |
| `SftpEntryDialog.qml` | `Dialog` | New folder/Rename | Header màu riêng, thiếu close button |
| `SftpMessageDialog.qml` | `Dialog` | Confirm/error | Header màu riêng, thiếu close button |
| `SftpConnectionDialog.qml` | `Dialog` | Edit connection | Header màu riêng, thiếu close button |
| `SyslogSourceInterfaceDialog.qml` | `Dialog` | Chọn source interface | Cần chuyển sang primitive chuẩn |
| `SyslogMessageDetails.qml` | `Dialog` | Chi tiết log | Cần chuyển sang primitive chuẩn |
| `ExternalToolsSettings.qml` | `Dialog` | Xác nhận xóa tool | Cần chuyển sang primitive chuẩn |
| `Main.qml` about dialog | `Dialog` mặc định | About | Khác hoàn toàn hệ thiết kế |
| `ViewPushDialog.qml` | `Popup` | Preview/push config | Giữ kích thước riêng, dùng title/footer chuẩn |
| `NotificationPanel.qml` | `Popup` modeless | Notification center | Không phải dialog; không áp dụng modal standard |

## Contract dialog chuẩn

- Căn giữa trong `Overlay.overlay`, modal và dim.
- Nền `Theme.contentPanelSurface`, border/radius token, shadow nhẹ.
- Padding ngoài 24 px; title bar dùng `DialogTitleBar`, có title, subtitle tùy
  chọn và nút đóng.
- Action footer nằm phải; Cancel dạng `Text`, primary/destructive action đứng
  cuối.
- `Escape` đóng khi không có thao tác nguy hiểm đang chạy; Enter chỉ submit khi
  form xác định rõ default action.
- Khi mở: acquire application interaction lock và focus field đầu tiên. Khi
  đóng: release lock.
- Main workspace blur nhẹ trong lúc lock. Popup modal dùng cùng
  `Theme.dialogOverlay`; top-level child window có scrim tương ứng.
- Dialog phải co theo viewport và nội dung dài phải scroll; không cắt action.
- Accessible name/description lấy từ title/subtitle và button tooltip.

## Tiêu chí nghiệm thu UI-01/UI-02

1. New Folder và Rename SFTP có cùng title bar, close button, surface, spacing và
   action hierarchy với Add New Device.
2. Tất cả dialog modal trong inventory dùng primitive/contract chuẩn hoặc ghi rõ
   ngoại lệ.
3. Mở dialog làm nền chính mờ nhẹ và không nhận click/shortcut.
4. Đóng bằng Cancel, close button hoặc Escape đều giải phóng lock.
5. QML module load không có warning mới; smoke test tạo được từng dialog.
