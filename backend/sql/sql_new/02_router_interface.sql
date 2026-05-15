-- ========================================================== 
-- File: 02_interface.sql 
-- ========================================================== 
-- =========================================================
-- INTERFACE
-- =========================================================

CREATE TABLE interface_name (
    iface_id        INTEGER PRIMARY KEY AUTOINCREMENT,
    host            TEXT    NOT NULL,
    interface_name  TEXT    NOT NULL,     -- ví dụ: GigabitEthernet0/0, FastEthernet0/1
    ip_address      TEXT,                 -- ví dụ: 192.168.1.1
    subnet_mask     TEXT,                 -- ví dụ: 255.255.255.0
    description     TEXT,
    shutdown        INTEGER DEFAULT 0,    -- 0 = no shutdown, 1 = shutdown
    success         INTEGER DEFAULT 0,

    FOREIGN KEY (host) REFERENCES devices(host) ON UPDATE CASCADE
                                                ON DELETE CASCADE
);
 
 

-- ========================================================== 
-- File: 10_router_interface.sql 
-- ========================================================== 
-- =========================================================
-- ROUTER INTERFACE - NHÓM BẢNG QUẢN LÝ INTERFACE ROUTER
-- Quan hệ: interface_name (bảng gốc) → các bảng con 1-1 / 1-N
-- Convention giữ nguyên: success: 0=pending | 1=done | -1=pending delete
-- action_Cfg: bitmask INTEGER cho các option có thể ghi đè độc lập
-- =========================================================

-- =========================================================
-- 10a. router_iface_l3
--      Mở rộng interface_name cho thông số Layer 3 thuần
--      Tồn tại 1-1 với interface_name khi interface là L3
--      action_Cfg bitmask 4 bit:
--        bit3=secondary_ip  bit2=mtu  bit1=bandwidth  bit0=description
-- =========================================================
CREATE TABLE IF NOT EXISTS router_iface_l3 (
    iface_id        INTEGER PRIMARY KEY,            -- FK → interface_name.iface_id
    secondary_ip    TEXT,                           -- ip address <x> <mask> secondary
    secondary_mask  TEXT,
    mtu             INTEGER DEFAULT 1500,           -- ip mtu <bytes>
    bandwidth       INTEGER,                        -- bandwidth <kbps> (ảnh hưởng metric)
    delay           INTEGER,                        -- delay <microsec>
    proxy_arp       INTEGER DEFAULT 1               -- 1=enable (mặc định IOS), 0=no proxy-arp
                    CHECK(proxy_arp IN (0,1)),
    unreachables    INTEGER DEFAULT 1               -- 1=ip unreachables, 0=no ip unreachables
                    CHECK(unreachables IN (0,1)),
    directed_broadcast INTEGER DEFAULT 0            -- 1=ip directed-broadcast
                    CHECK(directed_broadcast IN (0,1)),
    success         INTEGER DEFAULT 0,
    action_Cfg      INTEGER DEFAULT 15,             -- bitmask 4 bit

    CHECK(success IN (-1,0,1)),
    CHECK(action_Cfg >= 0),
    CHECK(mtu IS NULL OR mtu BETWEEN 68 AND 65535),
    CHECK(bandwidth IS NULL OR bandwidth > 0),

    FOREIGN KEY (iface_id) REFERENCES interface_name(iface_id)
        ON UPDATE CASCADE ON DELETE CASCADE
);

