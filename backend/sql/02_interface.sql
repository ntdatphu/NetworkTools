-- =========================================================
-- INTERFACE
-- =========================================================

CREATE TABLE interface_name (
    iface_id        INTEGER PRIMARY KEY AUTOINCREMENT,
    host            TEXT    NOT NULL,
    interface_name  TEXT    NOT NULL,     -- ví dụ: GigabitEthernet0/0, FastEthernet0/1
    ip_address      TEXT,                 -- ví dụ: 192.168.1.1
    subnet_mask     TEXT,                 -- ví dụ: 255.255.255.0
    description     TEXT,
    shutdown        INTEGER DEFAULT 0,    -- 0 = no shutdown, 1 = shutdown
    success         INTEGER DEFAULT 0,

    FOREIGN KEY (host) REFERENCES devices(host) ON UPDATE CASCADE
                                                ON DELETE CASCADE
);
