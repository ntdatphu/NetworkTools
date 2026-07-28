-- 1. HỆ THỐNG THIẾT BỊ CỐT LÕI (CORE DEVICES)
-- ==========================================================
PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;

CREATE TABLE t01_devices (
    host        TEXT PRIMARY KEY,
    device_name TEXT,
    method      TEXT,
    portnumber  INTEGER,
    username    TEXT,
    password    TEXT,
    os          TEXT,
    role        TEXT, -- rou sw2 sw3
    device_type TEXT DEFAULT 'unknown',
    success     INTEGER DEFAULT 0,
    dev         INTEGER DEFAULT 0
);
-- ==========================================================
-- ==========================================================
-- SSH ALGORITHM OVERRIDE
-- Opt-in compatibility settings for one legacy device.
-- ==========================================================
CREATE TABLE IF NOT EXISTS t01_ssh_algo (
    host                 TEXT PRIMARY KEY,
    kex_algorithms       TEXT,
    host_key_algorithms  TEXT,
    ciphers              TEXT,
    macs                 TEXT,
    note                 TEXT,
    FOREIGN KEY (host) REFERENCES t01_devices(host)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);
