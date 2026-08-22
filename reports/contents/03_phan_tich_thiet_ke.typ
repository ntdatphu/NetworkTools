#pagebreak(weak: true)
#import "../config/tables.typ": report-table
#import "../config/commands.typ": report-note
= Phân tích và thiết kế hệ thống

== Tác nhân và ca sử dụng

Hệ thống được thiết kế tối ưu cho môi trường phòng thực hành (lab), với tác nhân (Actor) duy nhất tham gia tương tác trực tiếp là *Người quản trị* (bao gồm giảng viên quản lý lab hoặc sinh viên thực hành). Các ca sử dụng (Use Cases) cốt lõi được mô hình hóa nhằm đáp ứng toàn bộ vòng đời quản trị cấu hình:

/ Quản lý Inventory: Khai báo, chỉnh sửa, xóa thông tin định danh và tham số kết nối của thiết bị (Router, Switch).
/ Đồng bộ trạng thái (Sync): Kết nối SSH, bóc tách cấu hình đang chạy (running-config) và cập nhật trạng thái cơ sở (Baseline) vào SQLite.
/ Định nghĩa cấu hình: Sử dụng giao diện (Form) để thiết lập thông số mạng (Interface, OSPF, VLAN, ACL, v.v.). Dữ liệu lưu ở trạng thái chờ (Pending).
/ Xem trước (Preview): Kết xuất dữ liệu chờ thành tập lệnh CLI qua engine Jinja2 để người quản trị kiểm duyệt.
/ Thực thi (Push): Đẩy tập lệnh cấu hình xuống thiết bị, thu thập phản hồi và xác minh tính thành công.
/ Quản lý Terminal: Mở phiên dòng lệnh nhúng (Alacritty) để thao tác thủ công, tự động đồng bộ khi đóng phiên.
/ Quản lý phiên bản: Xem lịch sử thay đổi cấu hình được lưu trữ dưới dạng các bản commit thông qua Dulwich.


== Yêu cầu chức năng

Dựa trên các ca sử dụng, yêu cầu chức năng (Functional Requirements) được phân rã thành các hạng mục cụ thể. Nhóm yêu cầu được chia thành hai mức độ để định hướng ưu tiên phát triển.

=== Nhóm tính năng bắt buộc
Đây là các tính năng cốt lõi phải hoàn thiện để hệ thống có thể vận hành luồng công việc cơ bản:
- *Quản lý thiết bị:* Hệ thống cho phép thêm, sửa, xóa thiết bị và lưu trữ an toàn thông tin xác thực.
- *Kiểm tra kết nối:* Cung cấp tính năng Ping và kiểm tra cổng SSH (Test Connection) trước khi cấp quyền truy cập.
- *Thu thập cấu hình:* Worker nền tự động kết nối, chạy lệnh `show run`, parse dữ liệu và lưu vào database.
- *Cấu hình Lớp 3:* Hỗ trợ giao diện thiết lập Interface IP, định tuyến tĩnh, OSPF, EIGRP và DHCP server.
- *Cấu hình Lớp 2:* Hỗ trợ thiết lập VLAN, Trunking và EtherChannel trên các thiết bị Switch (vIOS-L2).
- *Chính sách mạng:* Hỗ trợ thiết lập danh sách kiểm soát truy cập (ACL) và biên dịch địa chỉ (NAT/PAT).
- *View & Push:* Hệ thống phải sinh ra mã CLI chính xác từ dữ liệu Pending và cho phép đẩy lệnh an toàn.

=== Nhóm tính năng mở rộng
- *Terminal nhúng:* Tích hợp cửa sổ CLI nội bộ, bắt sự kiện (hook) khi phiên kết thúc để trigger luồng Sync.
- *Quản lý Backup:* Ứng dụng Dulwich để theo dõi sự thay đổi của cấu hình thiết bị qua các phiên bản (Git-based).


== Yêu cầu phi chức năng

Bên cạnh các nghiệp vụ mạng, kiến trúc hệ thống phải đáp ứng các tiêu chuẩn khắt khe về hiệu năng, an toàn và tính khả dụng (Non-Functional Requirements):

