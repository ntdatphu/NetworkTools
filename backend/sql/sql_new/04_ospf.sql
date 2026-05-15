-- ========================================================== 
-- File: 04_ospf.sql 
-- ========================================================== 
PRAGMA foreign_keys = ON;

-- =========================================================
-- OSPF - SCHEMA ĐẦY ĐỦ
-- Thay thế và mở rộng bảng ospf_processes, ospf_networks
-- trong data.sql để hỗ trợ toàn bộ tính năng OSPF
-- =========================================================

-- =========================================================
-- 1. TIẾN TRÌNH OSPF (ospf_processes)
--    Mở rộng bảng gốc: thêm reference_bandwidth,
--    passive_default, default_originate, default_originate_always
-- =========================================================
CREATE TABLE IF NOT EXISTS ospf_processes (
    ospf_id                  INTEGER PRIMARY KEY AUTOINCREMENT,
    host                     TEXT    NOT NULL,
    process_id               INTEGER NOT NULL,   -- router ospf <process_id>
    router_id                TEXT,               -- router-id x.x.x.x
    reference_bandwidth      INTEGER,            -- auto-cost reference-bandwidth <Mbps>
    passive_default          INTEGER DEFAULT 0,  -- 1 = passive-interface default
    default_originate        INTEGER DEFAULT 0,  -- 1 = default-information originate
    default_originate_always INTEGER DEFAULT 0,  -- 1 = thêm keyword always
    success                  INTEGER DEFAULT 0,

    UNIQUE (host, process_id),
    FOREIGN KEY (host) REFERENCES devices(host) ON DELETE CASCADE
);

-- =========================================================
-- 2. QUẢNG BÁ MẠNG (ospf_networks)
--    Giữ nguyên cấu trúc gốc, thêm UNIQUE constraint
-- =========================================================
CREATE TABLE IF NOT EXISTS ospf_networks (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    ospf_id     INTEGER NOT NULL,
    network     TEXT    NOT NULL,   -- 10.0.0.0
    wildcard    TEXT    NOT NULL,   -- 0.255.255.255
    area        INTEGER NOT NULL,   -- 0 / 10 / 67 ...
    success     INTEGER DEFAULT 0,

    UNIQUE (ospf_id, network, wildcard, area),
    FOREIGN KEY (ospf_id) REFERENCES ospf_processes(ospf_id) ON DELETE CASCADE
);

-- =========================================================
-- 3. ADMINISTRATIVE DISTANCE (ospf_distance)
--    Tách riêng vì OSPF cho phép đặt AD độc lập cho từng loại
--    distance ospf external <x> intra-area <y> inter-area <z>
-- =========================================================
CREATE TABLE IF NOT EXISTS ospf_distance (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    ospf_id     INTEGER NOT NULL UNIQUE,
    external    INTEGER,    -- AD cho external routes   (mặc định 110)
    intra_area  INTEGER,    -- AD cho intra-area routes (mặc định 110)
    inter_area  INTEGER,    -- AD cho inter-area routes (mặc định 110)
    success     INTEGER DEFAULT 0,

    FOREIGN KEY (ospf_id) REFERENCES ospf_processes(ospf_id) ON DELETE CASCADE
);

-- =========================================================
-- 4. CẤU HÌNH AREA (ospf_areas)
--    area <id> stub / nssa / normal + no-summary + authentication
-- =========================================================
CREATE TABLE IF NOT EXISTS ospf_areas (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    ospf_id         INTEGER NOT NULL,
    area_id         INTEGER NOT NULL,   -- 0, 10, 20, 67 ...
    area_type       TEXT    DEFAULT 'normal'
                    CHECK(area_type IN ('normal','stub','nssa')),
    no_summary      INTEGER DEFAULT 0,  -- 1 = no-summary (stub totally / nssa totally)
    authentication  TEXT                -- NULL / 'plain' / 'message-digest'
                    CHECK(authentication IN (NULL,'plain','message-digest')),
    success         INTEGER DEFAULT 0,

    UNIQUE (ospf_id, area_id),
    FOREIGN KEY (ospf_id) REFERENCES ospf_processes(ospf_id) ON DELETE CASCADE
);

-- =========================================================
-- 5. RANGE SUMMARY THEO AREA (ospf_area_ranges)
--    area <id> range <ip> <mask>
-- =========================================================
CREATE TABLE IF NOT EXISTS ospf_area_ranges (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    area_db_id  INTEGER NOT NULL,   -- FK → ospf_areas.id
    ip          TEXT    NOT NULL,   -- 172.16.0.0
    mask        TEXT    NOT NULL,   -- 255.255.0.0
    advertise   INTEGER DEFAULT 1,  -- 1 = advertise, 0 = not-advertise
    cost        INTEGER,            -- tùy chọn: override cost
    success     INTEGER DEFAULT 0,

    UNIQUE (area_db_id, ip, mask),
    FOREIGN KEY (area_db_id) REFERENCES ospf_areas(id) ON DELETE CASCADE
);

