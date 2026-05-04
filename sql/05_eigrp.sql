-- =========================================================
-- EIGRP
-- =========================================================

-- 1 process EIGRP
CREATE TABLE eigrp_processes (
    eigrp_id          INTEGER PRIMARY KEY AUTOINCREMENT,
    host              TEXT NOT NULL,
    as_number         INTEGER NOT NULL,    -- router eigrp 100
    router_id         TEXT,
    auto_summary      INTEGER DEFAULT 0,   -- no auto-summary / auto-summary
    passive_default   INTEGER DEFAULT 0,
    metric_weights    TEXT DEFAULT "0 1 0 1 0 0",
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
    interface_name    TEXT,                -- ví dụ: GigabitEthernet0/0
    success           INTEGER DEFAULT 0,

    FOREIGN KEY (eigrp_id) REFERENCES eigrp_processes(eigrp_id) ON DELETE CASCADE
);
