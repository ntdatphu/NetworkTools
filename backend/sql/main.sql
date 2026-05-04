-- =========================================================
-- MAIN SQL ENTRY POINT (standalone - all schemas inlined)
-- =========================================================
PRAGMA foreign_keys = ON;

-- ── 01_devices.sql ─────────────────────────────────────────────
-- =========================================================
-- DEVICES (THIẾT BỊ)
-- =========================================================

CREATE TABLE devices (
    host        TEXT PRIMARY KEY,
    device_name TEXT,
    method      TEXT,
    portnumber  INTEGER,
    username    TEXT,
    password    TEXT,
    os          TEXT,
    role        TEXT,
    success     INTEGER DEFAULT 0,
    yangcfg     INTEGER DEFAULT 0
);

CREATE TABLE yangcfg (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    host        TEXT NOT NULL,
    username    TEXT,
    password    TEXT,
    success     INTEGER DEFAULT 0,
    FOREIGN KEY (host) REFERENCES devices(host) ON UPDATE CASCADE
                              ON DELETE CASCADE
);

-- ── 02_interface.sql ─────────────────────────────────────────────
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

-- ── 03_static_route.sql ─────────────────────────────────────────────
-- =========================================================
-- STATIC ROUTE
-- =========================================================

-- Default route: ip route 0.0.0.0 0.0.0.0 <next-hop>
CREATE TABLE static_default_routes (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    host          TEXT NOT NULL,
    next_hop_ip   TEXT NOT NULL,          -- ví dụ: 192.168.1.1
    success       INTEGER DEFAULT 0,

    FOREIGN KEY (host) REFERENCES devices(host) ON DELETE CASCADE
);

-- Static route thường
CREATE TABLE static_routes (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    host          TEXT NOT NULL,
    network       TEXT NOT NULL,          -- ví dụ: 10.0.0.0
    subnet_mask   TEXT NOT NULL,          -- ví dụ: 255.255.255.0
    next_hop      TEXT NOT NULL,          -- ví dụ: 192.168.1.1
    ad            INTEGER DEFAULT 1,      -- administrative distance
    success       INTEGER DEFAULT 0,

    FOREIGN KEY (host) REFERENCES devices(host) ON DELETE CASCADE
);

-- ── 04_ospf.sql ─────────────────────────────────────────────
-- =========================================================
-- OSPF - SCHEMA ĐẦY ĐỦ
-- Thay thế và mở rộng bảng ospf_processes, ospf_networks
-- trong data.sql để hỗ trợ toàn bộ tính năng OSPF
-- =========================================================

-- =========================================================
-- 1. TIẾN TRÌNH OSPF (ospf_processes)
--    Mở rộng bảng gốc: thêm reference_bandwidth,
--    passive_default, default_originate, default_originate_always
-- =========================================================
CREATE TABLE IF NOT EXISTS ospf_processes (
    ospf_id                  INTEGER PRIMARY KEY AUTOINCREMENT,
    host                     TEXT    NOT NULL,
    process_id               INTEGER NOT NULL,   -- router ospf <process_id>
    router_id                TEXT,               -- router-id x.x.x.x
    reference_bandwidth      INTEGER,            -- auto-cost reference-bandwidth <Mbps>
    passive_default          INTEGER DEFAULT 0,  -- 1 = passive-interface default
    default_originate        INTEGER DEFAULT 0,  -- 1 = default-information originate
    default_originate_always INTEGER DEFAULT 0,  -- 1 = thêm keyword always
    success                  INTEGER DEFAULT 0,

    UNIQUE (host, process_id),
    FOREIGN KEY (host) REFERENCES devices(host) ON DELETE CASCADE
);

-- =========================================================
-- 2. QUẢNG BÁ MẠNG (ospf_networks)
--    Giữ nguyên cấu trúc gốc, thêm UNIQUE constraint
-- =========================================================
CREATE TABLE IF NOT EXISTS ospf_networks (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    ospf_id     INTEGER NOT NULL,
    network     TEXT    NOT NULL,   -- 10.0.0.0
    wildcard    TEXT    NOT NULL,   -- 0.255.255.255
    area        INTEGER NOT NULL,   -- 0 / 10 / 67 ...
    success     INTEGER DEFAULT 0,

    UNIQUE (ospf_id, network, wildcard, area),
    FOREIGN KEY (ospf_id) REFERENCES ospf_processes(ospf_id) ON DELETE CASCADE
);

