# DATA.SQL ANALYSIS

## Bản tiếng Việt

### 1. Mục tiêu của schema
- Đây là schema SQLite cho một ứng dụng quản lý cấu hình mạng theo từng thiết bị.
- Thiết bị là thực thể gốc trong bảng devices.
- Hầu hết các domain khác đều gắn với host của thiết bị và dùng cascade delete.

### 2. Cấu trúc tổng thể
- Bật ràng buộc khóa ngoại bằng PRAGMA.
- Tổng cộng 27 bảng.
- Mô hình theo kiểu parent-child là chính, có một số bảng độc lập theo host:
  - Parent theo domain: ROUTING_DB, ACL_DB, NAT_ACL_DB, NAT_DB.
  - Child rules/details: static routes, OSPF/EIGRP networks, ACL rules, NAT mappings, DHCP pools, excluded addresses, RESTCONF credential table.

### 3. Nhóm bảng chính
- Devices:
  - devices là bảng gốc, khóa chính host.
  - yangcfg lưu thông tin đăng nhập RESTCONF của Cisco theo host (nếu thiết bị có hỗ trợ).
- Routing:
  - ROUTING_DB là parent theo route_type và host cho OSPF/EIGRP.
  - static_default_routes, static_routes là bảng độc lập theo host cho static/default route.
  - ospf_processes + ospf_networks cho OSPF.
  - eigrp_processes + eigrp_networks cho EIGRP.
- ACL:
  - ACL_DB là parent ACL theo host.
  - 5 loại rule riêng: standard, extended, dynamic, reflexive, mac.
- NAT ACL:
  - NAT_ACL_DB là parent ACL dùng cho NAT.
  - nat_standard_acl_rules, nat_extended_acl_rules.
- NAT:
  - NAT_DB là parent theo nat_type.
  - nat_interfaces, nat_pools, nat_static_mappings.
  - nat_dynamic_rules, nat_overload_interface_rules, nat_exempt_rules.
- DHCP:
  - dhcp_pool.
  - excluded_address.

### 4. Quan hệ dữ liệu và hành vi cascade
- devices(host) là gốc tham chiếu cho nhiều domain qua FK ON DELETE CASCADE.
- Khi xóa 1 thiết bị:
  - Routing/ACL/NAT/DHCP/yangcfg liên quan sẽ bị xóa dây chuyền.
- Riêng DHCP dùng ON UPDATE CASCADE + ON DELETE CASCADE ở FK host.
- Bảng yangcfg cũng dùng ON UPDATE CASCADE + ON DELETE CASCADE theo host.

### 5. Cách mô hình nghiệp vụ
- Thiết kế bám sát cấu hình mạng thực tế kiểu Cisco-like:
  - OSPF process có networks + area/wildcard.
  - EIGRP process có AS, auto-summary, passive default.
  - ACL chia loại rõ theo cú pháp lệnh.
  - NAT tách các chế độ: static, dynamic, overload, port-forward.
- Kiểu dữ liệu linh hoạt (TEXT/INTEGER) để dễ map trực tiếp từ UI/form.

### 6. Điểm mạnh
- Domain coverage rộng: Routing + ACL + NAT + DHCP trong một schema thống nhất.
- Tách parent-child hợp lý, dễ mở rộng thêm rule type.
- Sử dụng foreign key cascade giúp giữ integrity tốt khi xóa thiết bị.

### 7. Điểm cần lưu ý
- Chính tả cột defaut trong dhcp_pool có vẻ là typo của default.
- Tên bảng/cột chưa nhất quán chữ hoa-thường (ROUTING_DB vs nat_pools).
- Chưa có CHECK constraint cho các giá trị dạng enum (route_type, acl_type, nat_type, action...).
- Trường password trong devices đang là TEXT thô, cần cân nhắc bảo mật ở tầng ứng dụng/mã hóa.
- Trường password trong yangcfg cũng là TEXT thô, nên áp dụng cùng chính sách bảo mật với devices.password.

---

## English Version

### 1. Schema objective
- This is a SQLite schema for a network configuration management application per device.
- Devices are the root entity in the devices table.
- Most other domains are linked by host and use cascade delete.

### 2. Overall structure
- Foreign-key enforcement is enabled via PRAGMA.
- Total: 27 tables.
- Mostly parent-child modeling with some host-based independent tables:
  - Domain parents: ROUTING_DB, ACL_DB, NAT_ACL_DB, NAT_DB.
  - Child rule/detail tables: static routes, OSPF/EIGRP networks, ACL rules, NAT mappings, DHCP pools, excluded addresses, RESTCONF credential table.

### 3. Main table groups
- Devices:
  - devices is the root table, primary key host.
  - yangcfg stores Cisco RESTCONF login credentials per host (when supported on that device).
- Routing:
  - ROUTING_DB as parent by route_type and host for OSPF/EIGRP.
  - static_default_routes, static_routes as independent host-based tables for default/static routing.
  - ospf_processes + ospf_networks for OSPF.
  - eigrp_processes + eigrp_networks for EIGRP.
- ACL:
  - ACL_DB as ACL parent by host.
  - Five dedicated rule tables: standard, extended, dynamic, reflexive, mac.
- NAT ACL:
  - NAT_ACL_DB as NAT ACL parent.
  - nat_standard_acl_rules, nat_extended_acl_rules.
- NAT:
  - NAT_DB as parent by nat_type.
  - nat_interfaces, nat_pools, nat_static_mappings.
  - nat_dynamic_rules, nat_overload_interface_rules, nat_exempt_rules.
- DHCP:
  - dhcp_pool.
  - excluded_address.

### 4. Data relationships and cascade behavior
- devices(host) is the main reference target for many domains with ON DELETE CASCADE FKs.
- Deleting one device will cascade-delete related Routing/ACL/NAT/DHCP data.
- Deleting one device will cascade-delete related Routing/ACL/NAT/DHCP/yangcfg data.
- DHCP specifically uses ON UPDATE CASCADE + ON DELETE CASCADE on host FK.
- yangcfg also uses ON UPDATE CASCADE + ON DELETE CASCADE on host FK.

### 5. Business modeling approach
- The design closely follows real network configuration patterns (Cisco-like):
  - OSPF process with networks + area/wildcard.
  - EIGRP process with AS, auto-summary, passive-default.
  - ACL split by syntax/type.
  - NAT split by mode: static, dynamic, overload, port-forward.
- Flexible data types (TEXT/INTEGER) make UI/form mapping straightforward.

### 6. Strengths
- Broad domain coverage: Routing + ACL + NAT + DHCP in one unified schema.
- Good parent-child decomposition, easy to extend with new rule types.
- Foreign-key cascades help maintain integrity when a device is removed.

### 7. Notes and potential concerns
- Column name defaut in dhcp_pool appears to be a typo for default.
- Table/column naming is case-style inconsistent (ROUTING_DB vs nat_pools).
- No CHECK constraints for enum-like fields (route_type, acl_type, nat_type, action, etc.).
- devices.password is stored as plain TEXT; security handling should be addressed at application/encryption layer.
- yangcfg.password is also stored as plain TEXT and should follow the same security controls as devices.password.
