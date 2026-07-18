# Kiểm kê và tổ chức SVG

Cập nhật ngày **2026-07-18**. Phạm vi: `app/UI/resources/` và mọi consumer QML/Python liên quan.

## 1. Kết quả rà soát

- Trước khi sắp xếp có **101 SVG** trong 8 nhóm theo vị trí UI. QML chứa 63 literal path, trong đó `sftp_icons/arrow-back.svg` không tồn tại.
- Có **39 SVG không có consumer**. Bốn SVG đang được gọi nhưng trùng chức năng/bản vẽ với asset khác (`featurebar/info`, SFTP `pencil`, `refresh-cw`, `trash-2`) cũng không cần giữ trong runtime. Ngược lại, `general/arrow-left.svg` trước đó chưa có consumer được dùng để sửa nút Back của SFTP.
- Sau lượt sắp xếp ban đầu có **59 SVG active** và **42 SVG chờ duyệt** trong `_unused/`. Sau khi nhập bộ loại file Material Icon Theme, trạng thái hiện tại là **109 SVG active**, **48 SVG chờ duyệt**, tổng cộng **157 SVG**. Không xóa SVG nào trong các lượt này.
- QML không còn literal path SVG ngoài `AppAssets.qml`. Các đường dẫn vòng kiểu `../UI/resources/sftp_icons/...` đã bị loại bỏ.
- SFTP dùng asset chung cho Edit, Delete, Refresh, Back; file/folder mặc định và 54 icon loại file dùng Material Icon Theme. Chi tiết mapping nằm trong [SFTP_FILE_TYPE_ICONS.md](SFTP_FILE_TYPE_ICONS.md).

Nguồn/giấy phép đã được giữ tại:

- `app/UI/resources/licenses/LUCIDE.txt` — Lucide Icons, MIT;
- `app/UI/resources/licenses/VSCODE-ICONS.txt` — vscode-icons, MIT; hiện chỉ còn áp dụng cho bản cũ trong `_unused/`;
- `app/UI/resources/licenses/MATERIAL-ICON-THEME.txt` — Material Icon Theme, MIT.

## 2. Cấu trúc chuẩn

```text
app/UI/resources/
├── actions/       # thao tác người dùng: save, delete, refresh, upload...
├── brand/         # logo SVG/PNG/ICO của ứng dụng
├── devices/       # router, switch và trạng thái kết nối mạng
├── files/         # file/folder, hướng transfer và loại file
│   └── types/
├── navigation/    # destination và điều hướng: dashboard, chevron, terminal...
├── status/        # severity, notification, DND và runtime status
├── licenses/      # attribution của bộ icon bên thứ ba
└── _unused/       # không được runtime tham chiếu; chờ người duyệt/xóa
    ├── legacy/
    └── sftp/
```

Thư mục không còn được dùng: `activitybar/`, `devicetabs/`, `featurebar/`, `general/`, `icons/`, `sftp_icons/`, `sidebar/`, `statusbar/`. Cách chia cũ buộc cùng một biểu tượng phải được sao chép theo từng màn hình; cấu trúc mới chia theo ý nghĩa.

## 3. Nơi quản lý đường dẫn tập trung

File chuẩn là `app/UI/qml/shared/AppAssets.qml`. Mỗi SVG active có đúng một property mang tên ngữ nghĩa:

```qml
icon.source: AppAssets.actionSave
iconSource: AppAssets.deviceRouter
```

Không viết `AppAssets.resource("resources/...svg")` tại consumer. Khi đổi tên hoặc di chuyển SVG, chỉ sửa path của property trong `AppAssets.qml`; consumer không đổi. `AppAssets.fileTypeIcon(fileName)` quản lý luật theo tên/extension và 54 đường dẫn icon loại file của SFTP; unknown type dùng `fileGeneric`.

`navigationInformation` là alias của `statusInfo`, vì hai vị trí dùng cùng một hình Info. Đây là chia sẻ có chủ đích, không phải bản sao file.

Logo cửa sổ dùng ICO từ Python nên `app/main.py` trỏ trực tiếp tới `resources/brand/logo.ico`; SVG logo của Welcome Screen vẫn đi qua `AppAssets.brandLogo`.

Contract trong `app/tests/test_ui_contracts.py` khóa các quy tắc sau:

1. 109 path active là duy nhất và đều tồn tại;
2. mọi SVG ngoài `_unused/` phải có mapping trong `AppAssets.qml`;
3. QML consumer không được chứa literal SVG path hoặc gọi `AppAssets.resource()`;
4. `_unused/` tách biệt khỏi runtime.

