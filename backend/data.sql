PRAGMA foreign_keys = ON;

-- Bảng devices giữ nguyên như hiện tại
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

-- =========================================================
-- OSPF
-- =========================================================

-- 1 process OSPF
CREATE TABLE ospf_processes (
    ospf_id         INTEGER PRIMARY KEY AUTOINCREMENT,
    host            TEXT NOT NULL,
    process_id      INTEGER NOT NULL,     -- router ospf 1
    router_id       TEXT,                 -- ví dụ: 1.1.1.1
    ad              INTEGER,              -- distance ospf ...
    default_info    INTEGER DEFAULT 0,    -- checkbox Default
    auto_summary    INTEGER DEFAULT 0,    -- checkbox Auto-Summary (nếu bạn muốn hiện trong UI)
    action          INTEGER DEFAULT 3,    -- bitmask: 2=default_info, 1=auto_summary
    success         INTEGER DEFAULT 0,

    FOREIGN KEY (host) REFERENCES devices(host) ON DELETE CASCADE
);

-- Danh sách network của từng process OSPF
CREATE TABLE ospf_networks (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    ospf_id         INTEGER NOT NULL,
    network         TEXT NOT NULL,        -- ví dụ: 192.168.1.0
    wildcard        TEXT NOT NULL,        -- ví dụ: 0.0.0.255
    area            TEXT NOT NULL,        -- ví dụ: 0 / 1 / 0.0.0.0
    success         INTEGER DEFAULT 0,

    FOREIGN KEY (ospf_id) REFERENCES ospf_processes(ospf_id) ON DELETE CASCADE
);

-- =========================================================
-- EIGRP
-- =========================================================

-- 1 process EIGRP
CREATE TABLE eigrp_processes (
    eigrp_id          INTEGER PRIMARY KEY AUTOINCREMENT,
    host              TEXT NOT NULL,
    as_number         INTEGER NOT NULL,    -- router eigrp 100
    router_id         TEXT,                -- nếu cần lưu thêm cho UI
    auto_summary      INTEGER DEFAULT 0,   -- no auto-summary / auto-summary
    passive_default   INTEGER DEFAULT 0,   -- nếu muốn mở rộng UI sau này
    metric_weights    TEXT DEFAULT "0 1 0 1 0 0",                 -- nếu muốn lưu trọng số metric
    action            INTEGER DEFAULT 15,
    success           INTEGER DEFAULT 0,

    FOREIGN KEY (host) REFERENCES devices(host) ON DELETE CASCADE
);

-- Danh sách network của từng process EIGRP
CREATE TABLE eigrp_networks (
    id                INTEGER PRIMARY KEY AUTOINCREMENT,
    eigrp_id          INTEGER NOT NULL,
    network           TEXT NOT NULL,       -- ví dụ: 10.0.0.0
    wildcard          TEXT,                -- ví dụ: 0.0.0.255
    success           INTEGER DEFAULT 0,

    FOREIGN KEY (eigrp_id) REFERENCES eigrp_processes(eigrp_id) ON DELETE CASCADE
);

-- Bảng cha lưu thông tin ACL
CREATE TABLE ACL_DB (
    Acl_id       INTEGER PRIMARY KEY AUTOINCREMENT,
    acl_name     TEXT NOT NULL,           -- tên ACL, ví dụ: SACL_IB / OUTSIDE-FILTER
    acl_type     TEXT NOT NULL,           -- standard / extended / dynamic / reflexive / mac
    host         TEXT NOT NULL,           -- liên kết đến thiết bị
    description  TEXT,

    FOREIGN KEY (host) REFERENCES devices(host) ON DELETE CASCADE
);

-- STANDARD ACL
CREATE TABLE standard_acl_rules (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    acl_id      INTEGER NOT NULL,
    sequence    INTEGER,
    action      TEXT NOT NULL,            -- permit / deny
    source      TEXT NOT NULL,            -- ví dụ: 192.168.1.0
    wildcard    TEXT,                     -- ví dụ: 0.0.0.255

    FOREIGN KEY (acl_id) REFERENCES ACL_DB(Acl_id) ON DELETE CASCADE
);

-- EXTENDED ACL
CREATE TABLE extended_acl_rules (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    acl_id          INTEGER NOT NULL,
    sequence        INTEGER,

    action          TEXT NOT NULL,        -- permit / deny
    protocol        TEXT NOT NULL,        -- ip / tcp / udp / icmp ...

    source          TEXT NOT NULL,
    src_wildcard    TEXT,
    src_port        TEXT,

    destination     TEXT NOT NULL,
    dst_wildcard    TEXT,
    dst_port        TEXT,

    FOREIGN KEY (acl_id) REFERENCES ACL_DB(Acl_id) ON DELETE CASCADE
);

-- DYNAMIC ACL
CREATE TABLE dynamic_acl_rules (
    id               INTEGER PRIMARY KEY AUTOINCREMENT,
    acl_id           INTEGER NOT NULL,
    sequence         INTEGER,

    action           TEXT NOT NULL,
    protocol         TEXT NOT NULL,

    source           TEXT NOT NULL,
    src_wildcard     TEXT,
    src_port         TEXT,

    destination      TEXT NOT NULL,
    dst_wildcard     TEXT,
    dst_port         TEXT,

    dynamic_name     TEXT NOT NULL,       -- tên dynamic ACL
    timeout_seconds  INTEGER DEFAULT 300,

    FOREIGN KEY (acl_id) REFERENCES ACL_DB(Acl_id) ON DELETE CASCADE
);

