# Kế hoạch và kết quả chuẩn hóa bảng UI

Ngày kiểm chứng: **2026-07-17**. Phạm vi implementation là QML trong `app/UI/`;
không thay đổi backend hay schema. Mục tiêu không phải sửa riêng màn hình VLAN mà
loại bỏ nguyên nhân khiến các giao diện có cùng ngữ nghĩa bảng lại dùng kích
thước, header, row, empty state và inspector khác nhau.

## 1. Kết quả đối chiếu

Ba ảnh tham chiếu cho thấy ba mức trưởng thành khác nhau:

- Batch New Device có cột và editor tương đối rõ, nhưng dùng `Rectangle`/`Text`
  riêng và kích thước không theo token chung.
- ACL dùng `SavedListPanel`, nhưng `Loader` của header không giữ chiều cao nên
  header có thể chồng lên row đầu tiên. Đây là lỗi layout của component dùng
  chung, không phải dữ liệu ACL.
- Switching tự dựng từng bảng. VLAN không có header cột, inspector vẫn hiện form
  disabled khi chưa chọn row và một SubBar chỉ có `VLAN` chiếm thêm một tầng
  điều hướng không tạo ra lựa chọn.

Nếu chỉ sửa từng ảnh, lỗi sẽ tái xuất hiện ở ACL/NAT/DHCP/Logs/SFTP hoặc feature
Switch mới. Vì vậy implementation được thực hiện ở hai lớp: primitive chung và
consumer.

## 2. Họ component bắt buộc

| Component | Trách nhiệm |
|---|---|
| `DataTableFrame` | Surface, border, radius và clipping của vùng dữ liệu. |
| `DataTable` | Header cố định, body, empty state và quyền hiển thị content theo `count`. |
| `DataTableHeader` | Header cao 36 px, nền/border chung và inset cột ổn định. |
| `DataTableRow` | Row cao 40 px, zebra, hover, selection và divider. |
| `DataTableCell` | Typography, elide, primary/secondary/header và monospace. |
| `EmptyState` | Title + description dùng chung khi không có dữ liệu/chưa chọn row. |
| `WorkspaceHeader` | Title/subtitle và nhóm action của data workspace. |
| `FormSection` | Card section trong inspector; không còn bản riêng dưới Switch. |

Các kích thước được export qua `Theme.tableHeaderHeight`,
`Theme.tableRowHeight` và `Theme.dataWorkspaceBreakpoint`; consumer không hard-code
lại. `SavedListHeader`/`SavedListRow` kế thừa trực tiếp primitive bảng nên các
list entity cũ tự nhận cùng typography, zebra và divider.

Selection của table không dùng `sideBarItemSelected`: nền Sidebar phụ thuộc Accent
và quá đậm khi phủ một row rộng như Saved ACL. Table dùng nền trung tính riêng cho
light/dark/high-contrast, giữ text primary/secondary bình thường và chỉ dùng vạch
Accent 2 px ở cạnh trái. Hover và zebra cũng có token riêng, nên selection vẫn rõ
mà không làm ba nút View/Edit/Delete và nội dung Binding khó đọc.

## 3. Switching đã thiết kế lại

| Màn hình | Thiết kế thống nhất |
|---|---|
| Switch Ports / Routed Ports | Workspace header + bảng cột cố định + inspector theo selection. |
| Port Security / Storm Control | Dùng lại bảng port, nhưng inspector chỉ hiện section đúng ngữ cảnh; không lặp một form tổng hợp gây rối. |
| VLAN | Bảng `VLAN / Name / Usage / State`; inspector rỗng cho tới khi chọn hoặc Add. |
| SVI | Bảng `Interface / VLAN Name / IP Address / Status`; IP Routing là action cấp workspace. |
| Port Counters / MAC Table | Hai view dùng cùng table shell và đổi schema header theo ngữ cảnh. |

VLAN/SVI/Ports dùng `SplitView` ngang khi đủ rộng và chuyển dọc dưới 920 px. Split
handle có hit area 5 px nhưng đường nhìn 1 px, hỗ trợ hover và cả hai orientation.
Pane chi tiết không còn hiển thị hàng loạt field disabled khi không có selection;
empty state giải thích bước tiếp theo.

`SwitchWorkspace` chỉ hiển thị `SubBar` khi feature hiện tại có ít nhất hai lựa
chọn. Vì Switching hiện chỉ có VLAN, thanh này được giữ trong model điều hướng
nhưng có chiều cao 0 và không hiển thị; khi bổ sung lựa chọn thứ hai, nó tự xuất
hiện mà không cần viết lại page.

## 4. Phạm vi đồng bộ ngoài Switch

| Nhóm | Cách áp dụng |
|---|---|
| ACL Saved/Pending Rules | Sửa chiều cao `Loader`, ẩn body lúc rỗng, căn lại cell/action và row spacing. |
| DHCP Pool/Excluded/Helper | Header và row dùng cùng `RowLayout`/`DataTableCell`; bỏ phép tính `parent.width` và margin bù action. |
| NAT Interface/Static/Dynamic/PAT/ACL/Route Map | Cột co giãn theo cùng schema; badge/action giữ đúng cột và row spacing bằng 0. |
| Interface và Routing saved lists | Kế thừa token row; Routing table dùng cell chung. |
| OSPF/EIGRP Networks | Chuyển frame/header/row/empty state sang primitive chung. |
| Batch New Device | Chuyển frame/header/editable row sang primitive chung, giữ workflow import/sample. |
| Device Logs | Packet list dùng `DataTable`; selection, protocol badge và inspector contract được giữ. |
| SFTP | File header/row/empty state dùng primitive chung, giữ toolbar và transfer action. |
| Database Browser | Dynamic column header/row dùng table frame chung; editor cell và cuộn hai chiều được giữ. |

Không ép các card, tree navigation, notification history hoặc list một cột thành
table. Primitive này chỉ dùng khi dữ liệu có schema cột và yêu cầu căn thẳng hàng.

## 5. Quy tắc UX/performance

- Header nằm ngoài `ListView`, vì vậy không cuộn mất và không được overlay body.
- Dataset theo row dùng `ListView`; không tạo toàn bộ row bằng `Repeater`.
- Empty state thay thế nội dung khi `count === 0`; không để form disabled hoặc
  header giả nằm giữa vùng trống.
- Selection dùng một row duy nhất và chỉ inspector tương ứng đọc dữ liệu; đổi
  context Security không tạo một bộ form khác.
- Column width của header và row phải lấy cùng một biểu thức. Action compact có
  cột riêng, không bù bằng margin không rõ nguồn gốc.
- Không dùng `sideBarItemSelected` cho table selection. Nền selection phải trung
  tính và chỉ vạch chỉ báo mảnh được lấy Accent của người dùng.
- Text dài phải elide; địa chỉ/MAC/counter có thể dùng monospace. Trạng thái không
  chỉ phụ thuộc màu mà phải còn label/badge.
- Component mới phải có QML smoke không warning và contract test khóa inheritance,
  token, SubBar rule và consumer trực tiếp.

## 6. Việc chưa thuộc lát cắt này

- Paging/sort/row count và redaction cho Database Browser vẫn là backlog riêng.
- Routing table collected lớn vẫn cần query paging/virtualization ở repository;
  đổi skin bảng không giải quyết việc copy toàn bộ dataset.
- Visual regression đa DPI/theme và keyboard traversal toàn bộ cell editor vẫn
  cần môi trường kiểm thử ảnh chuyên biệt.
- Switching hiện là desired-state local; thiết kế lại UI không thay đổi mức hỗ
  trợ push thiết bị.