## 4. Inventory SVG active

### `actions/` — 22 file

| Property | File | Chức năng/consumer chính |
|---|---|---|
| `actionAdd` | `actions/add.svg` | Mở thao tác thêm thiết bị ở Sidebar Header. |
| `actionBackup` | `actions/backup.svg` | Lấy/backup running-config ở Information và Device Context Menu. |
| `actionClear` | `actions/clear.svg` | Xóa toàn bộ Notification History. |
| `actionClose` | `actions/close.svg` | Đóng hoặc gỡ item UI; dùng bởi component Close/Remove chuẩn. Không dùng cho Cancel/rollback. |
| `actionConnect` | `actions/connect.svg` | Kết nối SFTP. |
| `actionCopy` | `actions/copy.svg` | Copy cấu hình hoặc lịch sử thông báo. |
| `actionDatabaseReload` | `actions/database-reload.svg` | Reload dữ liệu từ database/backend trong các form DHCP, NAT, ACL, Routing, Switching. |
| `actionDelete` | `actions/delete.svg` | Xóa device/SFTP entry và clear từng nhóm log/transfer hoàn tất. |
| `actionDisconnect` | `actions/disconnect.svg` | Ngắt kết nối SFTP. |
| `actionDownload` | `actions/download.svg` | Download file từ remote SFTP. |
| `actionEdit` | `actions/edit.svg` | Edit device hoặc rename SFTP entry. |
| `actionFilter` | `actions/filter.svg` | Bật/tắt lọc Sidebar. |
| `actionListAdd` | `actions/list-add.svg` | Mở luồng thêm danh sách/YANG ở Sidebar Header. |
| `actionMonitorStart` | `actions/monitor-start.svg` | Bắt đầu theo dõi device. |
| `actionMonitorStop` | `actions/monitor-stop.svg` | Dừng theo dõi device. |
| `actionPush` | `actions/push.svg` | View & Push/Push cấu hình tới thiết bị. |
| `actionRefresh` | `actions/refresh.svg` | Refresh Sidebar, DB table, External Tools và SFTP panel. |
| `actionSave` | `actions/save.svg` | Save cấu hình/form đã stage. |
| `actionSearch` | `actions/search.svg` | Tìm kiếm device trong Sidebar. |
| `actionUpload` | `actions/upload.svg` | Upload file local qua SFTP. |
| `actionVisibilityOff` | `actions/visibility-off.svg` | Action che password khi password đang hiển thị. |
| `actionVisibilityOn` | `actions/visibility-on.svg` | Action hiện password khi password đang bị che. |

### `brand/` — 1 SVG active

| Property | File | Chức năng/consumer chính |
|---|---|---|
| `brandLogo` | `brand/logo.svg` | Logo vector ở Welcome Screen. `logo.ico` dùng cho cửa sổ; `logo.png` là raster companion. |

### `devices/` — 6 file

| Property | File | Chức năng/consumer chính |
|---|---|---|
| `deviceNetworkDisconnected` | `devices/network-disconnected.svg` | Máy không có kết nối mạng ở Status Bar. |
| `deviceNetworkEthernet` | `devices/network-ethernet.svg` | Kết nối Ethernet ở Status Bar. |
| `deviceNetworkWifi` | `devices/network-wifi.svg` | Kết nối Wi-Fi ở Status Bar. |
| `deviceRouter` | `devices/router.svg` | Kiểu thiết bị Router trong tab/list. |
| `deviceStatusDot` | `devices/status-dot.svg` | Chấm trạng thái kết nối của device item. |
| `deviceSwitch` | `devices/switch.svg` | Kiểu thiết bị Switch trong tab/list. |

### `files/` — 58 file

| Property | File | Chức năng/consumer chính |
|---|---|---|
| `fileGeneric` | `files/file.svg` | File SFTP không có loại chuyên biệt. |
| `fileFolder` | `files/folder.svg` | Directory trong SFTP browser. |
| `fileTransferDownload` | `files/transfer-download.svg` | Hướng download trong transfer queue. |
| `fileTransferUpload` | `files/transfer-upload.svg` | Hướng upload trong transfer queue. |

54 property `fileType*` còn lại ánh xạ một-một tới 54 SVG trong `files/types/`.
Xem inventory đầy đủ, association và provenance tại
[SFTP_FILE_TYPE_ICONS.md](SFTP_FILE_TYPE_ICONS.md).

### `navigation/` — 14 file

