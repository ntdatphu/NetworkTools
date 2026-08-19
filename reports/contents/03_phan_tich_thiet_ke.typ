#pagebreak(weak: true)
= Phân tích và thiết kế hệ thống

== Tác nhân và ca sử dụng

Hệ thống được thiết kế tối ưu cho môi trường phòng thực hành (lab), với tác nhân (Actor) duy nhất tham gia tương tác trực tiếp là *Người quản trị* (bao gồm giảng viên quản lý lab hoặc sinh viên thực hành). Các ca sử dụng (Use Cases) cốt lõi được mô hình hóa nhằm đáp ứng toàn bộ vòng đời quản trị cấu hình:

/ [UC-01] Quản lý Inventory: Khai báo, chỉnh sửa, xóa thông tin định danh và tham số kết nối của thiết bị (Router, Switch).
/ [UC-02] Đồng bộ trạng thái (Sync): Kết nối SSH, bóc tách cấu hình đang chạy (running-config) và cập nhật trạng thái cơ sở (Baseline) vào SQLite.
/ [UC-03] Định nghĩa cấu hình: Sử dụng giao diện (Form) để thiết lập thông số mạng (Interface, OSPF, VLAN, ACL, v.v.). Dữ liệu lưu ở trạng thái chờ (Pending).
/ [UC-04] Xem trước (Preview): Kết xuất dữ liệu chờ thành tập lệnh CLI qua engine Jinja2 để người quản trị kiểm duyệt.
/ [UC-05] Thực thi (Push): Đẩy tập lệnh cấu hình xuống thiết bị, thu thập phản hồi và xác minh tính thành công.
/ [UC-06] Quản lý Terminal: Mở phiên dòng lệnh nhúng (Alacritty) để thao tác thủ công, tự động đồng bộ khi đóng phiên.
/ [UC-07] Quản lý phiên bản: Xem lịch sử thay đổi cấu hình được lưu trữ dưới dạng các bản commit thông qua Dulwich.


== Yêu cầu chức năng

Dựa trên các ca sử dụng, yêu cầu chức năng (Functional Requirements - FR) được phân rã thành các hạng mục cụ thể. Nhóm yêu cầu được chia thành hai mức độ để định hướng ưu tiên phát triển.

=== Nhóm tính năng bắt buộc
Đây là các tính năng cốt lõi phải hoàn thiện để hệ thống có thể vận hành luồng công việc cơ bản:
- *[FR-01] Quản lý thiết bị:* Hệ thống cho phép thêm, sửa, xóa thiết bị và lưu trữ an toàn thông tin xác thực.
- *[FR-02] Kiểm tra kết nối:* Cung cấp tính năng Ping và kiểm tra cổng SSH (Test Connection) trước khi cấp quyền truy cập.
- *[FR-03] Thu thập cấu hình:* Worker nền tự động kết nối, chạy lệnh `show run`, parse dữ liệu và lưu vào database.
- *[FR-04] Cấu hình Lớp 3:* Hỗ trợ giao diện thiết lập Interface IP, định tuyến tĩnh, OSPF, EIGRP và DHCP server.
- *[FR-05] Cấu hình Lớp 2:* Hỗ trợ thiết lập VLAN, Trunking và EtherChannel trên các thiết bị Switch (vIOS-L2).
- *[FR-06] Chính sách mạng:* Hỗ trợ thiết lập danh sách kiểm soát truy cập (ACL) và biên dịch địa chỉ (NAT/PAT).
- *[FR-07] View & Push:* Hệ thống phải sinh ra mã CLI chính xác từ dữ liệu Pending và cho phép đẩy lệnh an toàn.

=== Nhóm tính năng mở rộng
- *[FR-08] Terminal nhúng:* Tích hợp cửa sổ CLI nội bộ, bắt sự kiện (hook) khi phiên kết thúc để trigger luồng Sync.
- *[FR-09] Quản lý Backup:* Ứng dụng Dulwich để theo dõi sự thay đổi của cấu hình thiết bị qua các phiên bản (Git-based).