-- =========================================================
-- 3. ADMINISTRATIVE DISTANCE (ospf_distance)
--    Tách riêng vì OSPF cho phép đặt AD độc lập cho từng loại
--    distance ospf external <x> intra-area <y> inter-area <z>
-- =========================================================
CREATE TABLE IF NOT EXISTS ospf_distance (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    ospf_id     INTEGER NOT NULL UNIQUE,
    external    INTEGER,    -- AD cho external routes   (mặc định 110)
    intra_area  INTEGER,    -- AD cho intra-area routes (mặc định 110)
    inter_area  INTEGER,    -- AD cho inter-area routes (mặc định 110)
    success     INTEGER DEFAULT 0,

    FOREIGN KEY (ospf_id) REFERENCES ospf_processes(ospf_id) ON DELETE CASCADE
);

-- =========================================================
-- 4. CẤU HÌNH AREA (ospf_areas)
--    area <id> stub / nssa / normal + no-summary + authentication
-- =========================================================
CREATE TABLE IF NOT EXISTS ospf_areas (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    ospf_id         INTEGER NOT NULL,
    area_id         INTEGER NOT NULL,   -- 0, 10, 20, 67 ...
    area_type       TEXT    DEFAULT 'normal'
                    CHECK(area_type IN ('normal','stub','nssa')),
    no_summary      INTEGER DEFAULT 0,  -- 1 = no-summary (stub totally / nssa totally)
    authentication  TEXT                -- NULL / 'plain' / 'message-digest'
                    CHECK(authentication IN (NULL,'plain','message-digest')),
    success         INTEGER DEFAULT 0,

    UNIQUE (ospf_id, area_id),
    FOREIGN KEY (ospf_id) REFERENCES ospf_processes(ospf_id) ON DELETE CASCADE
);

-- =========================================================
-- 5. RANGE SUMMARY THEO AREA (ospf_area_ranges)
--    area <id> range <ip> <mask>
-- =========================================================
CREATE TABLE IF NOT EXISTS ospf_area_ranges (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    area_db_id  INTEGER NOT NULL,   -- FK → ospf_areas.id
    ip          TEXT    NOT NULL,   -- 172.16.0.0
    mask        TEXT    NOT NULL,   -- 255.255.0.0
    advertise   INTEGER DEFAULT 1,  -- 1 = advertise, 0 = not-advertise
    cost        INTEGER,            -- tùy chọn: override cost
    success     INTEGER DEFAULT 0,

    UNIQUE (area_db_id, ip, mask),
    FOREIGN KEY (area_db_id) REFERENCES ospf_areas(id) ON DELETE CASCADE
);

-- =========================================================
-- 6. REDISTRIBUTE (ospf_redistribute)
--    redistribute static/connected/eigrp/bgp subnets ...
-- =========================================================
CREATE TABLE IF NOT EXISTS ospf_redistribute (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    ospf_id     INTEGER NOT NULL,
    protocol    TEXT    NOT NULL    -- static / connected / eigrp / bgp / rip / isis
                CHECK(protocol IN ('static','connected','eigrp','bgp','rip','isis')),
    process_id  INTEGER,            -- bắt buộc với eigrp / bgp
    subnets     INTEGER DEFAULT 1,  -- 1 = thêm keyword subnets
    metric      INTEGER,            -- metric tuỳ chọn
    metric_type INTEGER             -- 1 hoặc 2 (E1 / E2)
                CHECK(metric_type IN (NULL,1,2)),
    route_map   TEXT,               -- tên route-map nếu có
    success     INTEGER DEFAULT 0,

    UNIQUE (ospf_id, protocol, process_id),
    FOREIGN KEY (ospf_id) REFERENCES ospf_processes(ospf_id) ON DELETE CASCADE
);

-- =========================================================
-- 7. PASSIVE INTERFACE TỪNG CỔNG (ospf_passive_interfaces)
--    passive-interface <name>  /  no passive-interface <name>
--    (khi passive_default = 1, cổng nào passive = 0 nghĩa là no passive-interface)
-- =========================================================
CREATE TABLE IF NOT EXISTS ospf_passive_interfaces (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    ospf_id         INTEGER NOT NULL,
    interface_name  TEXT    NOT NULL,   -- GigabitEthernet0/3
    passive         INTEGER DEFAULT 1,  -- 1 = passive, 0 = no passive (dùng khi passive_default = 1)
    success         INTEGER DEFAULT 0,

    UNIQUE (ospf_id, interface_name),
    FOREIGN KEY (ospf_id) REFERENCES ospf_processes(ospf_id) ON DELETE CASCADE
);

