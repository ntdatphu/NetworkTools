#import "../config/tables.typ": report-table

#pagebreak(weak: true)
= Thử nghiệm và đánh giá

== Mục tiêu và môi trường

Khi chốt báo cáo cần ghi cấu hình máy, hệ điều hành, phiên bản Python/Qt, commit, image Cisco IOS, EVE-NG/GNS3 và topology sử dụng trong thử nghiệm.

== Kiểm thử tự động

Các nhóm test hiện được định hướng gồm:

- Persistence: DHCP, ACL, NAT.
- Routing database contract.
- Dev-mode và worker safety.
- UI contract.
- QML smoke/load.

Tại thời điểm rà soát đề cương, 30 test được phát hiện; 28 test chức năng vượt qua và 2 test hợp đồng OSPF/EIGRP thất bại do code truy cập `t04_ospf_interface_settings` và `t04_eigrp_interface_settings` không tồn tại trong schema hiện hành. Số liệu này phải được chạy lại trước khi nộp báo cáo.

== Kịch bản lab tối thiểu

#report-table(
  columns: (1fr, 2.2fr, 4fr),
  header: ([Mã], [Kịch bản], [Kết quả cần xác minh]),
  rows: (
    ([LAB-01], [Thêm thiết bị, ping, connect/sync], [Có backup và dữ liệu interface/OSPF]),
    ([LAB-02], [DHCP pool/excluded/helper], [Client nhận địa chỉ; DB chuyển pending → applied]),
    ([LAB-03], [Static route], [Route xuất hiện trong `show ip route` và ping thành công]),
    ([LAB-04], [OSPF], [Neighbor/full, route học đúng, DB đồng bộ]),
    ([LAB-05], [EIGRP], [Neighbor và route học đúng]),
    ([LAB-06], [NAT/PAT], [Có translation và lưu lượng qua được]),
    ([LAB-07], [Dev-mode], [Không mở kết nối thật; kết quả mô phỏng có kiểm soát]),
    ([LAB-08], [Sai mật khẩu/mất kết nối], [App không treo, báo lỗi và không đánh dấu applied]),
  ),
  caption: [Các kịch bản lab tối thiểu],
) <tab-lab-scenarios>

ACL và Interface chỉ nên đưa vào lab push sau khi controller tương ứng được tích hợp.

== Đo hiệu năng

Đo thời gian thao tác thủ công và bằng ứng dụng cho 1, 5 và 10 thiết bị; thời gian preview/push; tỷ lệ thành công; CPU/RAM nếu có ý nghĩa. Không điền số giả định vào phần kết quả.

== Đánh giá

*Ưu điểm:* UI tập trung, cấu trúc module, preview/pending state, test dev-mode và database schema rộng.

*Hạn chế:* phạm vi Cisco IOS, secret dạng rõ, parser phụ thuộc CLI, schema routing đang lệch test, mức hoàn thiện không đồng đều, chưa có rollback và chưa kiểm thử quy mô lớn.
