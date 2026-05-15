-- ========================================================== 
-- File: 08_nat_acl.sql 
-- ========================================================== 
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
 
 
