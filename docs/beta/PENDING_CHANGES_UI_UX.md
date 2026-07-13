# Thay đổi Chờ xử lý (Pending Changes) - UI/UX & Hiệu năng

Tài liệu này lưu trữ kế hoạch cập nhật (To-Do List) chi tiết cho việc tối ưu hoá UI/UX, Cải thiện hiệu suất và thẩm mỹ của dự án NetworkTools theo kết quả phân tích hệ thống mới nhất. **Các thay đổi này là ưu tiên và cần được code hoàn thiện trong giai đoạn tới.**

## 1. Yêu cầu Chung (General & Core)
- **Tích hợp Phím tắt toàn cục:** Bổ sung `Ctrl+R` (Reload), `Ctrl+S` (Save), Phím tắt cho `Activity Bar` (Ctrl+1, Ctrl+2...), `View & Push` (Ctrl+Shift+P) trên toàn dự án (`Main.qml` hoặc `ContentArea.qml`).
- **Notification (Toast/Alert):** Bổ sung chức năng nhấn để `Copy` nội dung thông báo cho *từng thông báo*. Icon SVG trong `app/UI/resources/general`
- **Validation Form:** Rà soát lại tất cả các ô nhập liệu `StandardNetworkField`, `StandardTextField` trên ứng dụng. Bổ sung `RegExpValidator` chặt chẽ cho (IP, Wildcard, Subnet Mask,...). Tránh việc nhập sai định dạng truyền xuống DB gây treo (Crash) script Backend.
- **Trường Mật khẩu (Password):** Thêm icon Mắt (Eye icon - SVG) để bật/tắt (Toggle `echoMode`) xem mật khẩu. Hiện tại đang ẩn mặc định.
- **Đồng bộ màu sắc (Selection Color):** Màu bôi đen hiện tại (có thể đang hardcode màu xanh đậm) không nhất quán. Cần đưa về một chuẩn chung của Theme (`Theme.selectionBackground` hoặc tuỳ biến của `Theme.accentColor` phù hợp).
- **Cơ chế Reload Chủ động (Feature Click Reload):** Tại `ContentArea.qml` hoặc `ActivityBar`, khi click chuyển sang một tab (Ví dụ DHCP, Routing, ACL), hệ thống phải tự động truy xuất lại DB (`reloadPools`, `reloadAll`...) để đảm bảo người dùng luôn nhìn thấy dữ liệu mới nhất (đã được đồng bộ qua thao tác ngầm). 

## 2. Activity Bar
- **Bổ sung chức năng "Console Serial":** Thêm một Feature (Icon mới) lên Activity Bar trên khu vực nhóm ActivityBarItem (như Dashboard, Topology)
- **Di chuyển chức năng của "Database" (đổi tên từ Open Database):** Di chuyển và đổi tên "Open DB" thành "Database" xuống khu vực bên trên nút "Settings"

## 3. Khung hiển thị Thông tin (Information View)
Giao diện `InformationView.qml` (và các view hiển thị text tĩnh như `info_routing.qml`) cần được nâng cấp toàn diện để đạt thẩm mỹ cao:
- **Tương tác:** Cho phép zoom in/out bằng cách nhấn giữ `Ctrl + Lăn chuột`. Hỗ trợ Tìm kiếm (Search) nội dung nhanh (`Ctrl+F`).
- **Line Marking:** Trỏ chuột vào lề trái có khả năng chọn cả dòng, đánh dấu dòng (highlight). Thêm số dòng (Line numbers) để dễ đối chiếu lỗi.
- **Công cụ (Toolbar):** Bổ sung nút Copy nhanh toàn bộ thông tin (Button Copy Information).
- **Tự động tải lại:** Tương tự General, mỗi lần mở tab Information phải là mỗi lần reload từ `running-config` hoặc DB tĩnh.
- **Tô màu Cú pháp (Syntax Highlighting):** Xử lý làm nổi bật (Tô màu) các thành phần quan trọng trong bản cấu hình mạng, bao gồm:
  - `IP Address`
  - `Subnet Mask`, `Wildcard`
  - Từ khóa giao diện: sau chữ `interface` (VD: *GigabitEthernet0/1*)
  - Các số nguyên đứng đơn lẻ (0, 1, 10, 20...)
  - Các từ khoá boolean: `yes`, `no`
  - Cấu trúc thời gian: Giờ, ngày, tháng.
  - Policy: `permit`, `deny`
  - Zone/NAT: `inside`, `outside`

## 4. Giao thức DHCP
- **View DHCP Info Mới:** Dựa vào cơ sở dữ liệu `app/info_collected.db` (bảng `t09_info_dhcp_pool`, `t09_info_dhcp_binding`), xây dựng một giao diện bảng biểu Dashboard phụ để hiển thị tình trạng cấp phát DHCP thực tế lấy về từ thiết bị.

## 5. Open DB (Trình Duyệt Database)
- **Tái thiết kế Giao diện PanelSideBar:** Chỉnh sửa UI của Sidebar chọn bảng trong Database (trước kia là Open DB) sao cho giống (có sự tương đồng lớn) với các `DeviceItem` trên màn hình Dashboard chính (Devices).
- **Gom nhóm Bảng (Table Grouping):** Hiện tại list danh sách bảng bị lộn xộn. Cần tổ chức nhóm thành các Tree/Dropdown tương tự trạng thái Connect/Waiting trên Devices (Dashboard). Quy tắc: Dựa vào mã số đầu theo cấu trúc `t[mã số]` của tên bảng, nhóm chung sẽ thành `Group Table [mã số] - [tên chức năng chung của nhóm bảng]` (Ví dụ: `t01_devices`, `t01_yangcfg` -> `Table 01 - General`; `t02_interface_name`, `t02_router_iface_l3` -> `Table 02 - Interface`;... Chức năng này đòi hỏi viết parser xử lý tên bảng trên Python Backend.

## 6. Cài đặt (Settings) -> External Tools
- **Auto-Detect:** Viết script Python tự động nhận diện các công cụ SSH (Putty, SecureCRT) và Text Editor đang cài mặc định trên Windows.
- **UI UX External Tools:** Sửa lại form nhập liệu (đường dẫn, đối số) để quá trình Add / Edit công cụ ngoài mượt mà và trực quan hơn. Thay vì bắt người dùng điền thủ công, có thể thêm nút "Browse" và tự động điền Argument mẫu.
