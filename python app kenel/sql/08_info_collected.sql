-- ========================================================== 
-- File: 08_info_device.sql 
-- ========================================================== 
-- ============================================================
-- 8. DỮ LIỆU THU THẬP TỪ THIẾT BỊ (INFO / COLLECTED DATA)
-- ============================================================
-- Các bảng này là READ-ONLY từ góc độ config: 
-- chỉ ghi bởi collector, không có cột success/action_Cfg.
-- ============================================================

-- 8a. Routing Table (show ip route)
CREATE TABLE IF NOT EXISTS info_routing_table (
    id                    INTEGER PRIMARY KEY AUTOINCREMENT,
    host                  TEXT    NOT NULL,
    vrf_name              TEXT    NOT NULL DEFAULT 'default',
    protocol_code         TEXT    NOT NULL,           -- ký hiệu: C, S, O, D, B...
    protocol_name         TEXT,                       -- 'connected','static','ospf','eigrp','bgp'
    destination           TEXT    NOT NULL,           -- VD: 192.168.1.0
    prefix_length         INTEGER NOT NULL CHECK(prefix_length BETWEEN 0 AND 128),
    administrative_distance INTEGER,
    metric                INTEGER,
    next_hop              TEXT,                       -- NULL nếu connected
    route_age             TEXT,                       -- VD: '00:05:12', '2w3d'
    exit_interface        TEXT,
    is_best               INTEGER NOT NULL DEFAULT 1 CHECK(is_best IN (0,1)), -- '*>' trong BGP/EIGRP
    collected_at          TEXT    NOT NULL DEFAULT (datetime('now')),
    raw_line              TEXT,
    FOREIGN KEY (host) REFERENCES devices(host) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS ix_irt_host       ON info_routing_table(host);
CREATE INDEX IF NOT EXISTS ix_irt_collected  ON info_routing_table(collected_at);
CREATE INDEX IF NOT EXISTS ix_irt_dest       ON info_routing_table(destination, prefix_length);