- *Hiệu năng giao diện:* Luồng giao diện chính (UI Thread) phải hoàn toàn tách biệt với luồng mạng. Việc thực thi SSH kéo dài không được làm treo/đơ giao diện QML.
- *An toàn thực thi:* Hệ thống phải hỗ trợ Chế độ phát triển (Dev-mode). Khi bật Dev-mode, hệ thống cấm tuyệt đối việc khởi tạo session thật xuống thiết bị vật lý.
- *Toàn vẹn dữ liệu:* Sử dụng ràng buộc khóa ngoại (Foreign Keys) và Validation ở tầng Backend để ngăn chặn việc nhập sai định dạng IP/Subnet hoặc các tham chiếu không tồn tại.
- *Quản lý đồng thời:* Áp dụng cơ chế khóa theo host (Host Lock). Không cho phép hai Worker cùng đẩy cấu hình xuống một thiết bị tại cùng một thời điểm để tránh xung đột (Race Condition).
- *Bảo mật Secret:* Mật khẩu thiết bị không được ghi dạng plain-text vào các file log vận hành. Việc mã hóa khóa bí mật chuyên dụng (Secret Vault) được xem là định hướng mở rộng tương lai.
== Kiến trúc phân lớp



Kiến trúc phần mềm được tổ chức theo bốn lớp chính, đảm bảo sự tách biệt rõ ràng giữa giao diện, logic điều phối, lưu trữ và tương tác mạng:

/ 1. Lớp Giao diện (QML / Qt Quick UI): Chịu trách nhiệm tiếp nhận tương tác của người dùng. Tầng này giao tiếp với các tầng bên dưới thông qua cơ chế truyền nhận tín hiệu (Signal/Slot) và thuộc tính ngữ cảnh (Context Property).

/ 2. Lớp Cầu nối (PyQt6 Bridge): Đóng vai trò lớp đại diện (Facade) kết nối giao diện với hệ thống xử lý bên dưới. Các thành phần chính bao gồm `DatabaseManager`, `TerminalHelper`, `settings` và `monitor`.

/ 3. Lớp Dữ liệu và Nghiệp vụ (Backend & SQLite): Đảm nhiệm việc chuẩn hóa và lưu trữ dữ liệu. Cơ sở dữ liệu SQLite được dùng để quản lý danh sách thiết bị, cấu hình mong muốn và trạng thái đồng bộ thực tế.

/ 4. Lớp Mạng và Thực thi (Network Code): Xử lý giao tiếp trực tiếp với thiết bị mạng. Bao gồm các tiến trình nền thực hiện kết nối (qua SSH hoặc Telnet), thu thập trạng thái, sinh mã lệnh từ mẫu Jinja2, hỗ trợ người dùng xem trước và đẩy lệnh cấu hình xuống thiết bị Cisco IOS hoặc môi trường thử nghiệm (dev-mode).

`DatabaseManager` đóng vai trò là đối tượng trung tâm được nạp vào QML. Điểm khởi chạy của toàn bộ ứng dụng desktop là tệp `app/main.py`, hệ thống hoạt động độc lập tại máy cục bộ thay vì hoạt động theo mô hình máy khách - máy chủ (client-server) của ứng dụng web.



== Luồng dữ liệu cốt lõi

=== Quản lý và đồng bộ thiết bị
Quy trình quản lý và đồng bộ dữ liệu thiết bị từ lúc khởi tạo đến khi cập nhật trạng thái cơ sở (baseline) diễn ra theo trình tự sau:
+ *Khởi tạo và kết nối:* Người dùng thêm thiết bị mới vào hệ thống và mở phiên làm việc (tab). Hệ thống tiến hành kiểm tra kết nối mạng (Ping) và xác thực giao thức truy cập từ xa (SSH/Telnet).
+ *Thu thập cấu hình:* Sau khi kết nối thành công, tiến trình nền sẽ tiến hành sao lưu cấu hình đang chạy (running-config) của thiết bị.
+ *Trích xuất và lưu trữ:* Dữ liệu thô được bóc tách (parse) để lấy các thông tin trọng tâm như cấu hình giao diện (Interface) và định tuyến (OSPF), v.v.. Sau đó hệ thống cập nhật kết quả vào cơ sở dữ liệu SQLite.

