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