-- =========================================================
-- 8. TUNING OSPF (ospf_tuning)
--    maximum-paths, max-lsa, timers throttle spf/lsa
-- =========================================================
CREATE TABLE IF NOT EXISTS ospf_tuning (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    ospf_id         INTEGER NOT NULL UNIQUE,

    -- maximum-paths <1-32>
    maximum_paths   INTEGER,

    -- max-lsa <number>
    max_lsa         INTEGER,

    -- timers throttle spf <delay> <min-delay> <max-delay>  (đơn vị: ms)
    spf_delay       INTEGER,
    spf_min_delay   INTEGER,
    spf_max_delay   INTEGER,

    -- timers throttle lsa all <delay> <min-delay> <max-delay>  (đơn vị: ms)
    lsa_delay       INTEGER,
    lsa_min_delay   INTEGER,
    lsa_max_delay   INTEGER,

    success         INTEGER DEFAULT 0,

    FOREIGN KEY (ospf_id) REFERENCES ospf_processes(ospf_id) ON DELETE CASCADE
);

-- =========================================================
-- 9. CÀI ĐẶT OSPF TRÊN INTERFACE (ospf_interface_settings)
--    ip ospf <process-id> area <area>
--    ip ospf cost / hello-interval / dead-interval
--    ip ospf mtu-ignore / network / bfd
--    ip ospf authentication message-digest
-- =========================================================
CREATE TABLE IF NOT EXISTS ospf_interface_settings (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    ospf_id         INTEGER NOT NULL,   -- FK → ospf_processes
    interface_name  TEXT    NOT NULL,   -- GigabitEthernet0/1
    area            INTEGER NOT NULL,   -- area được gán

    -- Tuning trên interface
    cost            INTEGER,            -- ip ospf cost <1-65535>
    hello_interval  INTEGER,            -- ip ospf hello-interval <giây>
    dead_interval   INTEGER,            -- ip ospf dead-interval <giây> (tuỳ chọn)
    mtu_ignore      INTEGER DEFAULT 0,  -- 1 = ip ospf mtu-ignore
    bfd             INTEGER DEFAULT 0,  -- 1 = ip ospf bfd

    -- Loại mạng trên interface
    network_type    TEXT                -- broadcast / non-broadcast / point-to-point / point-to-multipoint
                    CHECK(network_type IN (NULL,'broadcast','non-broadcast','point-to-point','point-to-multipoint')),

    -- Xác thực trên interface (ghi đè xác thực cấp area)
    auth_type       TEXT                -- NULL / 'plain' / 'message-digest'
                    CHECK(auth_type IN (NULL,'plain','message-digest')),

    success         INTEGER DEFAULT 0,

    UNIQUE (ospf_id, interface_name, area),
    FOREIGN KEY (ospf_id) REFERENCES ospf_processes(ospf_id) ON DELETE CASCADE
);

-- ── 05_eigrp.sql ─────────────────────────────────────────────
-- =========================================================
-- EIGRP
-- success: 0=pending write, 1=done, -1=pending delete
-- action_Cfg (eigrp_processes): TEXT nhi phan 7 bit cho option ghi de cap process
-- =========================================================

-- 1 process EIGRP
CREATE TABLE eigrp_processes (
    eigrp_id          INTEGER PRIMARY KEY AUTOINCREMENT,
    host              TEXT NOT NULL,
    as_number         INTEGER NOT NULL,    -- router eigrp 100

    -- Core process tuning
    router_id         TEXT,
    timers_active_time INTEGER,
    bfd_all_interfaces INTEGER DEFAULT 0,
    auto_summary      INTEGER DEFAULT 0,   -- no auto-summary / auto-summary
    passive_default   INTEGER DEFAULT 0,
    metric_weights    TEXT DEFAULT "0 1 0 1 0 0",
    distance_internal INTEGER,
    distance_external INTEGER,
    variance          INTEGER,
    maximum_paths     INTEGER,

    -- Stub
    stub_enabled      INTEGER DEFAULT 0,
    stub_options      TEXT,
    stub_leak_map     TEXT,

    -- Backward-compatible flag and process-level override config
    action            INTEGER DEFAULT 15,
    action_Cfg        TEXT DEFAULT '1111111',
    success           INTEGER DEFAULT 0,

    CHECK(bfd_all_interfaces IN (0,1)),
    CHECK(auto_summary IN (0,1)),
    CHECK(passive_default IN (0,1)),
    CHECK(stub_enabled IN (0,1)),
    CHECK(action >= 0),
    CHECK(length(action_Cfg) = 7 AND action_Cfg GLOB '[01][01][01][01][01][01][01]'),
    CHECK(success IN (-1,0,1)),

    UNIQUE (host, as_number),

    FOREIGN KEY (host) REFERENCES devices(host) ON DELETE CASCADE
);

