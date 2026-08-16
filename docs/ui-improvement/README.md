# UI improvement contracts

Cập nhật: **2026-08-16**. Chương trình cải tiến UI ban đầu đã được tích hợp vào
QML hiện hành; progress log và plan responsive/sidebar đã hoàn tất được xóa để
không trở thành nguồn sự thật song song. Thư mục này chỉ giữ các contract kỹ
thuật còn hữu ích cho regression và review.

| Tài liệu | Dùng để kiểm tra |
| --- | --- |
| `CONTEXT_SHORTCUT_INVENTORY.md` | Bề mặt context menu và ownership shortcut |
| `DIALOG_INVENTORY.md` | `StandardDialog`, modal lock và cấu trúc dialog |
| `NETWORK_FIELD_FOCUS.md` | Focus/caret của `StandardNetworkField` |
| `OPEN_EDITORS.md` | Sidebar Open Editors và System Logs |
| `PANEL_SIDEBAR_SNAP.md` | Kéo/collapse PanelSideBar |
| `SPINBOX_INVENTORY.md` | Domain/range của SpinBox |
| `TOAST_NOTIFICATIONS.md` | Toast, notification center và action |
| `SFTP_BEHAVIOR.md` | Interaction contract SFTP; vận hành ở `../SFTP.md` |

Contract cấp component mới nằm tại [`../UI_COMPONENTS.md`](../UI_COMPONENTS.md),
shortcut người dùng tại [`../SHORTCUTS.md`](../SHORTCUTS.md). Khi hành vi QML
thay đổi, cập nhật contract liên quan và regression test; không tạo progress log
dài hạn mới trong thư mục này.
