#pagebreak(weak: true)
= Xây dựng phần mềm

== Môi trường và tổ chức mã nguồn

Khi chốt báo cáo cần ghi phiên bản thực tế của Python, Qt/PyQt6 và các thư viện chính. Cây thư mục trọng tâm gồm `app/ui`, `app/core`, `app/services`, `app/network_code`, `app/database` và `app/tests`.

== Khởi tạo ứng dụng và QML bridge

Mô tả `app/main.py`, các context property, QML module `UI`, settings và network monitor; chỉ nêu các thành phần thực tế được nạp trong runtime desktop.

== Quản lý thiết bị, kết nối và đồng bộ

Trình bày CRUD/import thiết bị, cơ chế tab/session, backup running-config, parsing interface/OSPF và database browser.

== Interface

Module Interface hiện có UI và persistence cho L3/WAN/Tunnel/QoS. Báo cáo phải ghi rõ rằng phần này *chưa có View & Push trong runtime chính* nếu trạng thái mã nguồn chưa thay đổi.

== DHCP

Trình bày Pool, Excluded Address, Helper, staged save, pending state, preview/push và cập nhật cơ sở dữ liệu sau khi worker thực thi.

== Routing

- Static/default route.
- OSPF process, area, network, interface, redistribute và tuning.
- EIGRP process, network, interface và các chính sách liên quan.
- Cơ chế template/worker.
- Lỗi schema đang được phát hiện bởi test hợp đồng.

BGP hoặc multi-router topology không được đặt vào phần kết quả hiện tại nếu chưa có UI, persistence, test và demo tích hợp tương ứng.

== ACL

Trình bày UI/persistence của Standard, Extended, Dynamic, Reflexive và MAC ACL; rule có thứ tự và binding nhiều interface. Cần ghi rõ chưa có controller sinh lệnh/push trong `app/` nếu chưa được tích hợp.

== NAT/PAT

Trình bày các nhóm UI, backend persistence, collector, template, preview/push và cập nhật trạng thái cho Static NAT, Dynamic NAT, PAT, interface role, NAT ACL và route-map.

== Tiện ích hệ thống

Theme, status bar, external tools, terminal, database browser, notification và tác vụ nền.

== Các thành phần chưa tích hợp

Các capability chưa qua integration test, BGP template, topology worker, FastAPI và các module độc lập trong root `backend/` cần được mô tả minh bạch như thành phần chưa tích hợp, không tính là kết quả desktop đã hoàn thành.