-- Danh sách network của từng process EIGRP
CREATE TABLE eigrp_networks (
    id                INTEGER PRIMARY KEY AUTOINCREMENT,
    eigrp_id          INTEGER NOT NULL,
    network           TEXT NOT NULL,       -- ví dụ: 10.0.0.0
    wildcard          TEXT,                -- ví dụ: 0.0.0.255
    interface_name    TEXT,                -- ví dụ: GigabitEthernet0/0
    success           INTEGER DEFAULT 0,

    CHECK(success IN (-1,0,1)),
    UNIQUE (eigrp_id, network, wildcard, interface_name),

    FOREIGN KEY (eigrp_id) REFERENCES eigrp_processes(eigrp_id) ON DELETE CASCADE
);

-- 2 Interface-level EIGRP settings
CREATE TABLE eigrp_interface_settings (
    id                INTEGER PRIMARY KEY AUTOINCREMENT,
    eigrp_id          INTEGER NOT NULL,
    interface_name    TEXT NOT NULL,

    bandwidth         INTEGER,
    delay             INTEGER,
    hello_interval    INTEGER,
    hold_time         INTEGER,

    auth_key_chain    TEXT,
    summary_ip        TEXT,
    summary_mask      TEXT,

    split_horizon     INTEGER,             -- 1=enable, 0=disable
    bandwidth_percent INTEGER,
    next_hop_self     INTEGER DEFAULT 0,   -- 1=ip next-hop-self eigrp <as>

    bfd               INTEGER DEFAULT 0,
    bfd_tx            INTEGER,
    bfd_rx            INTEGER,
    bfd_multiplier    INTEGER,
    success           INTEGER DEFAULT 0,

    CHECK(split_horizon IN (NULL,0,1)),
    CHECK(next_hop_self IN (0,1)),
    CHECK(bfd IN (0,1)),
    CHECK(success IN (-1,0,1)),
    UNIQUE (eigrp_id, interface_name),

    FOREIGN KEY (eigrp_id) REFERENCES eigrp_processes(eigrp_id) ON DELETE CASCADE
);

-- 3 Passive/no-passive interface per process
CREATE TABLE eigrp_passive_interfaces (
    id                INTEGER PRIMARY KEY AUTOINCREMENT,
    eigrp_id          INTEGER NOT NULL,
    interface_name    TEXT NOT NULL,
    mode              TEXT NOT NULL         -- passive / no-passive
                      CHECK(mode IN ('passive','no-passive')),
    success           INTEGER DEFAULT 0,

    CHECK(success IN (-1,0,1)),
    UNIQUE (eigrp_id, interface_name, mode),

    FOREIGN KEY (eigrp_id) REFERENCES eigrp_processes(eigrp_id) ON DELETE CASCADE
);

-- 4 distribute-list
CREATE TABLE eigrp_distribute_lists (
    id                INTEGER PRIMARY KEY AUTOINCREMENT,
    eigrp_id          INTEGER NOT NULL,
    list_name         TEXT NOT NULL,
    direction         TEXT NOT NULL         -- in / out
                      CHECK(direction IN ('in','out')),
    interface_name    TEXT,
    success           INTEGER DEFAULT 0,

    CHECK(success IN (-1,0,1)),
    UNIQUE (eigrp_id, list_name, direction, interface_name),

    FOREIGN KEY (eigrp_id) REFERENCES eigrp_processes(eigrp_id) ON DELETE CASCADE
);

-- 5 offset-list
CREATE TABLE eigrp_offset_lists (
    id                INTEGER PRIMARY KEY AUTOINCREMENT,
    eigrp_id          INTEGER NOT NULL,
    list_name         TEXT NOT NULL,
    direction         TEXT NOT NULL         -- in / out
                      CHECK(direction IN ('in','out')),
    value             INTEGER NOT NULL,
    interface_name    TEXT,
    success           INTEGER DEFAULT 0,

    CHECK(success IN (-1,0,1)),
    UNIQUE (eigrp_id, list_name, direction, value, interface_name),

    FOREIGN KEY (eigrp_id) REFERENCES eigrp_processes(eigrp_id) ON DELETE CASCADE
);