| Property | File | Chức năng/consumer chính |
|---|---|---|
| `navigationBack` | `navigation/arrow-left.svg` | Đi lên/quay lại thư mục cha trong SFTP; thay path `arrow-back.svg` bị thiếu. |
| `navigationChevronDown` | `navigation/chevron-down.svg` | Mở/collapse xuống, dropdown, spinner và ẩn Notification Center. |
| `navigationChevronRight` | `navigation/chevron-right.svg` | Mở nhánh Sidebar hoặc Feature Bar. |
| `navigationChevronUp` | `navigation/chevron-up.svg` | Spinner tăng và điều hướng kết quả trước. |
| `navigationConsoleSerial` | `navigation/console-serial.svg` | Destination Console Serial (hiện reserved/disabled). |
| `navigationDashboard` | `navigation/dashboard.svg` | Destination Dashboard/Devices. |
| `navigationDatabase` | `navigation/database.svg` | Destination Database Browser. |
| `navigationDatabaseSearch` | `navigation/database-search.svg` | Nhận diện tool Database/DB catalog. |
| `navigationInterface` | `navigation/interface.svg` | Feature Interface của device. |
| `navigationLogs` | `navigation/logs.svg` | Nhận diện tool Logs trong catalog. |
| `navigationSettings` | `navigation/settings.svg` | Destination Settings. |
| `navigationSftp` | `navigation/sftp.svg` | Destination/loại tool SFTP. |
| `navigationTerminal` | `navigation/terminal.svg` | CLI/terminal feature và external tool terminal. |
| `navigationTopology` | `navigation/topology.svg` | Destination Topology (hiện placeholder). |

### `status/` — 8 file

| Property | File | Chức năng/consumer chính |
|---|---|---|
| `statusDoNotDisturb` | `status/do-not-disturb.svg` | Action/state DND của Notification Center và Status Bar. |
| `statusError` | `status/error.svg` | Severity Error. |
| `statusInfo` | `status/info.svg` | Severity Info; đồng thời là hình cho destination Information qua alias. |
| `statusNotification` | `status/notification.svg` | Notification bình thường hoặc action tắt DND. |
| `statusNotificationUnread` | `status/notification-unread.svg` | Có notification chưa đọc. |
| `statusPython` | `status/python.svg` | Trạng thái Python/dev mode ở Status Bar. |
| `statusSuccess` | `status/success.svg` | Severity Success và feedback Copied. |
| `statusWarning` | `status/warning.svg` | Severity Warning. |

## 5. SVG trong `_unused/` để duyệt xóa

Runtime và `AppAssets.qml` không tham chiếu các file dưới đây. Có thể xóa toàn bộ `_unused/` sau khi xác nhận không cần cho feature tương lai.

### Legacy — 16 file

| File | Ý nghĩa dự kiến | Lý do cách ly |
|---|---|---|
| `legacy/activitybar/devices.svg` | Destination Devices. | Không có consumer; Dashboard đang đại diện luồng hiện tại. |
| `legacy/activitybar/logs-alerts.svg` | Logs có cảnh báo. | Không có destination/action tương ứng. |
| `legacy/devicetabs/close.svg` | Đóng tab. | Trùng chức năng `actions/close.svg`. |
| `legacy/general/arrow-right.svg` | Forward/next. | Chưa có consumer; được giữ vì là asset mới chưa tracked trước lượt này. |
| `legacy/general/chevron-left.svg` | Previous/collapse trái. | Chưa có consumer. |
| `legacy/general/database-push.svg` | Push dữ liệu database. | Không đúng action Push thiết bị hiện tại; dùng `actions/push.svg`. |
| `legacy/general/info-duplicate.svg` | Information. | Cùng vector với `status/info.svg`. |
| `legacy/icons/database.svg` | Logo database cỡ lớn. | Không có consumer; navigation dùng `navigation/database.svg`. |
| `legacy/statusbar/bell-slash.svg` | Notification muted. | DND dùng `status/do-not-disturb.svg`. |
| `legacy/statusbar/ready.svg` | Trạng thái Ready. | Chưa có state/consumer; success dùng `status/success.svg`. |
| `legacy/files/lucide-file.svg` | Generic file Lucide cũ. | Đã thay bằng hình file mặc định của Material Icon Theme. |
| `legacy/files/lucide-folder.svg` | Folder Lucide cũ. | Đã thay bằng hình folder mặc định của Material Icon Theme. |
| `legacy/files/vscode-icons/cpp.svg` | C/C++ cũ. | Đã thay bằng bộ Material Icon Theme tách riêng C, C++, header. |
| `legacy/files/vscode-icons/markdown.svg` | Markdown cũ. | Đã thay bằng Material Icon Theme. |
| `legacy/files/vscode-icons/python.svg` | Python cũ. | Đã thay bằng Material Icon Theme. |
| `legacy/files/vscode-icons/text.svg` | Text cũ. | Đã thay bằng `files/types/document.svg` của Material Icon Theme. |