-- =========================================================
-- 10b. router_iface_subif
--      Subinterface dot1q (router-on-a-stick / WAN)
--      Mỗi subinterface là 1 row, FK về interface_name cha
-- =========================================================
CREATE TABLE IF NOT EXISTS router_iface_subif (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    parent_iface_id INTEGER NOT NULL,               -- FK → interface_name.iface_id (interface vật lý)
    host            TEXT    NOT NULL,
    subif_name      TEXT    NOT NULL,               -- ví dụ: GigabitEthernet0/0.10
    encapsulation   TEXT    NOT NULL DEFAULT 'dot1q'
                    CHECK(encapsulation IN ('dot1q','isl')),
    vlan_id         INTEGER NOT NULL                -- encapsulation dot1q <vlan>
                    CHECK(vlan_id BETWEEN 1 AND 4094),
    native          INTEGER DEFAULT 0               -- 1 = native vlan (không tag)
                    CHECK(native IN (0,1)),
    ip_address      TEXT,
    subnet_mask     TEXT,
    shutdown        INTEGER DEFAULT 0
                    CHECK(shutdown IN (0,1)),
    success         INTEGER DEFAULT 0,

    CHECK(success IN (-1,0,1)),
    UNIQUE(host, subif_name),

    FOREIGN KEY (parent_iface_id) REFERENCES interface_name(iface_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    FOREIGN KEY (host) REFERENCES devices(host)
        ON UPDATE CASCADE ON DELETE CASCADE
);

-- =========================================================
-- 10c. router_iface_acl
--      Gán ACL vào interface (ip access-group <name> in/out)
--      1 interface có thể có tối đa 1 in + 1 out
-- =========================================================
CREATE TABLE IF NOT EXISTS router_iface_acl (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    iface_id        INTEGER NOT NULL,
    acl_id          INTEGER NOT NULL,               -- FK → ACL_DB.Acl_id
    direction       TEXT    NOT NULL
                    CHECK(direction IN ('in','out')),
    success         INTEGER DEFAULT 0,

    CHECK(success IN (-1,0,1)),
    UNIQUE(iface_id, direction),                    -- 1 in + 1 out tối đa

    FOREIGN KEY (iface_id) REFERENCES interface_name(iface_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    FOREIGN KEY (acl_id) REFERENCES ACL_DB(Acl_id)
        ON DELETE CASCADE
);

-- =========================================================
-- 10d. router_iface_nat
--      Đánh dấu interface là nat inside / outside
--      Tách riêng để không phụ thuộc vào nat_interfaces (NAT_DB)
-- =========================================================
CREATE TABLE IF NOT EXISTS router_iface_nat (
    iface_id        INTEGER PRIMARY KEY,
    nat_role        TEXT    NOT NULL
                    CHECK(nat_role IN ('inside','outside')),
    success         INTEGER DEFAULT 0,

    CHECK(success IN (-1,0,1)),

    FOREIGN KEY (iface_id) REFERENCES interface_name(iface_id)
        ON UPDATE CASCADE ON DELETE CASCADE
);

-- =========================================================
-- 10e. router_iface_helper
--      ip helper-address (DHCP relay) — 1 interface N helper
-- =========================================================
CREATE TABLE IF NOT EXISTS router_iface_helper (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    iface_id        INTEGER NOT NULL,
    helper_ip       TEXT    NOT NULL,               -- ip của DHCP server
    success         INTEGER DEFAULT 0,

    CHECK(success IN (-1,0,1)),
    UNIQUE(iface_id, helper_ip),

    FOREIGN KEY (iface_id) REFERENCES interface_name(iface_id)
        ON UPDATE CASCADE ON DELETE CASCADE
);

-- =========================================================
-- 10f. router_iface_ospf
--      Cấu hình OSPF trực tiếp trên interface
--      (ip ospf <pid> area <area> thay vì dùng network statement)
--      Bổ sung cho ospf_interface_settings đã có — dùng iface_id thay vì tên
-- =========================================================
CREATE TABLE IF NOT EXISTS router_iface_ospf (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    iface_id        INTEGER NOT NULL,
    ospf_id         INTEGER NOT NULL,               -- FK → ospf_processes
    area            INTEGER NOT NULL DEFAULT 0,
    cost            INTEGER,
    priority        INTEGER DEFAULT 1               -- ip ospf priority <0-255>
                    CHECK(priority BETWEEN 0 AND 255),
    hello_interval  INTEGER DEFAULT 10,
    dead_interval   INTEGER DEFAULT 40,
    mtu_ignore      INTEGER DEFAULT 0
                    CHECK(mtu_ignore IN (0,1)),
    network_type    TEXT
                    CHECK(network_type IN (NULL,'broadcast','non-broadcast',
                                          'point-to-point','point-to-multipoint')),
    auth_type       TEXT
                    CHECK(auth_type IN (NULL,'plain','message-digest')),
    auth_key        TEXT,
    success         INTEGER DEFAULT 0,

    CHECK(success IN (-1,0,1)),
    UNIQUE(iface_id, ospf_id),

    FOREIGN KEY (iface_id) REFERENCES interface_name(iface_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    FOREIGN KEY (ospf_id) REFERENCES ospf_processes(ospf_id)
        ON DELETE CASCADE
);

-- =========================================================
-- 10g. router_iface_eigrp
--      Liên kết interface_name ↔ eigrp_interface_settings
--      qua iface_id thay vì interface_name text
-- =========================================================
CREATE TABLE IF NOT EXISTS router_iface_eigrp (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    iface_id        INTEGER NOT NULL,
    eigrp_id        INTEGER NOT NULL,               -- FK → eigrp_processes
    bandwidth       INTEGER,                        -- bandwidth override (kbps)
    delay           INTEGER,                        -- delay override (microsec)
    hello_interval  INTEGER,
    hold_time       INTEGER,
    split_horizon   INTEGER DEFAULT 1
                    CHECK(split_horizon IN (0,1)),
    auth_key_chain  TEXT,
    summary_ip      TEXT,                           -- ip summary-address eigrp <as> <ip> <mask>
    summary_mask    TEXT,
    success         INTEGER DEFAULT 0,

    CHECK(success IN (-1,0,1)),
    UNIQUE(iface_id, eigrp_id),

    FOREIGN KEY (iface_id) REFERENCES interface_name(iface_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    FOREIGN KEY (eigrp_id) REFERENCES eigrp_processes(eigrp_id)
        ON DELETE CASCADE
);

-- =========================================================
-- 10h. router_iface_qos
--      QoS trên interface router: trust, shape, police
--      action_Cfg bitmask 3 bit:
--        bit2=policy_out  bit1=policy_in  bit0=trust
-- =========================================================
CREATE TABLE IF NOT EXISTS router_iface_qos (
    iface_id        INTEGER PRIMARY KEY,
    trust_mode      TEXT    NOT NULL DEFAULT 'none'
                    CHECK(trust_mode IN ('none','cos','dscp','ip-precedence')),
    policy_in       TEXT,                           -- tên service-policy input
    policy_out      TEXT,                           -- tên service-policy output
    shape_rate      INTEGER,                        -- traffic shape average <bps>
    police_rate     INTEGER,                        -- police rate <bps>
    police_burst    INTEGER,                        -- police burst <bytes>
    success         INTEGER DEFAULT 0,
    action_Cfg      INTEGER DEFAULT 7,              -- bitmask 3 bit

    CHECK(success IN (-1,0,1)),
    CHECK(action_Cfg >= 0),

    FOREIGN KEY (iface_id) REFERENCES interface_name(iface_id)
        ON UPDATE CASCADE ON DELETE CASCADE
);

-- =========================================================
-- 10i. router_iface_tunnel
--      GRE / IPsec tunnel interface
--      action_Cfg bitmask 3 bit:
--        bit2=keepalive  bit1=tunnel_key  bit0=description
-- =========================================================
CREATE TABLE IF NOT EXISTS router_iface_tunnel (
    iface_id        INTEGER PRIMARY KEY,
    tunnel_mode     TEXT    NOT NULL DEFAULT 'gre'
                    CHECK(tunnel_mode IN ('gre','ipip','ipsec','gre-ipsec')),
    tunnel_src      TEXT    NOT NULL,               -- tunnel source <ip/interface>
    tunnel_dst      TEXT    NOT NULL,               -- tunnel destination <ip>
    tunnel_key      INTEGER,                        -- tunnel key <number>
    keepalive_sec   INTEGER,                        -- keepalive <sec>
    keepalive_retry INTEGER,
    ipsec_profile   TEXT,                           -- tunnel protection ipsec profile <name>
    success         INTEGER DEFAULT 0,
    action_Cfg      INTEGER DEFAULT 7,

    CHECK(success IN (-1,0,1)),
    CHECK(action_Cfg >= 0),

    FOREIGN KEY (iface_id) REFERENCES interface_name(iface_id)
        ON UPDATE CASCADE ON DELETE CASCADE
);

-- =========================================================
-- 10j. router_iface_wan
--      Thông số WAN: PPPoE, serial encapsulation
--      action_Cfg bitmask 2 bit:
--        bit1=pppoe  bit0=serial_encap
-- =========================================================
CREATE TABLE IF NOT EXISTS router_iface_wan (
    iface_id            INTEGER PRIMARY KEY,
    encap_type          TEXT    NOT NULL DEFAULT 'none'
                        CHECK(encap_type IN ('none','pppoe','hdlc','ppp','frame-relay')),
    pppoe_dialer_pool   INTEGER,                    -- pppoe-client dial-pool-number <n>
    ppp_auth            TEXT
                        CHECK(ppp_auth IN (NULL,'pap','chap')),
    ppp_username        TEXT,
    ppp_password        TEXT,
    clock_rate          INTEGER,                    -- clock rate (DCE serial)
    lmi_type            TEXT
                        CHECK(lmi_type IN (NULL,'cisco','ansi','q933a')),
    success             INTEGER DEFAULT 0,
    action_Cfg          INTEGER DEFAULT 3,

    CHECK(success IN (-1,0,1)),
    CHECK(action_Cfg >= 0),

    FOREIGN KEY (iface_id) REFERENCES interface_name(iface_id)
        ON UPDATE CASCADE ON DELETE CASCADE
);
