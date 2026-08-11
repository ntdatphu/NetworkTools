# Các phần Switch Layer 2 chưa thể tích hợp an toàn

Các phần dưới đây được chủ động chặn thay vì suy đoán cấu hình và gây ảnh hưởng
switch đang vận hành:

- Chỉ Cisco IOS qua SSH/Telnet được Preview/Push. RESTCONF, NETCONF và platform
  khác chưa có mapping lệnh đã kiểm chứng.
- Pull-sync đã có cho VLAN, switchport/trunk, EtherChannel và VTP status trên
  Cisco IOS. STP, L2 security, SVI/routed port và dữ liệu monitoring chưa có
  parser pull-sync đầy đủ.
- Xoá vật lý một VLAN, EtherChannel, trust port hoặc static MAC khỏi SQLite
  chưa sinh lệnh `no ...` tương ứng. Cần thêm mô hình soft-delete/audit trước
  khi hỗ trợ để app biết chính xác đối tượng nào phải gỡ.
- Port `hybrid` bị chặn khi push vì schema hiện không lưu đủ native/allowed VLAN
  profile cho mode này.
- VTP password trong schema được yêu cầu mã hoá; app không chạy `show vtp
  password`, không import plaintext và vẫn chặn push authentication khi chưa có
  decryptor an toàn.
- Kích hoạt VTPv3 primary server và VTPv3 MST database cần luồng xác nhận
  tương tác riêng nên chưa push tự động.
- EtherChannel hiện push member, protocol/mode và mô tả Port-channel. Schema
  chưa có switchport profile riêng cho Port-channel.
- Khi mọi VLAN security đều tắt, worker gỡ DHCP snooping/DAI theo từng VLAN
  nhưng không tự gỡ global feature để tránh ảnh hưởng cấu hình ngoài app.
- Chưa có trang CRUD riêng cho STP, VTP và EtherChannel; dữ liệu hiện có trong
  SQLite vẫn được Preview/Push qua nút Layer 2 chung.

Ngoài phạm vi theo thiết kế: SVI/routed port/IP routing (Layer 3), QoS,
storm-control và YANG model.
