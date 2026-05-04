-- =========================================================
-- DHCP
-- success: 0=pending write, 1=done, -1=pending delete
-- action_Cfg (chỉ dhcp_pool): TEXT nhị phân 3 bit cho option ghi đè
--  bit2=defaut(default-router), bit1=dns, bit0=lease
-- =========================================================

CREATE TABLE dhcp_pool (
    dhcp_id    INTEGER PRIMARY KEY AUTOINCREMENT,
    host       TEXT    NOT NULL,
    pool       TEXT    NOT NULL,
    network    TEXT    NOT NULL,
    subnetmask TEXT    NOT NULL,
    defaut     TEXT,
    dns        TEXT,
    lease      TEXT DEFAULT '1',  -- mặc định 1 ngày cấu trúc D HH MM SS
    success    INTEGER DEFAULT 0,
    action_Cfg TEXT DEFAULT '111',  -- dạng nhị phân: bit2..bit0

    FOREIGN KEY (host) REFERENCES devices(host) ON UPDATE CASCADE
                                                ON DELETE CASCADE
);

CREATE TABLE excluded_address (
    ex_id    INTEGER PRIMARY KEY AUTOINCREMENT,
    host     TEXT    NOT NULL,
    start_ip TEXT    NOT NULL,
    end_ip   TEXT    NOT NULL,
    success  INTEGER DEFAULT 0,

    FOREIGN KEY (host) REFERENCES devices(host) ON UPDATE CASCADE
                                                ON DELETE CASCADE
);
