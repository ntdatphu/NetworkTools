# UI improvement program

Tài liệu này theo dõi chuỗi cải tiến UI/UX được thực hiện từ ngày 2026-07-23.
Mỗi hạng mục được triển khai và kiểm thử độc lập trước khi chuyển sang hạng mục
tiếp theo. Thứ tự ưu tiên chọn theo nguyên tắc: thay đổi nền tảng có ít phụ thuộc
được làm trước, hành vi nghiệp vụ và persistence làm sau.

## Thứ tự triển khai

| ID | Hạng mục | Lý do xếp thứ tự | Trạng thái |
|---|---|---|---|
| UI-01 | Inventory và primitive dialog chuẩn | Tạo nền tảng dùng lại, ít phụ thuộc nghiệp vụ | Done |
| UI-02 | Modal dim/blur và khóa tương tác cửa sổ chính | Đi cùng lifecycle dialog, không phụ thuộc feature | Done |
| UI-03 | Tự reload khi kích hoạt Feature/SubFeature | Contract lifecycle chung, cần ổn định trước khi sửa view riêng | Done |
| UI-04 | Màu Permit/Deny, ActivityBar, Interface actions, Information diff | Các chỉnh sửa presentation độc lập | Done |
| UI-05 | SpinBox theo domain | Cần inventory giới hạn/bước tăng của từng consumer | Done |
| UI-06 | SFTP external client và điều hướng chuột | Dựa trên catalog/history sẵn có | Done |
| UI-07 | SFTP metadata, selection, context menu và shortcut | Phụ thuộc selection contract và navigation ổn định | Done |
| UI-08 | SFTP password opt-in và setting tự lưu | Thay đổi persistence/security, thực hiện sau cùng | Done |
| UI-09 | Context menu/shortcut cho collection giá trị cao | Hoàn tất sau khi command SFTP ổn định | Done |
| UI-10 | Regression/visual QA và cập nhật tài liệu | Khóa kết quả toàn chương trình | Done |

## Nguyên tắc

- Không thay đổi đồng thời nhiều contract chưa liên quan.
- Mỗi hạng mục có test contract hoặc smoke test tương ứng.
- Giữ draft/selection khi reload có thể làm mất dữ liệu; view clean được reload
  ngay khi kích hoạt.
- Mật khẩu không được truyền qua command line cho ứng dụng ngoài.
- Lưu mật khẩu luôn là opt-in, có cảnh báo, mặc định tắt và không được mô tả như
  lựa chọn khuyến nghị.
- Không dùng màu là tín hiệu duy nhất cho Permit/Deny hoặc trạng thái.
- Không ghi đè thay đổi đang dở của người dùng trong working tree.

## Tài liệu tham chiếu

- [Qt Quick Controls Overlay](https://doc.qt.io/qt-6/qml-qtquick-controls-overlay.html):
  modal popup đặt trên overlay và dùng `Overlay.modal` để dim nền.
- [Qt SpinBox](https://doc.qt.io/qt-6/qml-qtquick-controls-spinbox.html):
  `from`, `to`, `stepSize`, editable input và indicator phải cùng thao tác trên
  một giá trị đã được kiểm tra.
- [VS Code user interface](https://code.visualstudio.com/docs/editing/userinterface):
  Explorer hỗ trợ create/delete/rename, context menu và multi-selection.
- [WinSCP Commander shortcuts](https://winscp.net/eng/docs/ui_commander_key):
  `Ctrl+R`/`F5` reload, `Alt+Up` parent, `Alt+Left`/`Alt+Right` history.
- [WinSCP navigation](https://winscp.net/eng/docs/task_navigate):
  chuột Back/Forward điều hướng lịch sử thư mục.

Chi tiết dialog nằm tại [DIALOG_INVENTORY.md](DIALOG_INVENTORY.md), contract
SpinBox tại [SPINBOX_INVENTORY.md](SPINBOX_INVENTORY.md), và nhật ký nghiệm thu
tại [PROGRESS.md](PROGRESS.md). Hành vi SFTP được ghi tại
[SFTP_BEHAVIOR.md](SFTP_BEHAVIOR.md); phạm vi menu/shortcut tại
[CONTEXT_SHORTCUT_INVENTORY.md](CONTEXT_SHORTCUT_INVENTORY.md).
