# Responsive layout development plan

## Phạm vi và bằng chứng

Hạng mục này áp dụng cho toàn bộ cửa sổ làm việc, không chỉ System Logs.
Baseline hiện có:

- 192 tệp QML, 216 `RowLayout` và 181 `StandardButton`.
- System Logs có toolbar/card chiều cao cố định nhưng chứa nhiều control có
  preferred width lớn; khi workspace còn khoảng 480 px, child tràn khỏi card.
- `Layout.minimumWidth` không được khai báo ở nhiều input/button. Theo thuật
  toán Qt Quick Layouts, minimum mặc định có thể là 0, nên control bị ép về 0
  trước khi parent biết cách đổi bố cục.
- Sidebar có maximum tuyệt đối nhưng không dành một width budget tối thiểu cho
  workspace. Cửa sổ 900 px với sidebar 600 px chỉ còn khoảng 251 px sau
  ActivityBar và divider.
- ACL, Interface, DHCP và NAT còn dùng `SplitView` ngang cố định. Tổng minimum
  width của hai pane có trường hợp lớn hơn workspace, làm pane con bị đẩy ra
  ngoài.
- `FeatureDropdown.qml` dùng `modelData` trong bound delegate mà không khai báo
  required property, tạo `ReferenceError` lặp lại khi dropdown xuất hiện.

## Nguồn nghiên cứu

- [Qt Quick Responsive Layouts](https://doc.qt.io/qt-6/qtquicklayouts-responsive.html):
  khi không thể co vô hạn mà vẫn dùng được, layout cần đổi cột/hàng, ẩn bớt
  thành phần hoặc tổ chức lại theo breakpoint.
- [Qt Quick Layout attached properties](https://doc.qt.io/qt-6/qml-qtquick-layouts-layout.html):
  item trong layout co giữa minimum/preferred/maximum; nếu không đặt minimum,
  giá trị có thể là 0.
- [Qt Quick `Flow`](https://doc.qt.io/qt-6/qml-qtquick-flow.html): child tự wrap
  sang dòng mới khi vượt chiều rộng khả dụng.
- [Windows responsive breakpoints](https://learn.microsoft.com/en-us/windows/apps/design/layout/screen-sizes-and-breakpoints-for-responsive-design):
  breakpoint phải dựa trên width của cửa sổ/app, với nhóm Small dưới 640 px,
  Medium 641–1007 px và Large từ 1008 px.
- [Windows command bar](https://learn.microsoft.com/en-us/windows/apps/develop/ui/controls/command-bar):
  command ưu tiên phải luôn truy cập được; khi thiếu chỗ, label có thể compact
  hoặc command chuyển sang overflow thay vì bị cắt khỏi màn hình.

## Responsive contract

### 1. Width budget toàn cửa sổ

- Tăng minimum window từ 900×600 lên 1024×700.
- Workspace chính luôn được dành tối thiểu 640 px khi sidebar đang mở.
- Maximum sidebar trở thành giá trị động:
  `window width - ActivityBar - divider - minimum workspace`.
- Width sidebar đã lưu vẫn được giữ; khi cửa sổ rộng lại, sidebar được phục hồi
  tới width người dùng đã chọn.

### 2. Primitive

- Input/ComboBox/SpinBox/Password có minimum usable width chung, không co về 0.
- Button có icon và text tự compact về icon-only khi actual width nhỏ hơn nội
  dung đầy đủ; accessible name và tooltip vẫn giữ label.
- Button text-only giữ text và minimum hit target, không biến thành icon giả.
- `SplitFormPane` cuộn dọc khi chiều cao nội dung lớn hơn pane.
- Container lấy height từ `implicitHeight` của layout; không dùng fixed height
  cho nội dung có thể wrap.

### 3. Workspace

- System Logs:
  - Control và filter bar đổi từ một hàng cố định sang grid 4/2/1 cột.
  - Card tăng chiều cao theo content.
  - Bảng ẩn các cột phụ theo breakpoint; Host, severity và message được ưu tiên.
- Information:
  - Header action compact bằng primitive button.
  - Mode/version/diff picker đổi sang grid; ở compact width, picker xuống dòng.
  - Khối bên trong luôn nằm trong bounds của card mẹ.
- SFTP giữ layout responsive hiện có; Switching bổ sung column priority cho
  bảng monitoring để ẩn các cột phụ trước khi cột chính bị ép về 0.
- ACL, Interface, DHCP và NAT chuyển `SplitView` sang dọc dưới data-workspace
  breakpoint; form pane cuộn thay vì đẩy pane còn lại khỏi màn hình.
- Data table rộng phải chọn một trong hai contract rõ ràng: ẩn cột phụ hoặc có
  horizontal scrolling đồng bộ header/body. Không cho cột thiết yếu co về 0.

### 4. Containment

- `clip` chỉ là lớp bảo vệ cuối, không phải cách che một layout sai.
- Text dài dùng elide/wrap theo ngữ cảnh.
- Popup/menu được neo trong window/overlay và không làm tăng implicit width của
  workspace.

## Kế hoạch triển khai

| Pha | Nội dung | Trạng thái |
|---|---|---|
| R-01 | Baseline ảnh/log, inventory và research | Done |
| R-02 | Token breakpoint, minimum window và sidebar width budget | Done |
| R-03 | Button/input/SplitFormPane primitive | Done |
| R-04 | System Logs và Information responsive | Done |
| R-05 | ACL/Interface/DHCP/NAT adaptive SplitView | Done |
| R-06 | FeatureDropdown bound delegate fix | Done |
| R-07 | Breakpoint runtime tests và full regression | Done |

## Ma trận kiểm thử

Các kích thước bắt buộc:

| Window/workspace | Mục đích |
|---|---|
| 1024×700, sidebar mở rộng tối đa | Workspace vẫn đạt 640 px |
| Workspace 640 px | Compact medium: grid xuống dòng, không width 0 |
| Workspace 520 px trong harness | Stress test: content còn truy cập bằng wrap/scroll |
| 1440×1024 | Không làm xấu hoặc compact nhầm layout desktop |

Assertion chính:

- Không input/box trọng yếu nào có width nhỏ hơn minimum usable width.
- Button icon+text compact đúng và có tooltip/accessibility label.
- Card height không nhỏ hơn content implicit height cộng padding.
- SplitView hẹp dùng orientation dọc.
- Không còn `FeatureDropdown modelData is not defined`.
- Main module load, QML breakpoint tests và full unit/contract regression pass.

## Kết quả nghiệm thu

- Runtime harness xác nhận sidebar rộng tự co để dành workspace 640 px ở cửa
  sổ 1024 px và phục hồi width đã lưu khi cửa sổ rộng lại.
- Runtime harness 520 px xác nhận System Logs tự tăng card height, input giữ
  minimum 120 px, button icon+text compact về icon-only và child quan trọng
  vẫn nằm trong bounds của parent.
- Information grid, form scroll và các SplitView đại diện của
  ACL/Interface/DHCP/NAT đã được kiểm tra ở compact width.
- `FeatureDropdown` load bằng bound delegate không còn phát sinh
  `modelData is not defined`.
- Full regression offscreen: 227/227 test pass.
- Python `compileall`, `uv lock --check` (57 package) và
  `git diff --check` pass. Cảnh báo LF/CRLF chỉ phản ánh line-ending của
  working tree Windows.