-- 6 redistribute
CREATE TABLE eigrp_redistribute (
    id                INTEGER PRIMARY KEY AUTOINCREMENT,
    eigrp_id          INTEGER NOT NULL,
    protocol          TEXT NOT NULL,        -- static/connected/ospf/bgp/rip/eigrp...
    route_map         TEXT,

    metric_bw         INTEGER,
    metric_delay      INTEGER,
    metric_reliability INTEGER,
    metric_load       INTEGER,
    metric_mtu        INTEGER,

    success           INTEGER DEFAULT 0,

    CHECK(success IN (-1,0,1)),
    UNIQUE (eigrp_id, protocol, route_map),

    FOREIGN KEY (eigrp_id) REFERENCES eigrp_processes(eigrp_id) ON DELETE CASCADE
);

-- 7 key chain (global, per host)
CREATE TABLE eigrp_key_chains (
    id                INTEGER PRIMARY KEY AUTOINCREMENT,
    host              TEXT NOT NULL,
    chain_name        TEXT NOT NULL,
    key_id            INTEGER,
    key_string        TEXT,
    accept_lifetime   TEXT,
    send_lifetime     TEXT,
    success           INTEGER DEFAULT 0,

    CHECK(success IN (-1,0,1)),
    UNIQUE (host, chain_name, key_id),

    FOREIGN KEY (host) REFERENCES devices(host) ON DELETE CASCADE
);

-- ── 06_dhcp.sql ─────────────────────────────────────────────
-- =========================================================
-- DHCP
-- success: 0=pending write, 1=done, -1=pending delete
-- action_Cfg (chỉ dhcp_pool): TEXT nhị phân 3 bit cho option ghi đè
--  bit2=defaut(default-router), bit1=dns, bit0=lease
-- =========================================================

CREATE TABLE dhcp_pool (
    dhcp_id    INTEGER PRIMARY KEY AUTOINCREMENT,
    host       TEXT    NOT NULL,
    pool       TEXT    NOT NULL,
    network    TEXT    NOT NULL,
    subnetmask TEXT    NOT NULL,
    defaut     TEXT,
    dns        TEXT,
    lease      TEXT DEFAULT '1',  -- mặc định 1 ngày cấu trúc D HH MM SS
    success    INTEGER DEFAULT 0,
    action_Cfg TEXT DEFAULT '111',  -- dạng nhị phân: bit2..bit0

    FOREIGN KEY (host) REFERENCES devices(host) ON UPDATE CASCADE
                                                ON DELETE CASCADE
);

CREATE TABLE excluded_address (
    ex_id    INTEGER PRIMARY KEY AUTOINCREMENT,
    host     TEXT    NOT NULL,
    start_ip TEXT    NOT NULL,
    end_ip   TEXT    NOT NULL,
    success  INTEGER DEFAULT 0,

    FOREIGN KEY (host) REFERENCES devices(host) ON UPDATE CASCADE
                                                ON DELETE CASCADE
);

-- ── 07_acl.sql ─────────────────────────────────────────────
-- =========================================================
-- ACL
-- success (tất cả bảng): 0=pending write, 1=done, -1=pending delete
-- action_Cfg  (chỉ ACL_DB):  INTEGER bitmask — bit0=description/remark cần push
--                        ≠ cột action TEXT (permit/deny) của bảng rule con
-- Khi sửa rule: mark success=-1 → insert rule mới success=0 (không ghi đè)
-- Khi sửa acl_name/acl_type: mark toàn bộ ACL + rules success=-1, insert mới
-- =========================================================

-- Bảng cha lưu thông tin ACL
CREATE TABLE ACL_DB (
    Acl_id       INTEGER PRIMARY KEY AUTOINCREMENT,
    acl_name     TEXT NOT NULL,           -- tên ACL, ví dụ: SACL_IB / OUTSIDE-FILTER
    acl_type     TEXT NOT NULL,           -- standard / extended / dynamic / reflexive / mac
    host         TEXT NOT NULL,
    description  TEXT,                    -- remark, có thể ghi đè → dùng action_Cfg bitmask
    success      INTEGER DEFAULT 0,       -- 0=pending write | 1=done | -1=pending delete
    action_Cfg   INTEGER DEFAULT 1,       -- bitmask: bit0=description (remark) — ghi đè được

    FOREIGN KEY (host) REFERENCES devices(host) ON DELETE CASCADE
);

