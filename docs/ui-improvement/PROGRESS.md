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

### UI-11/12/13 follow-up

- [x] Baseline working tree sạch tại thời điểm bắt đầu follow-up.
- [x] Đối chiếu VS Code `SidebarPart`: minimum width 170 px, `snap = true`.
- [x] Đối chiếu VS Code `SplitView`: ngưỡng snap hai chiều bằng nửa minimum
  size; width nhìn thấy được giữ tại minimum trước khi chuyển sang hidden.
- [x] Xác định layout hiện tại chỉ collapse sau mouse-release và cho sidebar
  co liên tục từ 150 px xuống 0 px.
- [x] Xác định SFTP file context menu tự bật `UiState.windowLock`, trong khi
  Device context menu là non-modal và không bật main-window blur.
- [x] Xác định Subnet/Wildcard cùng chuẩn hóa shorthand trong
  `StandardNetworkField.onEditingFinished`; cần regression test focus/caret
  trên primitive dùng chung.
- [x] UI-11 dùng persistent grab area và state width duy nhất; pointer test xác
  nhận collapse dưới 85 px và restore ở 85 px với visible width 170 px.
- [x] UI-12 bỏ `UiState.windowLock` khỏi SFTP file context menu; outside-click
  catcher và action lifecycle được giữ nguyên, regression test xác nhận menu
  mở mà main window không bị lock/blur.
- [x] UI-13 chuẩn hóa shorthand ngay lần mất focus đầu tiên và chỉ hiển thị một
  caret tại field đang active.
- [x] Reproducer focus mô phỏng late `cursorVisible=true`; inactive-field guard
  xóa caret trễ mà không ảnh hưởng caret của field active.
- [x] 3 targeted QML pointer/focus tests và toàn bộ 66 UI contract tests pass
  (69 test trong lượt targeted).
- [x] Full regression chạy lại sạch: 216/216 test pass offscreen. Lượt đầu gặp
  đúng flaky zoom `ConfigTextViewer` đã biết; test đó pass khi chạy riêng trước
  lượt full sạch.
- [x] Python `compileall` pass cho `core`, `features`, `infrastructure`,
  `tests` và `main.py`; `uv lock --check` pass với 57 package.
- [x] `git diff --check` pass; chỉ có cảnh báo LF/CRLF của working tree Windows.

### UI-14/15/16 follow-up

- [x] Tái hiện Settings PanelSideBar ở minimum width 170 px: card bị khóa
  `72 px` trong khi mô tả cần ba dòng, khiến text tràn sang card kế tiếp.
- [x] Card Settings dùng chiều cao động theo `implicitHeight` của title và
  description; QML layout test xác nhận cả bốn card chứa đủ nội dung ở 170 px.
- [x] Xác định `Ctrl+Shift+N` được đăng ký đồng thời bởi SFTP và DevicesPanel
  đang ẩn, tạo ambiguous shortcut ở Main.
- [x] `Ctrl+N` và `Ctrl+Shift+N` của Devices chỉ enabled khi DevicesPanel đang
  visible; regression harness giữ panel ẩn cùng SFTP để kiểm tra xung đột thật.
- [x] `Ctrl+R` của SFTP được chuyển về `CommandRegistry`; `F5` tiếp tục là
  shortcut cục bộ của pane.
- [x] Thêm bảng Keyboard Shortcuts theo nhóm General, Devices, Device tabs,
  SFTP và Interfaces; `Ctrl+/` mở được cả khi input đang focus, nhưng không mở
  chồng lên modal khác.
- [x] 4 QML keyboard/layout test và 2 static contract test pass.
- [x] Full regression chạy sạch: 220/220 test pass offscreen. Bài zoom
  `ConfigTextViewer` flaky xuất hiện trong một lượt UI suite, pass khi chạy
  riêng và trong lượt full regression.
- [x] Python `compileall` cho tests, `uv lock --check` với 57 package và
  `git diff --check` đều pass; chỉ có cảnh báo LF/CRLF của working tree Windows.

### UI-17/18 System Logs header and Open Editors

- [x] Chuẩn hóa System Logs PanelSideBar thành collection header `HOSTS`, khác
  tên feature `System Logs` trên ActivityBar.
- [x] Connected-host count dùng accent badge; Refresh Connected Hosts chuyển
  từ full-width footer button thành icon-only Header action có tooltip và busy
  guard.
- [x] Đối chiếu VS Code Explorer/Open Editors và source
  `openEditorsView.ts`: danh sách theo editor lifecycle, chọn/reveal editor
  active và mặc định hiện tối đa 9 editor trước khi cuộn.
- [x] `DeviceTabs.openEditorsSnapshot` là nguồn duy nhất cho Open Editors;
  chọn/close/close all gọi lại API tab hiện có để giữ session cleanup, history
  và active fallback.
- [x] Open Editors chỉ hiện khi có Device tab, có collapse, accent active row,
  icon loại thiết bị, màu trạng thái và scroll sau 9 hàng.
- [x] Runtime pointer test xác nhận 3-tab snapshot, chọn/reveal active editor,
  đóng một editor và đóng tất cả; static contract khóa wiring và Header System
  Logs.
- [x] Full regression chạy sạch: 222/222 test pass offscreen.
- [x] Python `compileall`, `uv lock --check` với 57 package và
  `git diff --check` đều pass; chỉ có cảnh báo LF/CRLF của working tree Windows.

### UI-20 actionable Toast Notification

