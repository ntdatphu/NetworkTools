# UI

QML module giữ tên `UI`. `qmldir` là danh sách public component; `qml/app` chứa entry, `layout`/`panels`/`shared` chứa UI dùng chung và `qml/features` là namespace đích cho view nghiệp vụ. QML chỉ gọi context QObject/slot, không chứa SQL hoặc logic push.

Ứng dụng khởi động bằng top-level `UI/Welcome`; cửa sổ workspace `UI/Main` chỉ
được load sau khi bridge `WelcomeController` nhận Create/Open/Recent. Các component
Welcome nằm trong `qml/welcome` và dùng recent-project mock cho đến khi package
backend `.ntp` hoàn tất. `WorkspaceMenuBar.qml` là menu QML dùng chung của
`ApplicationWindow`; action điều hướng delegate vào command/window hiện có thay
vì lặp logic nghiệp vụ trong menu.

`InformationView.qml` đọc lịch sử backup qua các slot config-backup do `dbManager` ủy quyền; chọn commit chỉ đọc Git object, không checkout, không chạy lệnh thiết bị và không tạo backup mới.

Routing Group dùng popup bốn bước trong `qml/features/routing`; FHRP có workspace
riêng với các tab con HSRP/VRRP/GLBP trong `qml/features/fhrp`. Mỗi protocol page
giữ draft riêng. Cả hai dùng `MultiHostViewPushDialog.qml` để preview/push theo
từng host và tổng hợp lỗi partial mà không chặn host khác.