-- ─── STANDARD ACL ────────────────────────────────────────
-- Sửa rule → mark success=-1, insert lại (không ghi đè trực tiếp)
CREATE TABLE standard_acl_rules (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    acl_id      INTEGER NOT NULL,
    sequence    INTEGER,
    action      TEXT NOT NULL,            -- permit / deny  (≠ action_Cfg INTEGER của ACL_DB)
    source      TEXT NOT NULL,            -- ví dụ: 192.168.1.0
    wildcard    TEXT,                     -- ví dụ: 0.0.0.255
    success     INTEGER DEFAULT 0,        -- 0=pending write | 1=done | -1=pending delete

    FOREIGN KEY (acl_id) REFERENCES ACL_DB(Acl_id) ON DELETE CASCADE
);

-- ─── EXTENDED ACL ────────────────────────────────────────
-- Sửa rule → mark success=-1, insert lại (không ghi đè trực tiếp)
CREATE TABLE extended_acl_rules (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    acl_id          INTEGER NOT NULL,
    sequence        INTEGER,
    action          TEXT NOT NULL,        -- permit / deny  (≠ action_Cfg INTEGER của ACL_DB)
    protocol        TEXT NOT NULL,        -- ip / tcp / udp / icmp ...
    source          TEXT NOT NULL,
    src_wildcard    TEXT,
    src_port        TEXT,
    destination     TEXT NOT NULL,
    dst_wildcard    TEXT,
    dst_port        TEXT,
    success         INTEGER DEFAULT 0,    -- 0=pending write | 1=done | -1=pending delete

    FOREIGN KEY (acl_id) REFERENCES ACL_DB(Acl_id) ON DELETE CASCADE
);

-- ─── DYNAMIC ACL ─────────────────────────────────────────
CREATE TABLE dynamic_acl_rules (
    id               INTEGER PRIMARY KEY AUTOINCREMENT,
    acl_id           INTEGER NOT NULL,
    sequence         INTEGER,
    action           TEXT NOT NULL,       -- permit / deny  (≠ action_Cfg INTEGER của ACL_DB)
    protocol         TEXT NOT NULL,
    source           TEXT NOT NULL,
    src_wildcard     TEXT,
    src_port         TEXT,
    destination      TEXT NOT NULL,
    dst_wildcard     TEXT,
    dst_port         TEXT,
    dynamic_name     TEXT NOT NULL,       -- tên dynamic map
    timeout_seconds  INTEGER DEFAULT 300,
    success          INTEGER DEFAULT 0,   -- 0=pending write | 1=done | -1=pending delete

    FOREIGN KEY (acl_id) REFERENCES ACL_DB(Acl_id) ON DELETE CASCADE
);

-- ─── REFLEXIVE ACL ───────────────────────────────────────
CREATE TABLE reflexive_acl_rules (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    acl_id          INTEGER NOT NULL,
    sequence        INTEGER,
    action          TEXT NOT NULL,        -- permit / deny  (≠ action_Cfg INTEGER của ACL_DB)
    protocol        TEXT NOT NULL,
    source          TEXT NOT NULL,
    src_wildcard    TEXT,
    src_port        TEXT,
    destination     TEXT NOT NULL,
    dst_wildcard    TEXT,
    dst_port        TEXT,
    reflect_name    TEXT,                 -- tên reflect session
    timeout_seconds INTEGER DEFAULT 300,
    success         INTEGER DEFAULT 0,    -- 0=pending write | 1=done | -1=pending delete

    FOREIGN KEY (acl_id) REFERENCES ACL_DB(Acl_id) ON DELETE CASCADE
);

-- ─── MAC ACL ─────────────────────────────────────────────
CREATE TABLE mac_acl_rules (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    acl_id      INTEGER NOT NULL,
    sequence    INTEGER,
    action      TEXT NOT NULL,            -- permit / deny  (≠ action_Cfg INTEGER của ACL_DB)
    src_mac     TEXT NOT NULL,
    src_mask    TEXT,
    dst_mac     TEXT,
    dst_mask    TEXT,
    ethertype   TEXT,
    success     INTEGER DEFAULT 0,        -- 0=pending write | 1=done | -1=pending delete

    FOREIGN KEY (acl_id) REFERENCES ACL_DB(Acl_id) ON DELETE CASCADE
);