- [x] Đối chiếu VS Code notification guideline, `notificationsToasts.ts`,
  `notificationsViewer.ts` và notification model.
- [x] Chốt contract stack tối đa ba toast, timeout 10/12/15 giây, hover/focus
  pause, sticky error action/progress và suppress toast khi Center mở.
- [x] Bổ sung primary action, source, accessibility metadata và action router
  dùng chung cho Toast/Notification Center.
- [x] Bổ sung dismiss từng history entry; action đóng toast/history sau khi
  thực thi như primary action của VS Code.
- [x] Nối `settingsKey: external_tools` từ backend tới CLI, SFTP và Database
  Browser; nút `Open External Tools` mở đúng ActivityBar/sidebar/content.
- [x] Runtime action/stack/Center tests, backend metadata tests và static
  contracts đều pass.
- [x] Full regression offscreen chạy sạch: 231/231 test pass.
- [x] Python `compileall`, `uv lock --check` với 57 package và
  `git diff --check` đều pass; chỉ có cảnh báo LF/CRLF của working tree Windows.

### UI-19 responsive layout

- [x] Phân tích ảnh System Logs: workspace hẹp hơn tổng preferred width của
  control bar, filter bar và table columns; child bị đẩy khỏi card.
- [x] Đọc runtime log và xác định `FeatureDropdown` thiếu required
  `modelData` trong bound delegate.
- [x] Inventory: 192 QML, 216 RowLayout, 181 StandardButton; nhóm SplitView cũ
  ở ACL/Interface/DHCP/NAT chưa đổi orientation theo breakpoint.
- [x] Đối chiếu Qt Quick Responsive Layouts, Layout minimum/preferred/maximum,
  Flow và Windows responsive breakpoint/command-bar guidance.
- [x] Chốt contract minimum window, workspace width budget, button compact,
  input minimum, adaptive SplitView và table column priority.
- [x] Triển khai primitive và workspace theo
  `RESPONSIVE_LAYOUT_PLAN.md`.
- [x] Tăng minimum window lên 1024×700; sidebar dùng maximum động để luôn dành
  tối thiểu 640 px cho workspace và phục hồi width đã lưu khi có đủ chỗ.
- [x] Standard input giữ minimum 120 px; button icon+text tự compact icon-only;
  button text-only vẫn giữ text; `SplitFormPane` có vertical scroll.
- [x] System Logs control/filter chuyển sang grid 4/2/1, card lấy dynamic
  implicit height và log table ẩn cột phụ theo breakpoint.
- [x] Information chuyển version/diff picker sang grid; ACL, Interface, DHCP,
  NAT chuyển SplitView dọc ở compact width; Switching monitoring áp dụng
  column priority.
- [x] `FeatureDropdown` khai báo bound delegate `modelData`, không còn
  `ReferenceError` lặp lại.
- [x] Breakpoint runtime tests xác nhận width budget 1024/640, stress width
  520, card containment, minimum input, button compact, form scrolling và
  adaptive SplitView.
- [x] Full regression offscreen chạy sạch: 227/227 test pass.
- [x] Python `compileall`, `uv lock --check` với 57 package và
  `git diff --check` đều pass; chỉ có cảnh báo LF/CRLF của working tree Windows.

### UI-21 Sidebar/SFTP/theme follow-up

- [x] Đối chiếu VS Code Explorer/Open Editors và khả năng reorder view; giữ
  lifecycle hiện có nhưng áp dụng vị trí đáy PanelSideBar theo yêu cầu sản phẩm.
- [x] Đối chiếu Qt `SystemPalette` và `QPalette::Accent`; chốt một pipeline
  accent động đa nền tảng, fallback về Highlight do Qt quản lý.
- [x] Xác định nguyên nhân toolbar SFTP có thể elide ở trạng thái rộng: phép đo
  expanded đang phụ thuộc Text đồng thời bị RowLayout co giãn.
- [x] Chốt contract context menu group không-modal, dùng chung state `expanded`
  và hai SVG `list-collapse.svg`/`list-expand.svg` mới.
- [x] Open Editors nằm sau vùng device và được ghim ở đáy; chiều cao danh sách
  tối đa 45% PanelSideBar để không làm vùng tìm kiếm/device bị ép về 0.
- [x] Chuột phải trên Connected/Waiting/Disconnected mở menu không-modal;
  Collapse/Expand All dùng chung ba property `expanded` và hai SVG semantic mới.
- [x] Database Table groups dùng cùng menu; state ownership được đưa hoàn toàn
  về `expandedGroups` để toggle riêng không làm đứt binding của bulk action.
- [x] StandardButton đo expanded label bằng `TextMetrics`; tám button toolbar
  SFTP ở hai pane hiển thị đầy đủ khi rộng và contract compact cũ vẫn hoạt động.
- [x] Accent `System` đọc động từ `SystemPalette.accent`, được lưu/khôi phục và
  loại trừ lẫn nhau với custom/preset.
- [x] Virtual Lab Starting dùng warning foreground riêng; contrast test đạt
  tối thiểu 4.5:1 trên 12 preset và các custom accent sáng/tối đại diện.
- [x] 11 targeted test và toàn bộ QML smoke/UI contract suite 135/135 pass.
- [x] Full regression offscreen chạy sạch: 238/238 test pass.
- [x] Python `compileall`, `uv lock --check` với 57 package và
  `git diff --check` đều pass; chỉ có cảnh báo LF/CRLF của working tree Windows.
