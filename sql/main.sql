-- =========================================================
-- MAIN SQL ENTRY POINT
-- Liên kết tất cả các file SQL schema theo đúng thứ tự
-- phụ thuộc (foreign key).
-- =========================================================

PRAGMA foreign_keys = ON;

-- 01: Core devices (phải đứng đầu vì các bảng khác FK tới đây)
.read 01_devices.sql

-- 02: Interface
.read 02_interface.sql

-- 03: Static Route
.read 03_static_route.sql

-- 04: OSPF
.read 04_ospf.sql

-- 05: EIGRP
.read 05_eigrp.sql

-- 06: DHCP
.read 06_dhcp.sql

-- 07: ACL
.read 07_acl.sql

-- 08: NAT ACL (phải trước NAT vì NAT FK tới đây)
.read 08_nat_acl.sql

-- 09: NAT
.read 09_nat.sql
