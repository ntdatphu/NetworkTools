#pagebreak(weak: true)
= Kết luận và hướng phát triển

== Kết quả đạt được

Bản báo cáo cuối cùng nên lập bảng mục tiêu – trạng thái – minh chứng dựa trên ma trận chức năng và kết quả test/lab thực tế. Chỉ các chức năng có bằng chứng tương ứng mới được xem là kết quả đã hoàn thành.

== Ý nghĩa

NetworkTools tạo một nền tảng thực hành tích hợp kiến thức mạng, Python, desktop UI, dữ liệu và tự động hóa; qua đó hướng đến giảm các thao tác cấu hình lặp lại trong môi trường phòng lab.

== Hạn chế

Các hạn chế cần nêu trung thực gồm lỗi test còn lại, bảo mật credential, phạm vi thiết bị, thiếu rollback, thiếu đo quy mô và một số module mới chỉ có persistence/schema hoặc template.

== Lộ trình phát triển ưu tiên

+ Đồng bộ schema/code OSPF, EIGRP và đưa toàn bộ test về trạng thái đạt.
+ Hoàn thiện View & Push cho Interface và ACL.
+ Bổ sung test worker NAT, test lab và cơ chế verify sau push.
+ Mã hóa secret, audit log, quyền người dùng và rollback.
+ Tích hợp VLAN/Switch Port, sau đó BGP và VRF.
+ Topology discovery và static route đa router.
+ SFTP backup/versioning, Syslog, Serial Console, Firewall và plugin đa hãng.
