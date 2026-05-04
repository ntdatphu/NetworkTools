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
    auto_summary    INTEGER DEFAULT 0,    -- checkbox Auto-Summary
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