### SFTP — 32 file

| File | Ý nghĩa dự kiến | Lý do cách ly |
|---|---|---|
| `archive.svg` | Nén/giải nén archive. | SFTP chưa hỗ trợ archive. |
| `arrow-up-down.svg` | Sort/sync/hai chiều. | Chưa có sort/sync action. |
| `chevron-left.svg` | Back. | Không có consumer; Back dùng `navigation/arrow-left.svg`. |
| `chevron-up.svg` | Parent/collapse. | Trùng vector `navigation/chevron-up.svg`. |
| `circle-dot.svg` | Status marker. | Không có state tương ứng; device đã có status dot chuẩn. |
| `clipboard-paste.svg` | Paste. | SFTP chưa hỗ trợ paste. |
| `clipboard.svg` | Clipboard chung. | Không có consumer. |
| `copy.svg` | Copy entry/path. | SFTP chưa hỗ trợ copy; app có `actions/copy.svg`. |
| `eye-off.svg` | Ẩn nội dung. | Trùng chức năng `actions/visibility-off.svg`. |
| `file-plus.svg` | Tạo file. | SFTP chưa có create-file action. |
| `file-text.svg` | Text file chung. | Đã có `files/file.svg` và mapping loại file cụ thể. |
| `folder-open.svg` | Folder đang mở. | UI không có state icon folder mở. |
| `folder-plus.svg` | Tạo folder. | New Folder chủ ý text-only theo UX contract. |
| `grid-3x3.svg` | Grid view. | SFTP chỉ có list/table view. |
| `house.svg` | Home directory. | Chưa có Home action. |
| `info.svg` | Information. | Cùng vector `status/info.svg`. |
| `list.svg` | List view. | Không có layout toggle. |
| `loader-circle.svg` | Loading spinner vòng. | App dùng `LoadingSpinner` chung. |
| `loader.svg` | Loading spinner tia. | App dùng `LoadingSpinner` chung. |
| `move-3d.svg` | Move theo nhiều trục. | Không phù hợp file manager hiện tại. |
| `move.svg` | Move entry. | SFTP chưa hỗ trợ move. |
| `pause.svg` | Pause transfer. | Backend/queue chưa hỗ trợ pause. |
| `pencil.svg` | Rename/edit. | Cùng vector `actions/edit.svg`. |
| `plug-zap.svg` | Kết nối nhanh/đang hoạt động. | Connect state dùng `actions/connect.svg`. |
| `refresh-cw.svg` | Refresh. | Trùng chức năng `actions/refresh.svg`. |
| `scissors.svg` | Cut. | SFTP chưa hỗ trợ cut/paste. |
| `search.svg` | Search. | Cùng vector `actions/search.svg`; SFTP chưa có search UI. |
| `settings.svg` | Settings. | Cùng vector `navigation/settings.svg`; SFTP chưa có settings riêng. |
| `trash-2.svg` | Delete. | Biến thể cùng nghĩa `actions/delete.svg`; chỉ giữ một icon Delete. |
| `wifi-off.svg` | Mất kết nối. | SFTP state dùng disabled/connection status; app có network status chuẩn. |
| `wifi.svg` | Có kết nối. | Không phải tín hiệu SFTP; app có network status chuẩn. |
| `x.svg` | Close. | Cùng vector `actions/close.svg`. |

## 6. Quy trình thêm hoặc đổi SVG

1. Xác định ý nghĩa và đặt file vào đúng nhóm; không tạo thư mục theo tên màn hình.
2. Tìm icon cùng nghĩa trước khi thêm file mới.
3. Thêm đúng một property vào `AppAssets.qml`; đặt tên theo ý nghĩa, không theo widget cụ thể.
4. Consumer chỉ dùng `AppAssets.<property>`.
5. Nếu thay thế icon cũ, chuyển bản cũ vào `_unused/` để duyệt hoặc xóa khi đã được phê duyệt.
6. Cập nhật inventory này và chạy `tests.test_ui_contracts` cùng `tests.test_qml_smoke`.
