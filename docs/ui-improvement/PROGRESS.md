# Progress log

## 2026-07-23

### Baseline

- [x] Kiểm kê dialog/popup/window hiện có.
- [x] Kiểm kê consumer của `StandardSpinBox`.
- [x] Xác nhận SFTP backend đã có local/remote history.
- [x] Xác nhận External Tools đã nhận diện WinSCP và chặn `{password}` trên
  command line.
- [x] Đối chiếu Qt Overlay/SpinBox, VS Code Explorer và WinSCP navigation.
- [x] UI-01 primitive dialog chuẩn; SFTP, System Logs, External Tools, About và
  View & Push đã dùng chung title/surface/lock contract.
- [x] UI-02 main window blur/dim; popup dùng `Overlay.modal`, child `Window`
  độc lập dùng scrim khi Main mất active.
- [x] QML smoke + UI contract baseline: 94 test pass sau lát cắt SFTP đầu tiên;
  test riêng xác nhận lỗi search/zoom xuất hiện một lần trong full run là flaky
  và pass khi chạy lại độc lập.

### UI-03 activation reload

- [x] Bấm FeatureBar, kể cả bấm lại feature đang active, yêu cầu reload view
  cache hiện tại.
- [x] Routing, DHCP, NAT, ACL và Switching reload subfeature đang active.
- [x] Interface refresh danh sách khi quay lại nhưng giữ form hiện tại.
- [x] Dirty/edit/save guard ngăn activation reload ghi đè staged changes.
- [x] NAT activation không còn gọi `clearForm()` trước khi reload.
- [x] 4 test ContentArea/Routing, 3 test DHCP, 4 test NAT và 5 test
  ACL/Interface/Switching pass.

### UI-04 independent presentation

- [x] Permit/Deny trong ACL dùng màu chữ và nền trạng thái xanh/đỏ; text vẫn là
  tín hiệu chính để không phụ thuộc riêng vào màu.
- [x] Icon ActivityBar chưa active mờ nhẹ; hover/active trở lại opacity đầy đủ.
- [x] Interface dùng asset Edit/Delete thay cho ký tự `...` và `X`.
- [x] Information diff có picker Original/Modified và badge additions/deletions
  theo cách trình bày quen thuộc của VS Code.

### UI-05 SpinBox by domain

- [x] Tái hiện lỗi click indicator bằng QML pointer test: giá trị `50` không
  tăng theo step `10`.
- [x] Hai indicator có hit target riêng, tăng/giảm đúng một lần và tự vô hiệu
  tại min/max.
- [x] Cả tám consumer khai báo rõ `from`, `to`, `value`, `stepSize`.
- [x] Dynamic ACL dùng phút và chuyển sang giây khi persistence; Reflexive ACL
  dùng giây, mặc định 300.
- [x] Backend guard timeout ACL và route-map sequence đồng bộ với UI/schema.
- [x] 5 regression test lõi, 6 QML load test và 5 Syslog setting test pass.

### UI-06 external SFTP and mouse navigation

- [x] ActivityBar mở SFTP Client đang active trong External Tools thay cho
  workspace tích hợp.
- [x] `{ip}`, `{port}`, `{username}`, `{path}` được thay theo profile đã chọn;
  nếu chưa chọn profile thì mở login/session UI của client ngoài.
- [x] Không cấu hình, launch lỗi, executable mất hoặc legacy `{password}` đều
  fallback về SFTP tích hợp.
- [x] Mouse Back/Forward dùng history của pane active kể cả khi input đang
  focus; keyboard shortcut vẫn được bảo vệ khi người dùng đang gõ.
- [x] 3 launcher unit test, 1 external QML contract test, 1 mouse pointer test
  và Main/SFTP load tests pass.

### UI-07 SFTP metadata, selection, context menu and shortcuts

- [x] Thêm cột Type; thư mục hiển thị `Folder`, loại tệp được suy ra từ phần
  mở rộng với fallback tổng quát.
