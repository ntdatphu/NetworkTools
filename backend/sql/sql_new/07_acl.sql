-- ========================================================== 
-- File: 07_acl.sql 
-- ========================================================== 
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
 
 