== Yêu cầu phi chức năng

Bên cạnh các nghiệp vụ mạng, kiến trúc hệ thống phải đáp ứng các tiêu chuẩn khắt khe về hiệu năng, an toàn và tính khả dụng (Non-Functional Requirements - NFR):

- *[NFR-01] Hiệu năng giao diện:* Luồng giao diện chính (UI Thread) phải hoàn toàn tách biệt với luồng mạng. Việc thực thi SSH kéo dài không được làm treo/đơ giao diện QML.
- *[NFR-02] An toàn thực thi:* Hệ thống phải hỗ trợ Chế độ phát triển (Dev-mode). Khi bật Dev-mode, hệ thống cấm tuyệt đối việc khởi tạo session thật xuống thiết bị vật lý.
- *[NFR-03] Toàn vẹn dữ liệu:* Sử dụng ràng buộc khóa ngoại (Foreign Keys) và Validation ở tầng Backend để ngăn chặn việc nhập sai định dạng IP/Subnet hoặc các tham chiếu không tồn tại.
- *[NFR-04] Quản lý đồng thời:* Áp dụng cơ chế khóa theo host (Host Lock). Không cho phép hai Worker cùng đẩy cấu hình xuống một thiết bị tại cùng một thời điểm để tránh xung đột (Race Condition).
- *[NFR-05] Bảo mật Secret:* Mật khẩu thiết bị không được ghi dạng plain-text vào các file log vận hành. Việc mã hóa khóa bí mật chuyên dụng (Secret Vault) được xem là định hướng mở rộng tương lai.

== Kiến trúc phân lớp

Kiến trúc runtime được tổ chức theo bốn lớp chính:

```text
QML/Qt Quick UI
       │ signal/slot và context property
       ▼
PyQt6 bridge: DatabaseManager, TerminalHelper, settings, monitor
       │
       ├── SQLite: cấu hình mong muốn, thiết bị, trạng thái đồng bộ
       ├── backend/: chuẩn hóa và lưu dữ liệu nghiệp vụ
       └── network_code/: thu thập, render Jinja2, preview và push
                                │
                                ▼
                     Thiết bị Cisco IOS hoặc dev-mode
```

`DatabaseManager` đóng vai trò facade được đưa vào QML. Entry point của runtime desktop là `app/main.py`, không phải kiến trúc web client/server.

== Luồng dữ liệu cốt lõi

=== Quản lý và đồng bộ thiết bị

Thêm thiết bị → mở tab → ping/kết nối → lưu running-config → parse interface/OSPF → cập nhật SQLite.

=== Lưu cấu hình mong muốn

Form QML → validation → slot → backend persistence → `success=0` hoặc `success=-1` → hiển thị trạng thái pending.

=== View & Push

Controller thu thập bản ghi pending → Jinja2 render → preview → worker dùng session → nhận kết quả → cập nhật hoặc xóa bản ghi thành công.

== Thiết kế dữ liệu

Các nhóm bảng chính:

- `t01_*`: thiết bị và cấu hình YANG.
- `t02_*`: interface router.
- `t03_*`: DHCP.
- `t04_*`: static route, OSPF, EIGRP.
- `t05_*`: ACL, NAT, route-map.
- `t06_*`, `t07_*`: schema dự phòng cho L2/VRF, chưa phải chức năng hoàn chỉnh.

Trạng thái `success` được dùng theo quy ước: `0` là pending add/update, `1` là đã áp dụng, `-1` là pending remove hoặc soft delete. `action_Cfg` cần được giải thích tại những nơi worker vẫn còn sử dụng trường này.

== Thiết kế giao diện

Phần giao diện cần mô tả application shell, device sidebar, feature bar, lazy Loader, các nhóm form/list, process card và View & Push dialog.

== Thiết kế an toàn và xử lý lỗi

Thiết kế hiện tại nhấn mạnh dev-mode fail-closed, timeout, validation, không log password, session registry và tác vụ nền. Mã hóa secret và rollback được ghi nhận là yêu cầu tương lai nếu chưa có triển khai và test tương ứng.