-- REFLEXIVE ACL
CREATE TABLE reflexive_acl_rules (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    acl_id          INTEGER NOT NULL,
    sequence        INTEGER,

    action          TEXT NOT NULL,
    protocol        TEXT NOT NULL,

    source          TEXT NOT NULL,
    src_wildcard    TEXT,
    src_port        TEXT,

    destination     TEXT NOT NULL,
    dst_wildcard    TEXT,
    dst_port        TEXT,

    reflect_name    TEXT,                 -- tên reflect
    timeout_seconds INTEGER DEFAULT 300,

    FOREIGN KEY (acl_id) REFERENCES ACL_DB(Acl_id) ON DELETE CASCADE
);

-- MAC ACL
CREATE TABLE mac_acl_rules (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    acl_id      INTEGER NOT NULL,
    sequence    INTEGER,

    action      TEXT NOT NULL,
    src_mac     TEXT NOT NULL,
    src_mask    TEXT,
    dst_mac     TEXT,
    dst_mask    TEXT,
    ethertype   TEXT,

    FOREIGN KEY (acl_id) REFERENCES ACL_DB(Acl_id) ON DELETE CASCADE
);

-- =========================================================
-- NAT ACL - BẢNG CHA
-- =========================================================
CREATE TABLE NAT_ACL_DB (
    nat_acl_id      INTEGER PRIMARY KEY AUTOINCREMENT,
    acl_name        TEXT NOT NULL,
    acl_type        TEXT NOT NULL,         -- standard / extended
    host            TEXT NOT NULL,
    description     TEXT,

    FOREIGN KEY (host) REFERENCES devices(host) ON DELETE CASCADE
);

-- STANDARD NAT ACL RULES
CREATE TABLE nat_standard_acl_rules (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    nat_acl_id      INTEGER NOT NULL,
    sequence        INTEGER,
    action          TEXT NOT NULL,         -- permit / deny
    source          TEXT NOT NULL,
    wildcard        TEXT,

    FOREIGN KEY (nat_acl_id) REFERENCES NAT_ACL_DB(nat_acl_id) ON DELETE CASCADE
);

-- EXTENDED NAT ACL RULES
CREATE TABLE nat_extended_acl_rules (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    nat_acl_id      INTEGER NOT NULL,
    sequence        INTEGER,
    action          TEXT NOT NULL,
    protocol        TEXT NOT NULL,
    source          TEXT NOT NULL,
    src_wildcard    TEXT,
    src_port        TEXT,
    destination     TEXT NOT NULL,
    dst_wildcard    TEXT,
    dst_port        TEXT,

    FOREIGN KEY (nat_acl_id) REFERENCES NAT_ACL_DB(nat_acl_id) ON DELETE CASCADE
);

-- =========================================================
-- NAT - BẢNG CHA
-- =========================================================
CREATE TABLE NAT_DB (
    nat_id              INTEGER PRIMARY KEY AUTOINCREMENT,
    nat_name            TEXT NOT NULL,
    nat_type            TEXT NOT NULL,     -- static / dynamic / overload / port_forward
    host                TEXT NOT NULL,
    description         TEXT,

    FOREIGN KEY (host) REFERENCES devices(host) ON DELETE CASCADE
);

-- INTERFACES ĐÁNH DẤU NAT INSIDE / OUTSIDE
CREATE TABLE nat_interfaces (
    id                  INTEGER PRIMARY KEY AUTOINCREMENT,
    nat_id              INTEGER NOT NULL,
    interface_name      TEXT NOT NULL,
    nat_role            TEXT NOT NULL,     -- inside / outside

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

    FOREIGN KEY (nat_id) REFERENCES NAT_DB(nat_id) ON DELETE CASCADE,
    FOREIGN KEY (nat_acl_id) REFERENCES NAT_ACL_DB(nat_acl_id) ON DELETE CASCADE
);

-- OPTIONAL: NAT EXEMPT
CREATE TABLE nat_exempt_rules (
    id                  INTEGER PRIMARY KEY AUTOINCREMENT,
    nat_id              INTEGER NOT NULL,
    nat_acl_id          INTEGER NOT NULL,
    description         TEXT,

    FOREIGN KEY (nat_id) REFERENCES NAT_DB(nat_id) ON DELETE CASCADE,
    FOREIGN KEY (nat_acl_id) REFERENCES NAT_ACL_DB(nat_acl_id) ON DELETE CASCADE
);

CREATE TABLE dhcp_pool (
    dhcp_id    INTEGER PRIMARY KEY AUTOINCREMENT,
    host       TEXT    NOT NULL,
    pool       TEXT    NOT NULL,
    network    TEXT    NOT NULL,
    subnetmask TEXT    NOT NULL,
    defaut     TEXT,
    dns        TEXT,
    FOREIGN KEY (
        host
    )
    REFERENCES devices (host) ON UPDATE CASCADE
                              ON DELETE CASCADE
);

CREATE TABLE excluded_address (
    ex_id    INTEGER PRIMARY KEY AUTOINCREMENT,
    host     TEXT    NOT NULL,
    start_ip TEXT    NOT NULL,
    end_ip   TEXT    NOT NULL,
    FOREIGN KEY (
        host
    )
    REFERENCES devices (host) ON UPDATE CASCADE
                              ON DELETE CASCADE
);
