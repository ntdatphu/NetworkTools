# Giao diện và QML Components (UI Components)

Dự án NetworkTools sử dụng kiến trúc giao diện theo **Họ giao diện (Interface Families)**, nhằm mục đích đảm bảo tính nhất quán (consistency), giảm thiểu sự lặp lại code (DRY), và dễ dàng mở rộng khi có tính năng mạng mới.

## 1. Họ Giao Diện (Interface Families)

Tất cả các tính năng hiển thị ở phần nội dung chính (Content Area) đều phải tuân thủ một trong các họ giao diện dưới đây.

| Ký hiệu | Tên Họ Giao Diện | Mục đích sử dụng | Pattern chính |
|---|---|---|---|
| **F1** | Observe/Info Dashboard | Xem thông tin (read-only), trạng thái mạng. | `info_routing.qml` (Hiển thị dữ liệu tĩnh, chia theo block). |
| **F2** | Entity Workspace | Nhập liệu cấu hình có dạng Form và xem dạng Danh sách. Dùng cho DHCP, NAT, Interface. | `SplitFormPane` (bên trái) + `SavedListPanel` (bên phải). |
| **F3** | Policy/Rule Workspace | Cấu hình các rule có thứ tự (Order). Dùng cho ACL, Route Map. | Bảng rule có các cột tuần tự, kèm bộ nhập liệu Rule ở trên (`AclRuleRow`). |
| **F4** | Process Workspace | Cấu hình các tiến trình lớn (OSPF, EIGRP, BGP). | Sử dụng `ProcessCard` kèm theo pinned header và các section tab. |
| **F5** | Guided Setup | Form định hướng người dùng. Dùng thêm thiết bị. | Step-by-step form (`NewDevice.qml`). |
| **F6** | Operations/Inspector | Các công cụ hệ thống như CLI, DB Browser. | View độc lập, có search, filter. |
| **F7** | Settings Catalog | Cài đặt hệ thống, Theme, External Tools. | Danh mục dọc bên trái, nội dung bên phải. |

## 2. Hệ Thống Components Chuẩn (Standard Components)

Các components này nằm tại thư mục `app/UI/components/` và phải được ưu tiên sử dụng thay vì tự viết các thẻ thuần như `Rectangle` hay `Button`.

### Standard Controls (`components/standard/`)
- `StandardButton`: Các nút bấm theo theme (Primary, Secondary, Danger, Ghost).
- `StandardTextField`: Ô nhập liệu chuẩn. Phải luôn sử dụng kết hợp với `validator` (ví dụ: `RegExpValidator`) để bắt lỗi ngay từ Front-end. Đối với trường mật khẩu, cần cung cấp chức năng ẩn/hiện mật khẩu bằng icon mắt (điều khiển thuộc tính `echoMode`).
- `StandardNetworkField`: TextField tuỳ chỉnh chuyên dụng cho địa chỉ IP, mask (bắt buộc phải có validation chặn nhập sai dạng octet).
- `StandardComboBox` / `StandardDropdown`: Danh sách thả xuống.
- `StandardCheckBox` / `StandardToggleButton`: Các nút trạng thái Bật/Tắt.

### Layout Components (`components/layout/`)
- `SplitFormPane`: Panel nhập liệu nằm trong SplitView. Dùng ở F2.
- `SavedListPanel` & `SavedListRow`: Danh sách bảng hiển thị bên phải, có chức năng edit/delete.
- `FormLayout`: Gói gọn các TextField lại theo grid hoặc column.
- `SubBar`: Thanh menu phụ để chuyển qua lại giữa các module nhỏ trong một feature (vd: DHCP Pool / Excluded / Helper).

### Base Components (`components/base/`)
- `ProcessCard`: Component khung dạng Card chuyên trị cho các giao thức kiểu Process như OSPF (Họ F4).
- `CustomAlert`: Dialog thông báo có tuỳ chọn xác nhận.
- `ThemedIcon`: Gói Icon bằng SVG cho phép dễ dàng đổi màu (Light/Dark mode).

## 3. Quản lý Theme & Design Tokens

Thay vì gán hardcode (vd: `color: "#ffffff"`, `height: 32`), toàn bộ giao diện phải tham chiếu đến thư mục `app/UI/theme/`.

Bằng cách gọi `import UI`, các files QML có thể gọi thẳng:
- **Kích thước**: `Theme.spacing8`, `Theme.spacing16`, `Theme.radiusMedium`, `Theme.itemHeight`.
- **Chữ viết**: `Theme.fontSizeNormal`, `Theme.fontSizeLarge`.
- **Trạng thái chọn (Selection)**: Sử dụng `selectionColor: Theme.selectionBackground` để đồng nhất màu khi bôi đen văn bản, tuyệt đối không hardcode màu xanh đậm.
- **Assets (Hình ảnh)**: Gọi qua `AppAssets.resource("resources/general/icon.svg")`.
