-- ========================================================== 
-- File: 09_nat.sql 
-- ========================================================== 
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
 
 