-- ── 08_nat_acl.sql ─────────────────────────────────────────────
-- =========================================================
-- NAT ACL
-- success: 0=pending write, 1=done, -1=pending delete
-- action_Cfg (chỉ NAT_ACL_DB): INTEGER bitmask cho option ghi đè
--   bit0=description
-- =========================================================

-- Bảng cha NAT ACL
CREATE TABLE NAT_ACL_DB (
    nat_acl_id      INTEGER PRIMARY KEY AUTOINCREMENT,
    acl_name        TEXT NOT NULL,
    acl_type        TEXT NOT NULL          -- standard / extended
                    CHECK(acl_type IN ('standard','extended')),
    host            TEXT NOT NULL,
    description     TEXT,
    success         INTEGER DEFAULT 0,
    action_Cfg      INTEGER DEFAULT 1,

    CHECK(success IN (-1,0,1)),
    CHECK(action_Cfg >= 0),

    UNIQUE (host, acl_name),

    FOREIGN KEY (host) REFERENCES devices(host) ON DELETE CASCADE
);

-- STANDARD NAT ACL RULES
CREATE TABLE nat_standard_acl_rules (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    nat_acl_id      INTEGER NOT NULL,
    sequence        INTEGER,
    action          TEXT NOT NULL          -- permit / deny
                    CHECK(action IN ('permit','deny')),
    source          TEXT NOT NULL,
    wildcard        TEXT,
    success         INTEGER DEFAULT 0,

    CHECK(success IN (-1,0,1)),
    CHECK(sequence IS NULL OR sequence > 0),
    UNIQUE (nat_acl_id, sequence),

    FOREIGN KEY (nat_acl_id) REFERENCES NAT_ACL_DB(nat_acl_id) ON DELETE CASCADE
);

-- EXTENDED NAT ACL RULES
CREATE TABLE nat_extended_acl_rules (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    nat_acl_id      INTEGER NOT NULL,
    sequence        INTEGER,
    action          TEXT NOT NULL
                    CHECK(action IN ('permit','deny')),
    protocol        TEXT NOT NULL,
    source          TEXT NOT NULL,
    src_wildcard    TEXT,
    src_port        TEXT,
    destination     TEXT NOT NULL,
    dst_wildcard    TEXT,
    dst_port        TEXT,
    success         INTEGER DEFAULT 0,

    CHECK(success IN (-1,0,1)),
    CHECK(sequence IS NULL OR sequence > 0),
    UNIQUE (nat_acl_id, sequence),

    FOREIGN KEY (nat_acl_id) REFERENCES NAT_ACL_DB(nat_acl_id) ON DELETE CASCADE
);

-- ── 09_nat.sql ─────────────────────────────────────────────
-- =========================================================
-- NAT
-- success: 0=pending write, 1=done, -1=pending delete
-- action_Cfg (chỉ NAT_DB): INTEGER bitmask cho option ghi đè
--   bit0=description
-- =========================================================

-- Bảng cha NAT
CREATE TABLE NAT_DB (
    nat_id              INTEGER PRIMARY KEY AUTOINCREMENT,
    nat_name            TEXT NOT NULL,
    nat_type            TEXT NOT NULL      -- static / dynamic / overload / port_forward
                        CHECK(nat_type IN ('static','dynamic','overload','port_forward')),
    host                TEXT NOT NULL,
    description         TEXT,
    success             INTEGER DEFAULT 0,
    action_Cfg          INTEGER DEFAULT 1,

    CHECK(success IN (-1,0,1)),
    CHECK(action_Cfg >= 0),

    UNIQUE (host, nat_name),

    FOREIGN KEY (host) REFERENCES devices(host) ON DELETE CASCADE
);

-- INTERFACES ĐÁNH DẤU NAT INSIDE / OUTSIDE
CREATE TABLE nat_interfaces (
    id                  INTEGER PRIMARY KEY AUTOINCREMENT,
    nat_id              INTEGER NOT NULL,
    interface_name      TEXT NOT NULL,
    nat_role            TEXT NOT NULL      -- inside / outside
                        CHECK(nat_role IN ('inside','outside')),
    success             INTEGER DEFAULT 0,

    CHECK(success IN (-1,0,1)),
    UNIQUE (nat_id, interface_name),

    FOREIGN KEY (nat_id) REFERENCES NAT_DB(nat_id) ON DELETE CASCADE
);