=== Lưu cấu hình mong muốn
Quá trình ghi nhận cấu hình do người quản trị thiết lập (desired state) được thực hiện một cách an toàn và chưa tác động ngay đến thiết bị thật:
+ *Tiếp nhận và kiểm tra:* Dữ liệu đầu vào từ biểu mẫu giao diện (Form QML) được kiểm tra tính hợp lệ (validation) để loại bỏ các lỗi cú pháp và logic.
+ *Truyền tải và lưu trữ:* Dữ liệu hợp lệ được đẩy qua cơ chế truyền nhận tín hiệu (slot) xuống tầng lưu trữ nội bộ (backend persistence).
+ *Đánh dấu trạng thái:* Bản ghi được lưu vào cơ sở dữ liệu với cờ đánh dấu trạng thái chờ: `success = 0` đối với thao tác thêm/cập nhật, hoặc `success = -1` đối với thao tác chờ xóa. Giao diện sau đó phản hồi lại trạng thái chờ xử lý (pending) cho người dùng theo dõi.

=== Xem trước và thực thi (View & Push)
Đây là luồng tác vụ quan trọng nhất để chuyển đổi cấu hình mong muốn thành cấu hình thực tế trên thiết bị:
+ *Thu thập và sinh mã lệnh:* Bộ điều khiển (Controller) quét cơ sở dữ liệu để lấy các bản ghi đang ở trạng thái chờ (pending). Dữ liệu này được đưa qua bộ tạo mẫu (Jinja2) để kết xuất thành các tập lệnh CLI chuẩn xác.
+ *Xem trước (Preview):* Hệ thống hiển thị tập lệnh để người quản trị kiểm duyệt trực quan trước khi đưa ra quyết định áp dụng.
+ *Thực thi (Push) và cập nhật:* Nếu được phê duyệt, tiến trình thực thi (worker) sẽ tái sử dụng phiên kết nối hiện tại để đẩy lệnh xuống thiết bị. Dựa trên kết quả phản hồi, hệ thống sẽ chuyển trạng thái bản ghi sang thành công (đã áp dụng) hoặc xóa bản ghi tương ứng khỏi hệ thống nếu là tác vụ gỡ bỏ cấu hình.

Đoạn mã
== Thiết kế dữ liệu

Hệ thống cơ sở dữ liệu SQLite được phân hoạch thành hai nhóm chính: Nhóm dữ liệu cấu hình (Desired State) và Nhóm dữ liệu thu thập (Current State). Việc phân tách này giúp tối ưu hóa hiệu suất truy vấn và cách ly hoàn toàn luồng thao tác đọc/ghi.

*Nhóm 1: Dữ liệu cấu hình và trạng thái đồng bộ (t01 - t07)*

Nhóm này lưu trữ các tham số mạng do người dùng thiết lập, đóng vai trò là cấu hình mong muốn đang chờ được thực thi.

#[
  #set par(justify: false)
  #report-table(
    columns: (18%, 37%, 45%),
    cell-align: (center + horizon, left + horizon, left + horizon),
    header: ([Tiền tố bảng], [Phân hệ nghiệp vụ], [Mục đích lưu trữ chính]),
    rows: (
      ([`t01_*`], [Inventory], [Định danh thiết bị, xác thực, SSH, trạng thái kết nối.]),
      ([`t02_*`], [Interface], [Thông số IPv4, Subinterface, Tunnel.]),
      ([`t03_*`], [Dịch vụ IP], [Cấu hình DHCP Pool, Helper Address.]),
      ([`t04_*`], [Định tuyến], [Static Route, OSPF, EIGRP.]),
      ([`t05_*`], [ACL & NAT], [ACL (Std/Ext/Dynamic/Reflexive), NAT/PAT.]),
      ([`t06_*`], [Switching & L2 Security], [VLAN, Trunking, EtherChannel, STP, DHCP Snooping, DAI.]),
      ([`t08_*`], [FHRP], [Cấu hình HSRP, VRRP, GLBP.]),
      ([`t09_*`], [VTP], [Quản lý Domain, VTP Modes, thành viên VTP.]),
    ),
    caption: [Phân loại và mục đích của các nhóm bảng dữ liệu cấu hình],
  ) <tab-database-schema-config>
]

*Nhóm 2: Dữ liệu thu thập từ thiết bị (t08 - t12)*

Đây là các bảng chỉ đọc (Read-only) từ góc độ cấu hình. Dữ liệu được các tiến trình nền (Collector) tự động lấy về từ thiết bị (thông qua kết quả trả về của các lệnh `show`) nhằm phục vụ mục đích giám sát và xác minh sau khi đẩy cấu hình.

