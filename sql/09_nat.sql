-- =========================================================
-- NAT
-- =========================================================

-- Bảng cha NAT
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

-- NAT EXEMPT
CREATE TABLE nat_exempt_rules (
    id                  INTEGER PRIMARY KEY AUTOINCREMENT,
    nat_id              INTEGER NOT NULL,
    nat_acl_id          INTEGER NOT NULL,
    description         TEXT,

    FOREIGN KEY (nat_id) REFERENCES NAT_DB(nat_id) ON DELETE CASCADE,
    FOREIGN KEY (nat_acl_id) REFERENCES NAT_ACL_DB(nat_acl_id) ON DELETE CASCADE
);
