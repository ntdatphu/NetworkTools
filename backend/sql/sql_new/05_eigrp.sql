-- ========================================================== 
-- File: 05_eigrp.sql 
-- ========================================================== 
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
 
 
