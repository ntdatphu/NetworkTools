#pagebreak(weak: true)
= Phân tích và thiết kế hệ thống

== Tác nhân và ca sử dụng

Tác nhân chính là người quản trị hoặc phụ trách phòng lab. Các ca sử dụng cốt lõi gồm quản lý thiết bị, ping/kết nối, đồng bộ, chỉnh cấu hình, preview/push, xem backup, duyệt cơ sở dữ liệu và tùy chỉnh ứng dụng.

== Yêu cầu chức năng

Các yêu cầu cần được tách thành nhóm bắt buộc hiện tại và nhóm mở rộng. Khi hoàn thiện báo cáo, mỗi yêu cầu nên có mã dạng `FR-xx` và được ánh xạ đến module hoặc minh chứng tương ứng.

== Yêu cầu phi chức năng

- UI nhất quán và không chặn luồng chính khi chạy tác vụ nền.
- Không mở session thật cho host dev-mode.
- Hạn chế lỗi dữ liệu bằng validation và khóa ngoại.
- Tách UI, bridge, nghiệp vụ, worker và template.
- Ghi nhận rõ giới hạn bảo mật secret hiện tại.

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