#[
  #set par(justify: false)
  #report-table(
    columns: (22%, 43%, 35%),
    cell-align: (center + horizon, left + horizon, left + horizon),
    header: ([Tiền tố bảng], [Phân hệ dữ liệu thu thập], [Đặc điểm]),
    rows: (
      ([`t08_info_*`], [Bảng định tuyến (Routing table)], [Thu thập từ lệnh `show ip route`]),
      ([`t09_info_*`], [Trạng thái DHCP (Pool, Binding, Conflict)], [Ghi nhận tình trạng cấp phát IP thực tế]),
      ([`t10_info_*`], [Trạng thái ACL (Rules, Interface apply)], [Phân tích chi tiết bộ quy tắc ]),
      ([`t11_info_*`], [Trạng thái NAT (Translations, Stats)], [Theo dõi các luồng NAT đang hoạt động]),
      ([`t12_syslog_*`], [Nhật ký hệ thống (Syslog Messages)], [Lưu trữ độc lập, phân tích log tập trung]),
    ),
    caption: [Phân loại các nhóm bảng dữ liệu thu thập (Current State)],
  ) <tab-database-schema-info>
]

*Quản lý vòng đời trạng thái dữ liệu (State Management):*

Trong các bảng cấu hình nghiệp vụ (Nhóm 1), vòng đời của một bản ghi dữ liệu được kiểm soát chặt chẽ thông qua trường `success` với quy ước sau:

- `success = 0`: Cấu hình đang ở trạng thái chờ thêm mới hoặc cập nhật (Pending Add/Update).
- `success = 1`: Cấu hình đã được thực thi và đồng bộ thành công xuống thiết bị (Applied).
- `success = -1`: Cấu hình đang ở trạng thái chờ gỡ bỏ hoặc đã bị xóa mềm (Pending Remove / Soft Delete).

#report-note[
  Đối với các bảng thuộc Nhóm 2 (Dữ liệu thu thập), hệ thống không sử dụng các trường `sync_status` hay `action_Cfg` do bản chất đây không phải là dữ liệu chờ đẩy xuống thiết bị. Trong một số luồng thực thi nền hiện tại của Nhóm 1, hệ thống vẫn duy trì trường `action_Cfg` song song để điều hướng logic; các trường này sẽ được quy chuẩn hóa thống nhất ở các phiên bản tiếp theo.
]
== Thiết kế giao diện

Phần giao diện cần mô tả application shell, device sidebar, feature bar, lazy Loader, các nhóm form/list, process card và View & Push dialog.
== Thiết kế an toàn và xử lý lỗi

Đặc thù của quản trị mạng tự động đòi hỏi tính chính xác cao, do đó hệ thống được thiết kế tích hợp nhiều lớp phòng vệ nhằm giảm thiểu rủi ro:

- *Cô lập môi trường thử nghiệm (Dev-mode Fail-closed):* Hệ thống cung cấp cơ chế Dev-mode chuyên dụng. Khi được kích hoạt, mọi luồng giao tiếp SSH/Telnet hướng tới thiết bị vật lý sẽ bị khóa chặn hoàn toàn theo nguyên tắc "fail-closed", hệ thống chỉ trả về các phản hồi giả lập để an toàn gỡ lỗi.
- *Xác thực dữ liệu (Validation) & Ngắt thời gian chờ (Timeout):* Toàn bộ tham số mạng (IP, Subnet, Port, Wildcard...) đều được xác thực nghiêm ngặt tại tầng giao diện và backend. Các kết nối mạng được thiết lập ngưỡng thời gian chờ để tự động giải phóng tài nguyên, tránh hiện tượng treo ứng dụng khi mất kết nối đột ngột.
- *Quản lý phiên (Session Registry) & Tác vụ nền:* Toàn bộ kết nối mạng được đẩy xuống các tiến trình nền (worker) độc lập nhằm giải phóng luồng giao diện chính. Hệ thống duy trì cơ chế khóa thiết bị (Host Lock) để ngăn ngừa xung đột dữ liệu khi nhiều tiến trình cố gắng ghi cấu hình xuống cùng một thiết bị. Ngoài ra, mật khẩu đăng nhập được bảo vệ và tuyệt đối không ghi lại dưới dạng bản rõ (plain-text).

#report-note[
  Ở phạm vi nghiên cứu hiện tại, hệ thống ưu tiên tính năng tự động hóa và sinh cấu hình chuẩn xác. Các cơ chế bảo mật nâng cao như kho lưu trữ mật khẩu mã hóa (Secret Vault) và tự động hoàn tác trạng thái (Rollback) khi xảy ra lỗi một phần (partial failure) được ghi nhận là định hướng mở rộng trong tương lai.
]