- [x] Size thư mục và thuộc tính size không lấy được hiển thị `-`; tệp rỗng
  vẫn hiển thị chính xác `0 B`.
- [x] Click, Ctrl+click, Shift+click và Ctrl+A chọn nhiều theo kiểu Explorer;
  model reset hoặc chuyển thư mục xóa selection cũ.
- [x] Upload/Download/Delete nhận toàn bộ tập chọn; Rename chỉ bật khi đúng một
  mục được chọn.
- [x] Menu chuột phải giữ selection hiện có, có Open/Transfer, Rename, Delete,
  New folder, Select all và Refresh; hỗ trợ Shift+F10 và Escape.
- [x] 4 metadata/unit test, 1 QML contract test, 1 multi-selection pointer test,
  1 right-click pointer test và Main/SFTP load tests pass.

### UI-08 SFTP password opt-in

- [x] Mặc định không lưu mật khẩu; profile JSON chỉ có cờ `passwordSaved`, không
  chứa secret.
- [x] Checkbox lưu theo profile có nhãn “not recommended”; bỏ chọn sẽ xóa
  credential đã lưu.
- [x] Cài đặt tự lưu sau khi kết nối thành công mặc định tắt và có cảnh báo
  riêng trong SFTP Settings.
- [x] Mật khẩu được bảo vệ bằng Windows DPAPI theo current user, không dùng
  machine scope; hệ thống không có secure store sẽ vô hiệu hóa tùy chọn.
- [x] Quick connect dùng credential đã bảo vệ mà không đưa secret vào public
  profile map; password field được xóa sau khi kết nối thành công.
- [x] External SFTP launcher tiếp tục chặn `{password}` và không nhận secret
  qua command line.
- [x] 6 persistence/DPAPI unit test, 1 dialog pointer test và 3 password UI
  contract test pass.

### UI-09 collection context menus and shortcuts

- [x] Device tabs có Close, Close Others, Close to the Right, Close All, Reopen
  Closed và New Device; right-click chọn tab đích trước khi mở menu.
- [x] Giữ Ctrl+W/Ctrl+T/Ctrl+Shift+T/Ctrl+Tab hiện có; bổ sung Ctrl+F4,
  Ctrl+K Ctrl+W và Shift+F10 theo VS Code/Windows.
- [x] Interface saved rows dùng chung function Edit/Delete cho icon, context
  menu và F2/Delete; F5 reload, Shift+F10 mở menu của hàng chọn.
- [x] Collection shortcut bị chặn khi modal mở; Interface còn chặn khi người
  dùng đang nhập trong TextInput/TextEdit.
- [x] Không gắn menu vào ActivityBar/FeatureBar chỉ có hành vi điều hướng hoặc
  các bảng chưa có command contract chung.
- [x] 2 pointer test thực hiện action thật trên DeviceTabs và Interface; QML
  load và static command contract pass.

### UI-10 regression and QA

- [x] Toàn bộ 213 unit, contract và QML smoke/pointer test pass trong một lượt
  chạy offscreen (`python -m unittest discover -s tests`).
- [x] Python compileall pass cho `core`, `features`, `tests` và `main.py`.
- [x] `uv lock --check` pass với 57 package đã resolve.
- [x] `git diff --check` pass; chỉ còn cảnh báo chuyển LF sang CRLF theo cấu
  hình working tree trên Windows.
- [x] Các QML harness thực hiện thao tác chuột thật cho SpinBox, SFTP
  navigation/multi-selection/context menu/password, DeviceTabs và Interface.
- [x] Một số fixture cũ vẫn phát `ResourceWarning` về SQLite connection khi
  teardown; không có test failure và không thuộc phạm vi thay đổi UI này.

### Working tree safety

Trước khi bắt đầu chương trình đã có thay đổi chưa commit tại:

- `app/UI/qml/panels/DatabaseTableSection.qml`
- `app/tests/test_qml_smoke.py`

Các thay đổi này được xem là thay đổi của người dùng và phải được bảo toàn.