-- =========================================================
-- 6. REDISTRIBUTE (ospf_redistribute)
--    redistribute static/connected/eigrp/bgp subnets ...
-- =========================================================
CREATE TABLE IF NOT EXISTS ospf_redistribute (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    ospf_id     INTEGER NOT NULL,
    protocol    TEXT    NOT NULL    -- static / connected / eigrp / bgp / rip / isis
                CHECK(protocol IN ('static','connected','eigrp','bgp','rip','isis')),
    process_id  INTEGER,            -- bắt buộc với eigrp / bgp
    subnets     INTEGER DEFAULT 1,  -- 1 = thêm keyword subnets
    metric      INTEGER,            -- metric tuỳ chọn
    metric_type INTEGER             -- 1 hoặc 2 (E1 / E2)
                CHECK(metric_type IN (NULL,1,2)),
    route_map   TEXT,               -- tên route-map nếu có
    success     INTEGER DEFAULT 0,

    UNIQUE (ospf_id, protocol, process_id),
    FOREIGN KEY (ospf_id) REFERENCES ospf_processes(ospf_id) ON DELETE CASCADE
);

-- =========================================================
-- 7. PASSIVE INTERFACE TỪNG CỔNG (ospf_passive_interfaces)
--    passive-interface <name>  /  no passive-interface <name>
--    (khi passive_default = 1, cổng nào passive = 0 nghĩa là no passive-interface)
-- =========================================================
CREATE TABLE IF NOT EXISTS ospf_passive_interfaces (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    ospf_id         INTEGER NOT NULL,
    interface_name  TEXT    NOT NULL,   -- GigabitEthernet0/3
    passive         INTEGER DEFAULT 1,  -- 1 = passive, 0 = no passive (dùng khi passive_default = 1)
    success         INTEGER DEFAULT 0,

    UNIQUE (ospf_id, interface_name),
    FOREIGN KEY (ospf_id) REFERENCES ospf_processes(ospf_id) ON DELETE CASCADE
);

-- =========================================================
-- 8. TUNING OSPF (ospf_tuning)
--    maximum-paths, max-lsa, timers throttle spf/lsa
-- =========================================================
CREATE TABLE IF NOT EXISTS ospf_tuning (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    ospf_id         INTEGER NOT NULL UNIQUE,

    -- maximum-paths <1-32>
    maximum_paths   INTEGER,

    -- max-lsa <number>
    max_lsa         INTEGER,

    -- timers throttle spf <delay> <min-delay> <max-delay>  (đơn vị: ms)
    spf_delay       INTEGER,
    spf_min_delay   INTEGER,
    spf_max_delay   INTEGER,

    -- timers throttle lsa all <delay> <min-delay> <max-delay>  (đơn vị: ms)
    lsa_delay       INTEGER,
    lsa_min_delay   INTEGER,
    lsa_max_delay   INTEGER,

    success         INTEGER DEFAULT 0,

    FOREIGN KEY (ospf_id) REFERENCES ospf_processes(ospf_id) ON DELETE CASCADE
);

-- =========================================================
-- 9. CÀI ĐẶT OSPF TRÊN INTERFACE (ospf_interface_settings)
--    ip ospf <process-id> area <area>
--    ip ospf cost / hello-interval / dead-interval
--    ip ospf mtu-ignore / network / bfd
--    ip ospf authentication message-digest
-- =========================================================
CREATE TABLE IF NOT EXISTS ospf_interface_settings (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    ospf_id         INTEGER NOT NULL,   -- FK → ospf_processes
    interface_name  TEXT    NOT NULL,   -- GigabitEthernet0/1
    area            INTEGER NOT NULL,   -- area được gán

    -- Tuning trên interface
    cost            INTEGER,            -- ip ospf cost <1-65535>
    hello_interval  INTEGER,            -- ip ospf hello-interval <giây>
    dead_interval   INTEGER,            -- ip ospf dead-interval <giây> (tuỳ chọn)
    mtu_ignore      INTEGER DEFAULT 0,  -- 1 = ip ospf mtu-ignore
    bfd             INTEGER DEFAULT 0,  -- 1 = ip ospf bfd

    -- Loại mạng trên interface
    network_type    TEXT                -- broadcast / non-broadcast / point-to-point / point-to-multipoint
                    CHECK(network_type IN (NULL,'broadcast','non-broadcast','point-to-point','point-to-multipoint')),

    -- Xác thực trên interface (ghi đè xác thực cấp area)
    auth_type       TEXT                -- NULL / 'plain' / 'message-digest'
                    CHECK(auth_type IN (NULL,'plain','message-digest')),

    success         INTEGER DEFAULT 0,

    UNIQUE (ospf_id, interface_name, area),
    FOREIGN KEY (ospf_id) REFERENCES ospf_processes(ospf_id) ON DELETE CASCADE
);
 
 
