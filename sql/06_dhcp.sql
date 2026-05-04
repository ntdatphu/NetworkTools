-- =========================================================
-- DHCP
-- =========================================================

CREATE TABLE dhcp_pool (
    dhcp_id    INTEGER PRIMARY KEY AUTOINCREMENT,
    host       TEXT    NOT NULL,
    pool       TEXT    NOT NULL,
    network    TEXT    NOT NULL,
    subnetmask TEXT    NOT NULL,
    defaut     TEXT,
    dns        TEXT,

    FOREIGN KEY (host) REFERENCES devices(host) ON UPDATE CASCADE
                                                ON DELETE CASCADE
);

CREATE TABLE excluded_address (
    ex_id    INTEGER PRIMARY KEY AUTOINCREMENT,
    host     TEXT    NOT NULL,
    start_ip TEXT    NOT NULL,
    end_ip   TEXT    NOT NULL,

    FOREIGN KEY (host) REFERENCES devices(host) ON UPDATE CASCADE
                                                ON DELETE CASCADE
);
