# Sidebar, SFTP toolbar, and system accent follow-up

## Trạng thái

UI-21 — Done.

## Nguồn đối chiếu

- [VS Code User Interface — Views](https://code.visualstudio.com/docs/editing/userinterface#_views):
  các view trong Explorer có thể được kéo để đổi thứ tự; Open Editors phản ánh
  danh sách tab/editor đang mở. NetworkTools giữ lifecycle đó nhưng đặt Open
  Editors ở đáy PanelSideBar theo yêu cầu sản phẩm.
- [VS Code `openEditorsView.ts`](https://github.com/microsoft/vscode/blob/main/src/vs/workbench/contrib/files/browser/views/openEditorsView.ts):
  active editor được reveal, lifecycle open/close/active là nguồn cập nhật và
  mặc định tối đa 9 editor được nhìn thấy trước khi cuộn.
- [Qt `SystemPalette`](https://doc.qt.io/qt-6/qml-qtquick-systempalette.html):
  cung cấp palette hiện hành của ứng dụng trên nền tảng đang chạy.
- [Qt `QPalette::Accent`](https://doc.qt.io/qt-6/qpalette.html#ColorRole-enum):
  Accent đại diện lựa chọn cá nhân hóa của desktop và fallback về Highlight
  nếu hệ thống/style không cung cấp vai trò riêng.

## Contract triển khai

### PanelSideBar

- Open Editors tiếp tục dùng duy nhất `DeviceTabs.openEditorsSnapshot`, nhưng
  nằm sau vùng danh sách thiết bị và được ghim ở đáy PanelSideBar.
- Khi chiều cao cửa sổ nhỏ, Open Editors giữ header và giới hạn phần danh sách
  để không làm vùng device/search bị ép về 0.
- Chuột phải trên header của các group Connected, Waiting hoặc Disconnected mở
  menu không-modal gồm `Collapse All` và `Expand All`.
- Database dùng cùng menu cho mọi table group. Bulk action cập nhật state
  `expandedGroups` duy nhất nên vẫn đúng sau khi người dùng toggle từng group.
- Hai lệnh tác động lên cùng các property `expanded` mà thao tác click header
  đang dùng; không tạo state collapse thứ hai.
- Menu dùng SVG semantic `list-collapse.svg` và `list-expand.svg`, không bật
  `UiState.windowLock` nên không làm mờ workspace.

### SFTP toolbar

- Ở chiều rộng đủ lớn, `New folder`, `Rename`, `Delete`, `Upload`/`Download`
  phải hiển thị đầy đủ, không elide thành dấu ba chấm.
- Kích thước expanded được đo độc lập với Text đang bị layout.
- Khi thật sự thiếu chỗ, Flow được phép xuống dòng; button icon + text có thể
  compact thành icon-only theo contract responsive hiện có.

### Accent Color và StatusBar

- Bổ sung lựa chọn `Use system accent color`, lưu bền vững và loại trừ lẫn nhau
  với preset/custom accent.
- Màu hệ thống đọc động từ `SystemPalette.accent`; toàn bộ shade/status bar được
  dẫn xuất qua cùng pipeline accent hiện có để Windows và Linux không cần nhánh
  code theo hệ điều hành.
- `Virtual Lab · Starting...` dùng token warning riêng cho StatusBar. Token ưu
  tiên sắc vàng nhạt nhưng fallback sang foreground đen/trắng có contrast cao
  khi accent/status bar hiện tại không đạt ngưỡng 4.5:1.

## Tiêu chí nghiệm thu

- Runtime test xác nhận Open Editors đứng dưới vùng device và các action
  Collapse/Expand All đổi đồng thời ba device group lẫn toàn bộ Database group.
- Runtime test xác nhận toolbar SFTP rộng không compact, label có đủ bề rộng;
  test responsive hiện có vẫn xác nhận icon-only khi hẹp.
- Persistence test xác nhận system accent được lưu/khôi phục; QML test xác nhận
  system accent đi qua `currentAccent`.
- Contrast test xác nhận màu Starting đạt tối thiểu 4.5:1 trên toàn bộ preset
  status bar và một tập custom accent sáng/tối đại diện.
- Main module load, UI contracts và full regression không có warning/failure
  mới.

## Kết quả nghiệm thu

- 11 targeted test pass: persistence, static contracts, system accent/contrast,
  SFTP toolbar và pointer flow của Device/Database group context menu.
- Toàn bộ QML smoke + UI contract suite pass 135/135 trong full regression.
- Full regression offscreen pass 238/238.
- Python `compileall` pass; `uv lock --check` pass với 57 package.
- `git diff --check` pass; chỉ còn cảnh báo line-ending LF/CRLF của working tree
  Windows.
