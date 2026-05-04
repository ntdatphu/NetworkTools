-- =========================================================
-- NAT ACL
-- =========================================================

-- Bảng cha NAT ACL
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