-- NAT POOL
CREATE TABLE nat_pools (
    pool_id             INTEGER PRIMARY KEY AUTOINCREMENT,
    nat_id              INTEGER NOT NULL,
    pool_name           TEXT NOT NULL,
    start_ip            TEXT NOT NULL,
    end_ip              TEXT NOT NULL,
    netmask             TEXT,
    prefix_length       INTEGER,
    success             INTEGER DEFAULT 0,

    CHECK(success IN (-1,0,1)),
    CHECK(netmask IS NOT NULL OR prefix_length IS NOT NULL),
    CHECK(prefix_length IS NULL OR (prefix_length BETWEEN 0 AND 32)),
    UNIQUE (nat_id, pool_name),

    FOREIGN KEY (nat_id) REFERENCES NAT_DB(nat_id) ON DELETE CASCADE
);

-- STATIC NAT / STATIC PAT / PORT FORWARD
CREATE TABLE nat_static_mappings (
    id                  INTEGER PRIMARY KEY AUTOINCREMENT,
    nat_id              INTEGER NOT NULL,
    inside_local_ip     TEXT NOT NULL,
    inside_global_ip    TEXT NOT NULL,
    protocol            TEXT,
    local_port          INTEGER,
    global_port         INTEGER,
    is_extendable       INTEGER DEFAULT 0,
    description         TEXT,
    success             INTEGER DEFAULT 0,

    CHECK(success IN (-1,0,1)),
    CHECK(is_extendable IN (0,1)),
    CHECK(local_port IS NULL OR (local_port BETWEEN 1 AND 65535)),
    CHECK(global_port IS NULL OR (global_port BETWEEN 1 AND 65535)),
    CHECK((local_port IS NULL AND global_port IS NULL) OR (local_port IS NOT NULL AND global_port IS NOT NULL)),

    FOREIGN KEY (nat_id) REFERENCES NAT_DB(nat_id) ON DELETE CASCADE
);

-- DYNAMIC NAT / DYNAMIC PAT THEO POOL
CREATE TABLE nat_dynamic_rules (
    id                  INTEGER PRIMARY KEY AUTOINCREMENT,
    nat_id              INTEGER NOT NULL,
    nat_acl_id          INTEGER NOT NULL,
    pool_id             INTEGER NOT NULL,
    overload            INTEGER DEFAULT 0,
    description         TEXT,
    success             INTEGER DEFAULT 0,

    CHECK(success IN (-1,0,1)),
    CHECK(overload IN (0,1)),
    UNIQUE (nat_id, nat_acl_id, pool_id),

    FOREIGN KEY (nat_id) REFERENCES NAT_DB(nat_id) ON DELETE CASCADE,
    FOREIGN KEY (nat_acl_id) REFERENCES NAT_ACL_DB(nat_acl_id) ON DELETE CASCADE,
    FOREIGN KEY (pool_id) REFERENCES nat_pools(pool_id) ON DELETE CASCADE
);

-- OVERLOAD QUA INTERFACE
CREATE TABLE nat_overload_interface_rules (
    id                  INTEGER PRIMARY KEY AUTOINCREMENT,
    nat_id              INTEGER NOT NULL,
    nat_acl_id          INTEGER NOT NULL,
    outside_interface   TEXT NOT NULL,
    overload            INTEGER DEFAULT 1,
    description         TEXT,
    success             INTEGER DEFAULT 0,

    CHECK(success IN (-1,0,1)),
    CHECK(overload IN (0,1)),
    UNIQUE (nat_id, nat_acl_id, outside_interface),

    FOREIGN KEY (nat_id) REFERENCES NAT_DB(nat_id) ON DELETE CASCADE,
    FOREIGN KEY (nat_acl_id) REFERENCES NAT_ACL_DB(nat_acl_id) ON DELETE CASCADE
);

-- NAT EXEMPT
CREATE TABLE nat_exempt_rules (
    id                  INTEGER PRIMARY KEY AUTOINCREMENT,
    nat_id              INTEGER NOT NULL,
    nat_acl_id          INTEGER NOT NULL,
    description         TEXT,
    success             INTEGER DEFAULT 0,

    CHECK(success IN (-1,0,1)),
    UNIQUE (nat_id, nat_acl_id),

    FOREIGN KEY (nat_id) REFERENCES NAT_DB(nat_id) ON DELETE CASCADE,
    FOREIGN KEY (nat_acl_id) REFERENCES NAT_ACL_DB(nat_acl_id) ON DELETE CASCADE
);
