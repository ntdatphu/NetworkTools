-- ============================================================
-- INFO COLLECTED SCHEMA
-- ============================================================
-- File được tạo tự động bởi build_sql.sh.
--
-- Không chỉnh sửa trực tiếp file này.
-- Hãy chỉnh sửa các file nguồn trong:
--   info_collected/
--
-- Thời điểm tạo:
--   2026-07-12 14:25:11 +0700
-- ============================================================

PRAGMA foreign_keys = ON;


-- ============================================================
-- BEGIN FILE: info_collected/08_info_routing_table.sql
-- ============================================================

-- ============================================================
-- 8. DỮ LIỆU THU THẬP TỪ THIẾT BỊ
--    INFO / COLLECTED DATA
-- ============================================================
-- Các bảng trong nhóm t08_info_* là dữ liệu READ-ONLY
-- từ góc độ cấu hình.
--
-- Chỉ collector được phép:
--   - INSERT dữ liệu thu thập từ thiết bị
--   - UPDATE dữ liệu trạng thái
--   - DELETE snapshot cũ
--
-- Không sử dụng các cột:
--   - success
--   - action_Cfg
--
-- Vì đây không phải dữ liệu cấu hình cần push.
-- ============================================================


-- ============================================================
-- 8a. ROUTING TABLE
-- Nguồn dữ liệu:
--   show ip route
--   show ip route vrf <vrf-name>
-- ============================================================

CREATE TABLE IF NOT EXISTS t08_info_routing_table (
    id                      INTEGER PRIMARY KEY AUTOINCREMENT,

    host                    TEXT    NOT NULL,

    -- Tên VRF.
    -- Route thuộc bảng định tuyến global sử dụng giá trị 'default'.
    vrf_name                TEXT    NOT NULL DEFAULT 'default',

    -- Mã giao thức xuất hiện trong output Cisco:
    -- C, L, S, O, O IA, D, D EX, B, R...
    protocol_code           TEXT    NOT NULL,

    -- Tên giao thức đã chuẩn hóa:
    -- connected, local, static, ospf, eigrp, bgp, rip...
    protocol_name           TEXT,

    -- Địa chỉ mạng đích.
    destination             TEXT    NOT NULL,

    -- Hỗ trợ cả IPv4 và IPv6.
    prefix_length           INTEGER NOT NULL
                                      CHECK(prefix_length BETWEEN 0 AND 128),

    administrative_distance INTEGER,
    metric                  INTEGER,

    -- NULL đối với route connected/local hoặc route không có next-hop.
    next_hop                TEXT,

    -- Ví dụ:
    -- 00:05:12
    -- 2w3d
    -- 01:20:40
    route_age               TEXT,

    exit_interface          TEXT,

    -- Cho biết tuyến đường được chọn là tuyến tốt nhất.
    is_best                 INTEGER NOT NULL DEFAULT 1
                                      CHECK(is_best IN (0,1)),

    -- Thời điểm collector thu thập bản ghi.
    collected_at            TEXT    NOT NULL
                                      DEFAULT (datetime('now')),

    -- Lưu dòng output gốc để debug parser.
    raw_line                TEXT,

    FOREIGN KEY (host)
        REFERENCES t01_devices(host)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS ix_t08_routing_host
    ON t08_info_routing_table(host);

CREATE INDEX IF NOT EXISTS ix_t08_routing_host_vrf
    ON t08_info_routing_table(host, vrf_name);

CREATE INDEX IF NOT EXISTS ix_t08_routing_destination
    ON t08_info_routing_table(destination, prefix_length);

CREATE INDEX IF NOT EXISTS ix_t08_routing_protocol
    ON t08_info_routing_table(host, protocol_name);

CREATE INDEX IF NOT EXISTS ix_t08_routing_collected_at
    ON t08_info_routing_table(collected_at);



-- ============================================================
-- END FILE: info_collected/08_info_routing_table.sql
-- ============================================================


-- ============================================================
-- BEGIN FILE: info_collected/09_info_dhcp.sql
-- ============================================================

-- ============================================================
-- 9. THÔNG TIN DHCP THU THẬP TỪ THIẾT BỊ
--    DHCP INFO / COLLECTED DATA
-- ============================================================
-- Các bảng này chỉ được ghi bởi collector.
-- Không chứa success hoặc action_Cfg.
-- ============================================================


-- ============================================================
-- 9a. DHCP POOL STATUS
-- Nguồn dữ liệu:
--   show ip dhcp pool
-- ============================================================

CREATE TABLE IF NOT EXISTS t09_info_dhcp_pool (
    id                    INTEGER PRIMARY KEY AUTOINCREMENT,

    host                  TEXT    NOT NULL,

    vrf_name              TEXT    NOT NULL DEFAULT 'default',

    -- Tên DHCP pool trên thiết bị.
    pool_name             TEXT    NOT NULL,

    -- Network được cấu hình trong pool.
    network               TEXT,

    subnet_mask           TEXT,

    prefix_length         INTEGER
                                  CHECK(
                                      prefix_length IS NULL
                                      OR prefix_length BETWEEN 0 AND 128
                                  ),

    -- Phạm vi IP thực tế của pool.
    first_address         TEXT,
    last_address          TEXT,

    -- Current index trong output show ip dhcp pool.
    current_index         TEXT,

    total_addresses       INTEGER NOT NULL DEFAULT 0
                                  CHECK(total_addresses >= 0),

    leased_addresses      INTEGER NOT NULL DEFAULT 0
                                  CHECK(leased_addresses >= 0),

    excluded_addresses    INTEGER NOT NULL DEFAULT 0
                                  CHECK(excluded_addresses >= 0),

    available_addresses   INTEGER NOT NULL DEFAULT 0
                                  CHECK(available_addresses >= 0),

    utilization_percent   REAL
                                  CHECK(
                                      utilization_percent IS NULL
                                      OR utilization_percent BETWEEN 0 AND 100
                                  ),

    -- Utilization mark high/low của Cisco DHCP pool.
    high_utilization      INTEGER
                                  CHECK(
                                      high_utilization IS NULL
                                      OR high_utilization BETWEEN 0 AND 100
                                  ),

    low_utilization       INTEGER
                                  CHECK(
                                      low_utilization IS NULL
                                      OR low_utilization BETWEEN 0 AND 100
                                  ),

    pending_event         TEXT,

    collected_at          TEXT    NOT NULL
                                  DEFAULT (datetime('now')),

    -- Lưu nguyên output của pool tương ứng nếu cần debug.
    raw_output            TEXT,

    FOREIGN KEY (host)
        REFERENCES t01_devices(host)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS ix_t09_dhcp_pool_host
    ON t09_info_dhcp_pool(host);

CREATE INDEX IF NOT EXISTS ix_t09_dhcp_pool_host_name
    ON t09_info_dhcp_pool(host, pool_name);

CREATE INDEX IF NOT EXISTS ix_t09_dhcp_pool_host_vrf
    ON t09_info_dhcp_pool(host, vrf_name);

CREATE INDEX IF NOT EXISTS ix_t09_dhcp_pool_network
    ON t09_info_dhcp_pool(network, prefix_length);

CREATE INDEX IF NOT EXISTS ix_t09_dhcp_pool_collected_at
    ON t09_info_dhcp_pool(collected_at);


-- ============================================================
-- 9b. DHCP BINDING / LEASE
-- Nguồn dữ liệu:
--   show ip dhcp binding
-- ============================================================

CREATE TABLE IF NOT EXISTS t09_info_dhcp_binding (
    id                    INTEGER PRIMARY KEY AUTOINCREMENT,

    host                  TEXT    NOT NULL,

    vrf_name              TEXT    NOT NULL DEFAULT 'default',

    -- Có thể NULL nếu output không xác định trực tiếp pool.
    pool_name             TEXT,

    -- Địa chỉ IP đang được cấp.
    ip_address            TEXT    NOT NULL,

    -- Client identifier của DHCP client.
    client_id             TEXT,

    -- MAC address đã chuẩn hóa nếu parser lấy được.
    hardware_address      TEXT,

    username              TEXT,

    -- Chuỗi thời gian hết hạn theo output thiết bị.
    lease_expiration      TEXT,

    -- Automatic, Manual, Infinite...
    lease_type            TEXT,

    -- Active, Expired, Selecting...
    binding_state         TEXT,

    -- Interface liên quan nếu thiết bị cung cấp.
    interface_name        TEXT,

    collected_at          TEXT    NOT NULL
                                  DEFAULT (datetime('now')),

    -- Dòng output gốc.
    raw_line              TEXT,

    FOREIGN KEY (host)
        REFERENCES t01_devices(host)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS ix_t09_dhcp_binding_host
    ON t09_info_dhcp_binding(host);

CREATE INDEX IF NOT EXISTS ix_t09_dhcp_binding_ip
    ON t09_info_dhcp_binding(host, ip_address);

CREATE INDEX IF NOT EXISTS ix_t09_dhcp_binding_client
    ON t09_info_dhcp_binding(host, client_id);

CREATE INDEX IF NOT EXISTS ix_t09_dhcp_binding_mac
    ON t09_info_dhcp_binding(host, hardware_address);

CREATE INDEX IF NOT EXISTS ix_t09_dhcp_binding_pool
    ON t09_info_dhcp_binding(host, pool_name);

CREATE INDEX IF NOT EXISTS ix_t09_dhcp_binding_collected_at
    ON t09_info_dhcp_binding(collected_at);


-- ============================================================
-- 9c. DHCP CONFLICT
-- Nguồn dữ liệu:
--   show ip dhcp conflict
-- ============================================================

CREATE TABLE IF NOT EXISTS t09_info_dhcp_conflict (
    id                    INTEGER PRIMARY KEY AUTOINCREMENT,

    host                  TEXT    NOT NULL,

    vrf_name              TEXT    NOT NULL DEFAULT 'default',

    -- Địa chỉ IP bị phát hiện trùng.
    ip_address            TEXT    NOT NULL,

    -- Ví dụ:
    -- Ping
    -- Gratuitous ARP
    detection_method      TEXT,

    -- Thời điểm phát hiện theo output thiết bị.
    detection_time        TEXT,

    collected_at          TEXT    NOT NULL
                                  DEFAULT (datetime('now')),

    raw_line              TEXT,

    FOREIGN KEY (host)
        REFERENCES t01_devices(host)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS ix_t09_dhcp_conflict_host
    ON t09_info_dhcp_conflict(host);

CREATE INDEX IF NOT EXISTS ix_t09_dhcp_conflict_ip
    ON t09_info_dhcp_conflict(host, ip_address);

CREATE INDEX IF NOT EXISTS ix_t09_dhcp_conflict_vrf
    ON t09_info_dhcp_conflict(host, vrf_name);

CREATE INDEX IF NOT EXISTS ix_t09_dhcp_conflict_collected_at
    ON t09_info_dhcp_conflict(collected_at);


-- ============================================================
-- 9d. DHCP SERVER STATISTICS
-- Nguồn dữ liệu:
--   show ip dhcp server statistics
--
-- Bảng này có thể lưu lịch sử để:
--   - vẽ biểu đồ
--   - theo dõi số gói DHCP
--   - phát hiện DHCP NAK tăng bất thường
-- ============================================================

CREATE TABLE IF NOT EXISTS t09_info_dhcp_server_statistics (
    id                      INTEGER PRIMARY KEY AUTOINCREMENT,

    host                    TEXT    NOT NULL,

    vrf_name                TEXT    NOT NULL DEFAULT 'default',

    memory_usage            INTEGER
                                    CHECK(
                                        memory_usage IS NULL
                                        OR memory_usage >= 0
                                    ),

    address_pools           INTEGER
                                    CHECK(
                                        address_pools IS NULL
                                        OR address_pools >= 0
                                    ),

    database_agents         INTEGER
                                    CHECK(
                                        database_agents IS NULL
                                        OR database_agents >= 0
                                    ),

    automatic_bindings      INTEGER
                                    CHECK(
                                        automatic_bindings IS NULL
                                        OR automatic_bindings >= 0
                                    ),

    manual_bindings         INTEGER
                                    CHECK(
                                        manual_bindings IS NULL
                                        OR manual_bindings >= 0
                                    ),

    expired_bindings        INTEGER
                                    CHECK(
                                        expired_bindings IS NULL
                                        OR expired_bindings >= 0
                                    ),

    malformed_messages      INTEGER
                                    CHECK(
                                        malformed_messages IS NULL
                                        OR malformed_messages >= 0
                                    ),

    dhcp_discover_received  INTEGER NOT NULL DEFAULT 0
                                    CHECK(dhcp_discover_received >= 0),

    dhcp_offer_sent         INTEGER NOT NULL DEFAULT 0
                                    CHECK(dhcp_offer_sent >= 0),

    dhcp_request_received   INTEGER NOT NULL DEFAULT 0
                                    CHECK(dhcp_request_received >= 0),

    dhcp_decline_received   INTEGER NOT NULL DEFAULT 0
                                    CHECK(dhcp_decline_received >= 0),

    dhcp_ack_sent           INTEGER NOT NULL DEFAULT 0
                                    CHECK(dhcp_ack_sent >= 0),

    dhcp_nak_sent           INTEGER NOT NULL DEFAULT 0
                                    CHECK(dhcp_nak_sent >= 0),

    dhcp_release_received   INTEGER NOT NULL DEFAULT 0
                                    CHECK(dhcp_release_received >= 0),

    dhcp_inform_received    INTEGER NOT NULL DEFAULT 0
                                    CHECK(dhcp_inform_received >= 0),

    collected_at            TEXT    NOT NULL
                                    DEFAULT (datetime('now')),

    raw_output              TEXT,

    FOREIGN KEY (host)
        REFERENCES t01_devices(host)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS ix_t09_dhcp_statistics_host
    ON t09_info_dhcp_server_statistics(host);

CREATE INDEX IF NOT EXISTS ix_t09_dhcp_statistics_host_vrf
    ON t09_info_dhcp_server_statistics(host, vrf_name);

CREATE INDEX IF NOT EXISTS ix_t09_dhcp_statistics_collected_at
    ON t09_info_dhcp_server_statistics(collected_at);


-- ============================================================
-- 9e. DHCP DATABASE AGENT
-- Nguồn dữ liệu:
--   show ip dhcp database
--
-- Chỉ có dữ liệu khi thiết bị được cấu hình DHCP database agent.
-- ============================================================

CREATE TABLE IF NOT EXISTS t09_info_dhcp_database (
    id                    INTEGER PRIMARY KEY AUTOINCREMENT,

    host                  TEXT    NOT NULL,

    vrf_name              TEXT    NOT NULL DEFAULT 'default',

    -- Ví dụ:
    -- flash:dhcp.dat
    -- ftp://server/dhcp-db
    -- tftp://server/dhcp-db
    database_url          TEXT,

    write_delay_seconds   INTEGER
                                  CHECK(
                                      write_delay_seconds IS NULL
                                      OR write_delay_seconds >= 0
                                  ),

    timeout_seconds       INTEGER
                                  CHECK(
                                      timeout_seconds IS NULL
                                      OR timeout_seconds >= 0
                                  ),

    last_write_time       TEXT,
    last_read_time        TEXT,

    -- Trạng thái database agent:
    -- OK, Error, Disabled, Pending...
    status                TEXT,

    collected_at          TEXT    NOT NULL
                                  DEFAULT (datetime('now')),

    raw_output            TEXT,

    FOREIGN KEY (host)
        REFERENCES t01_devices(host)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS ix_t09_dhcp_database_host
    ON t09_info_dhcp_database(host);

CREATE INDEX IF NOT EXISTS ix_t09_dhcp_database_host_vrf
    ON t09_info_dhcp_database(host, vrf_name);

CREATE INDEX IF NOT EXISTS ix_t09_dhcp_database_collected_at
    ON t09_info_dhcp_database(collected_at);
-- ============================================================
-- END FILE: info_collected/09_info_dhcp.sql
-- ============================================================


-- ============================================================
-- BEGIN FILE: info_collected/10_info_acl copy.sql
-- ============================================================

-- ============================================================
-- 10. DỮ LIỆU ACL THU THẬP TỪ THIẾT BỊ
--     ACL INFO / COLLECTED DATA
-- ============================================================
-- Nguồn dữ liệu tham khảo:
--   show access-lists
--   show ip access-lists
--   show ipv6 access-list
--   show mac access-list
--   show ip interface
--   show running-config | section access-list
--
-- Các bảng t10_info_* là dữ liệu READ-ONLY từ góc độ cấu hình.
--
-- Chỉ collector được phép:
--   - INSERT dữ liệu lấy từ thiết bị
--   - UPDATE trạng thái hoặc thông tin parser
--   - DELETE snapshot cũ
--
-- Không sử dụng:
--   - success
--   - action_Cfg
--
-- Vì đây là dữ liệu được đọc từ thiết bị, không phải dữ liệu
-- cấu hình chờ push.
-- ============================================================


-- ============================================================
-- 10a. ACL DATABASE
-- Lưu thông tin tổng quát của từng ACL được phát hiện trên thiết bị.
-- ============================================================

CREATE TABLE IF NOT EXISTS t10_info_acl_db (
    info_acl_id     INTEGER PRIMARY KEY AUTOINCREMENT,

    host            TEXT    NOT NULL,

    -- Tên hoặc số ACL.
    -- Ví dụ:
    --   10
    --   101
    --   BLOCK_WEB
    --   IPV6_FILTER
    acl_name        TEXT    NOT NULL,

    -- Loại ACL đã chuẩn hóa.
    acl_type        TEXT    NOT NULL
                            CHECK(
                                acl_type IN (
                                    'standard',
                                    'extended',
                                    'dynamic',
                                    'reflexive',
                                    'mac',
                                    'ipv6',
                                    'unknown'
                                )
                            ),

    -- Họ địa chỉ áp dụng cho ACL.
    address_family  TEXT    NOT NULL DEFAULT 'ipv4'
                            CHECK(
                                address_family IN (
                                    'ipv4',
                                    'ipv6',
                                    'mac',
                                    'unknown'
                                )
                            ),

    -- ACL dạng số hoặc dạng tên.
    acl_format      TEXT    DEFAULT 'named'
                            CHECK(
                                acl_format IN (
                                    'numbered',
                                    'named',
                                    'unknown'
                                )
                            ),

    description     TEXT,

    -- Tổng số rule collector phân tích được.
    rule_count      INTEGER NOT NULL DEFAULT 0
                            CHECK(rule_count >= 0),

    -- Cho biết ACL đang được gắn vào interface hay chưa.
    is_applied      INTEGER NOT NULL DEFAULT 0
                            CHECK(is_applied IN (0,1)),

    -- Thời điểm collector thu thập dữ liệu.
    collected_at    TEXT    NOT NULL
                            DEFAULT (datetime('now')),

    -- Phần output gốc tương ứng ACL để debug parser.
    raw_output      TEXT,

    UNIQUE(host, acl_name, address_family),

    FOREIGN KEY (host)
        REFERENCES t01_devices(host)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);


CREATE INDEX IF NOT EXISTS ix_t10_acl_host
    ON t10_info_acl_db(host);

CREATE INDEX IF NOT EXISTS ix_t10_acl_host_name
    ON t10_info_acl_db(host, acl_name);

CREATE INDEX IF NOT EXISTS ix_t10_acl_type
    ON t10_info_acl_db(host, acl_type);

CREATE INDEX IF NOT EXISTS ix_t10_acl_collected_at
    ON t10_info_acl_db(collected_at);


-- ============================================================
-- 10b. ACL RULES
-- Lưu các ACE - Access Control Entry của ACL.
--
-- Bảng này dùng chung cho:
--   - Standard ACL
--   - Extended ACL
--   - Dynamic ACL
--   - Reflexive ACL
--   - IPv6 ACL
--   - MAC ACL
-- ============================================================

CREATE TABLE IF NOT EXISTS t10_info_acl_rules (
    info_rule_id      INTEGER PRIMARY KEY AUTOINCREMENT,

    info_acl_id       INTEGER NOT NULL,

    -- Số thứ tự ACE nếu output thiết bị có sequence.
    sequence          INTEGER,
    CHECK(sequence IS NULL OR sequence >= 0),

    action            TEXT    NOT NULL
                              CHECK(action IN ('permit','deny','remark')),

    -- Giao thức:
    -- ip, tcp, udp, icmp, icmpv6, gre, ospf, esp, ahp...
    -- NULL đối với standard ACL hoặc remark.
    protocol          TEXT,

    -- Biểu diễn nguồn đã chuẩn hóa.
    -- Ví dụ:
    -- any
    -- host 192.168.1.10
    -- 192.168.1.0
    source            TEXT,

    src_wildcard      TEXT,
    src_prefix_length INTEGER
                              CHECK(
                                  src_prefix_length IS NULL
                                  OR src_prefix_length BETWEEN 0 AND 128
                              ),

    -- Toán tử cổng:
    -- eq, neq, lt, gt, range.
    src_port_operator TEXT
                              CHECK(
                                  src_port_operator IS NULL
                                  OR src_port_operator IN (
                                      'eq',
                                      'neq',
                                      'lt',
                                      'gt',
                                      'range'
                                  )
                              ),

    src_port_start    TEXT,
    src_port_end      TEXT,

    -- Đích có thể NULL đối với standard ACL hoặc remark.
    destination       TEXT,

    dst_wildcard      TEXT,
    dst_prefix_length INTEGER
                              CHECK(
                                  dst_prefix_length IS NULL
                                  OR dst_prefix_length BETWEEN 0 AND 128
                              ),

    dst_port_operator TEXT
                              CHECK(
                                  dst_port_operator IS NULL
                                  OR dst_port_operator IN (
                                      'eq',
                                      'neq',
                                      'lt',
                                      'gt',
                                      'range'
                                  )
                              ),

    dst_port_start    TEXT,
    dst_port_end      TEXT,

    -- Các tùy chọn TCP:
    -- established, syn, ack, rst, fin, psh, urg...
    tcp_flags         TEXT,

    -- Loại ICMP:
    -- echo, echo-reply, unreachable...
    icmp_type         TEXT,
    icmp_code         TEXT,

    -- Tên dynamic ACL.
    dynamic_name      TEXT,

    -- Tên reflexive ACL.
    reflect_name      TEXT,

    -- Dùng cho evaluate <reflect-name>.
    evaluate_name     TEXT,

    -- Timeout được thiết bị hiển thị, nếu có.
    timeout_seconds   INTEGER
                              CHECK(
                                  timeout_seconds IS NULL
                                  OR timeout_seconds > 0
                              ),

    -- Nội dung remark.
    remark_text       TEXT,

    -- Tùy chọn log hoặc log-input.
    logging           TEXT
                              CHECK(
                                  logging IS NULL
                                  OR logging IN (
                                      'log',
                                      'log-input'
                                  )
                              ),

    -- Số packet match ACE, lấy từ dạng:
    -- (123 matches)
    match_count       INTEGER DEFAULT 0
                              CHECK(match_count >= 0),

    -- Thông tin hardware match nếu thiết bị hỗ trợ.
    hardware_count    INTEGER
                              CHECK(
                                  hardware_count IS NULL
                                  OR hardware_count >= 0
                              ),

    -- Cho biết rule là rule tạm thời được sinh bởi dynamic
    -- hoặc reflexive ACL.
    is_temporary      INTEGER NOT NULL DEFAULT 0
                              CHECK(is_temporary IN (0,1)),

    -- Cho biết rule được parser nhận diện đầy đủ.
    parsed_ok         INTEGER NOT NULL DEFAULT 1
                              CHECK(parsed_ok IN (0,1)),

    collected_at      TEXT    NOT NULL
                              DEFAULT (datetime('now')),

    -- Dòng output nguyên bản của ACE.
    raw_line          TEXT,

    FOREIGN KEY (info_acl_id)
        REFERENCES t10_info_acl_db(info_acl_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);


CREATE INDEX IF NOT EXISTS ix_t10_acl_rules_acl
    ON t10_info_acl_rules(info_acl_id);

CREATE INDEX IF NOT EXISTS ix_t10_acl_rules_sequence
    ON t10_info_acl_rules(info_acl_id, sequence);

CREATE INDEX IF NOT EXISTS ix_t10_acl_rules_action
    ON t10_info_acl_rules(action);

CREATE INDEX IF NOT EXISTS ix_t10_acl_rules_protocol
    ON t10_info_acl_rules(protocol);

CREATE INDEX IF NOT EXISTS ix_t10_acl_rules_collected_at
    ON t10_info_acl_rules(collected_at);


-- ============================================================
-- 10c. MAC ACL RULE DETAILS
-- Lưu phần dữ liệu riêng của MAC ACL.
--
-- Một bản ghi trong bảng này mở rộng một rule tương ứng trong
-- t10_info_acl_rules.
-- ============================================================

CREATE TABLE IF NOT EXISTS t10_info_mac_acl_rule_details (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,

    info_rule_id    INTEGER NOT NULL UNIQUE,

    src_mac         TEXT,
    src_mask        TEXT,

    dst_mac         TEXT,
    dst_mask        TEXT,

    -- Ví dụ:
    -- ipv4
    -- ipv6
    -- arp
    -- 0x0800
    ethertype       TEXT,

    -- Có thể chứa vlan, cos hoặc các tùy chọn MAC ACL khác.
    vlan_id         INTEGER
                            CHECK(
                                vlan_id IS NULL
                                OR vlan_id BETWEEN 1 AND 4094
                            ),

    cos_value       INTEGER
                            CHECK(
                                cos_value IS NULL
                                OR cos_value BETWEEN 0 AND 7
                            ),

    raw_line        TEXT,

    FOREIGN KEY (info_rule_id)
        REFERENCES t10_info_acl_rules(info_rule_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);


CREATE INDEX IF NOT EXISTS ix_t10_mac_acl_src
    ON t10_info_mac_acl_rule_details(src_mac);

CREATE INDEX IF NOT EXISTS ix_t10_mac_acl_dst
    ON t10_info_mac_acl_rule_details(dst_mac);


-- ============================================================
-- 10d. ACL ĐƯỢC ÁP DỤNG TRÊN INTERFACE
-- Nguồn dữ liệu:
--   show ip interface
--   show ipv6 interface
--   show running-config interface <interface>
-- ============================================================

CREATE TABLE IF NOT EXISTS t10_info_iface_acl (
    id               INTEGER PRIMARY KEY AUTOINCREMENT,

    host             TEXT    NOT NULL,

    -- Có thể liên kết được với t02_interface_name hoặc để NULL
    -- khi collector chưa tìm thấy iface_id tương ứng.
    iface_id         INTEGER,

    -- Tên interface lấy trực tiếp từ thiết bị.
    interface_name   TEXT    NOT NULL,

    info_acl_id      INTEGER,

    -- Tên ACL lấy trực tiếp từ output.
    -- Vẫn lưu acl_name để tránh mất thông tin nếu chưa liên kết
    -- được với t10_info_acl_db.
    acl_name         TEXT    NOT NULL,

    direction        TEXT    NOT NULL
                             CHECK(direction IN ('in','out')),

    address_family   TEXT    NOT NULL DEFAULT 'ipv4'
                             CHECK(
                                 address_family IN (
                                     'ipv4',
                                     'ipv6',
                                     'mac',
                                     'unknown'
                                 )
                             ),

    -- Loại cách áp ACL.
    -- interface: ip access-group / ipv6 traffic-filter
    -- vlan: VLAN access-map
    -- control-plane: control-plane ACL
    apply_scope      TEXT    NOT NULL DEFAULT 'interface'
                             CHECK(
                                 apply_scope IN (
                                     'interface',
                                     'vlan',
                                     'control-plane',
                                     'line',
                                     'unknown'
                                 )
                             ),

    collected_at     TEXT    NOT NULL
                             DEFAULT (datetime('now')),

    raw_line         TEXT,

    UNIQUE(
        host,
        interface_name,
        acl_name,
        direction,
        address_family,
        apply_scope
    ),

    FOREIGN KEY (host)
        REFERENCES t01_devices(host)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    FOREIGN KEY (iface_id)
        REFERENCES t02_interface_name(iface_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    FOREIGN KEY (info_acl_id)
        REFERENCES t10_info_acl_db(info_acl_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);


CREATE INDEX IF NOT EXISTS ix_t10_iface_acl_host
    ON t10_info_iface_acl(host);

CREATE INDEX IF NOT EXISTS ix_t10_iface_acl_interface
    ON t10_info_iface_acl(host, interface_name);

CREATE INDEX IF NOT EXISTS ix_t10_iface_acl_acl
    ON t10_info_iface_acl(info_acl_id);

CREATE INDEX IF NOT EXISTS ix_t10_iface_acl_name
    ON t10_info_iface_acl(host, acl_name);

CREATE INDEX IF NOT EXISTS ix_t10_iface_acl_collected_at
    ON t10_info_iface_acl(collected_at);


-- ============================================================
-- 10e. ACL COLLECTION SNAPSHOT
-- Quản lý từng lần chạy collector ACL.
--
-- Bảng này giúp phân biệt dữ liệu của nhiều lần thu thập và
-- theo dõi lỗi lệnh hoặc lỗi parser.
-- ============================================================

CREATE TABLE IF NOT EXISTS t10_info_acl_collection (
    collection_id    INTEGER PRIMARY KEY AUTOINCREMENT,

    host             TEXT    NOT NULL,

    command          TEXT    NOT NULL,

    started_at       TEXT    NOT NULL
                             DEFAULT (datetime('now')),

    completed_at     TEXT,

    collection_state TEXT    NOT NULL DEFAULT 'running'
                             CHECK(
                                 collection_state IN (
                                     'running',
                                     'completed',
                                     'partial',
                                     'failed'
                                 )
                             ),

    acl_count        INTEGER NOT NULL DEFAULT 0
                             CHECK(acl_count >= 0),

    rule_count       INTEGER NOT NULL DEFAULT 0
                             CHECK(rule_count >= 0),

    error_message    TEXT,

    raw_output       TEXT,

    FOREIGN KEY (host)
        REFERENCES t01_devices(host)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);


CREATE INDEX IF NOT EXISTS ix_t10_acl_collection_host
    ON t10_info_acl_collection(host);

CREATE INDEX IF NOT EXISTS ix_t10_acl_collection_started
    ON t10_info_acl_collection(started_at);

CREATE INDEX IF NOT EXISTS ix_t10_acl_collection_state
    ON t10_info_acl_collection(host, collection_state);
-- ============================================================
-- END FILE: info_collected/10_info_acl copy.sql
-- ============================================================


-- ============================================================
-- BEGIN FILE: info_collected/11_info_nat.sql
-- ============================================================

-- ============================================================
-- 11. DỮ LIỆU NAT THU THẬP TỪ THIẾT BỊ
--     NAT INFO / COLLECTED DATA
-- ============================================================
-- Nguồn dữ liệu:
--   show running-config | include ip nat
--   show running-config | section ip nat
--   show ip nat translations
--   show ip nat translations verbose
--   show ip nat statistics
--
-- Không sử dụng:
--   show ip interface
--
-- Vì trạng thái:
--   ip nat inside
--   ip nat outside
--
-- là thuộc tính của interface và phải được collector interface
-- xử lý trong nhóm dữ liệu thông tin interface.
--
-- Các bảng t11_info_nat_* là dữ liệu READ-ONLY từ góc độ
-- cấu hình.
--
-- Không sử dụng:
--   - success
--   - action_Cfg
--
-- Vì đây là dữ liệu được thu thập từ thiết bị, không phải dữ
-- liệu cấu hình chờ push.
-- ============================================================

-- ============================================================
-- 11a. NAT DATABASE / NAT CONFIGURATION SUMMARY
-- ============================================================

CREATE TABLE IF NOT EXISTS t11_info_nat_db (
    info_nat_id         INTEGER PRIMARY KEY AUTOINCREMENT,

    host                TEXT    NOT NULL,

    -- Tên logic do collector sinh ra.
    nat_name            TEXT    NOT NULL,

    nat_type            TEXT    NOT NULL
                                CHECK(
                                    nat_type IN (
                                        'static',
                                        'dynamic',
                                        'overload',
                                        'port_forward',
                                        'exempt',
                                        'unknown'
                                    )
                                ),

    description         TEXT,

    parsed_ok           INTEGER NOT NULL DEFAULT 1
                                CHECK(parsed_ok IN (0,1)),

    collected_at        TEXT    NOT NULL
                                DEFAULT (datetime('now')),

    raw_line            TEXT,

    UNIQUE(host, nat_name),

    FOREIGN KEY (host)
        REFERENCES t01_devices(host)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS ix_t11_nat_db_host
    ON t11_info_nat_db(host);

CREATE INDEX IF NOT EXISTS ix_t11_nat_db_type
    ON t11_info_nat_db(host, nat_type);

CREATE INDEX IF NOT EXISTS ix_t11_nat_db_collected_at
    ON t11_info_nat_db(collected_at);


-- ============================================================
-- 11b. NAT POOLS
-- Nguồn:
--   ip nat pool <name> <start-ip> <end-ip> netmask <mask>
--   ip nat pool <name> <start-ip> <end-ip> prefix-length <n>
-- ============================================================

CREATE TABLE IF NOT EXISTS t11_info_nat_pools (
    info_pool_id        INTEGER PRIMARY KEY AUTOINCREMENT,

    host                TEXT    NOT NULL,

    pool_name           TEXT    NOT NULL,

    start_ip            TEXT    NOT NULL,
    end_ip              TEXT    NOT NULL,

    netmask             TEXT,
    prefix_length       INTEGER,

    CHECK(
        netmask IS NOT NULL
        OR prefix_length IS NOT NULL
    ),

    CHECK(
        prefix_length IS NULL
        OR prefix_length BETWEEN 0 AND 32
    ),

    address_count       INTEGER
                                CHECK(
                                    address_count IS NULL
                                    OR address_count >= 0
                                ),

    allocated_count     INTEGER
                                CHECK(
                                    allocated_count IS NULL
                                    OR allocated_count >= 0
                                ),

    collected_at        TEXT    NOT NULL
                                DEFAULT (datetime('now')),

    raw_line            TEXT,

    UNIQUE(host, pool_name),

    FOREIGN KEY (host)
        REFERENCES t01_devices(host)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS ix_t11_nat_pool_host
    ON t11_info_nat_pools(host);

CREATE INDEX IF NOT EXISTS ix_t11_nat_pool_name
    ON t11_info_nat_pools(host, pool_name);

CREATE INDEX IF NOT EXISTS ix_t11_nat_pool_collected_at
    ON t11_info_nat_pools(collected_at);


-- ============================================================
-- 11c. STATIC NAT / STATIC PAT MAPPINGS
-- Nguồn:
--   ip nat inside source static <local> <global>
--   ip nat inside source static tcp ...
--   ip nat inside source static udp ...
-- ============================================================

CREATE TABLE IF NOT EXISTS t11_info_nat_static_mappings (
    id                  INTEGER PRIMARY KEY AUTOINCREMENT,

    host                TEXT    NOT NULL,

    info_nat_id         INTEGER,

    inside_local_ip     TEXT    NOT NULL,
    inside_global_ip    TEXT    NOT NULL,

    protocol            TEXT
                                CHECK(
                                    protocol IS NULL
                                    OR lower(protocol) IN (
                                        'tcp',
                                        'udp',
                                        'icmp'
                                    )
                                ),

    local_port          INTEGER,
    global_port         INTEGER,

    CHECK(
        local_port IS NULL
        OR local_port BETWEEN 1 AND 65535
    ),

    CHECK(
        global_port IS NULL
        OR global_port BETWEEN 1 AND 65535
    ),

    CHECK(
        (
            local_port IS NULL
            AND global_port IS NULL
        )
        OR
        (
            local_port IS NOT NULL
            AND global_port IS NOT NULL
        )
    ),

    is_extendable       INTEGER NOT NULL DEFAULT 0
                                CHECK(is_extendable IN (0,1)),

    no_alias            INTEGER NOT NULL DEFAULT 0
                                CHECK(no_alias IN (0,1)),

    route_map_name      TEXT,
    redundancy_name     TEXT,
    description         TEXT,

    collected_at        TEXT    NOT NULL
                                DEFAULT (datetime('now')),

    raw_line            TEXT,

    UNIQUE(
        host,
        inside_local_ip,
        inside_global_ip,
        protocol,
        local_port,
        global_port
    ),

    FOREIGN KEY (host)
        REFERENCES t01_devices(host)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    FOREIGN KEY (info_nat_id)
        REFERENCES t11_info_nat_db(info_nat_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS ix_t11_nat_static_host
    ON t11_info_nat_static_mappings(host);

CREATE INDEX IF NOT EXISTS ix_t11_nat_static_local
    ON t11_info_nat_static_mappings(host, inside_local_ip);

CREATE INDEX IF NOT EXISTS ix_t11_nat_static_global
    ON t11_info_nat_static_mappings(host, inside_global_ip);

CREATE INDEX IF NOT EXISTS ix_t11_nat_static_collected_at
    ON t11_info_nat_static_mappings(collected_at);


-- ============================================================
-- 11d. DYNAMIC NAT / PAT RULES
-- Nguồn:
--   ip nat inside source list <acl> pool <pool>
--   ip nat inside source list <acl> pool <pool> overload
--   ip nat inside source list <acl> interface <iface> overload
--   ip nat inside source route-map <name> pool <pool>
--   ip nat inside source route-map <name> interface <iface>
-- ============================================================

CREATE TABLE IF NOT EXISTS t11_info_nat_dynamic_rules (
    id                  INTEGER PRIMARY KEY AUTOINCREMENT,

    host                TEXT    NOT NULL,

    info_nat_id         INTEGER,

    match_type          TEXT    NOT NULL
                                CHECK(
                                    match_type IN (
                                        'acl',
                                        'route-map',
                                        'unknown'
                                    )
                                ),

    acl_name            TEXT,
    route_map_name      TEXT,

    CHECK(
        (
            match_type = 'acl'
            AND acl_name IS NOT NULL
        )
        OR
        (
            match_type = 'route-map'
            AND route_map_name IS NOT NULL
        )
        OR
        (
            match_type = 'unknown'
        )
    ),

    translation_type    TEXT    NOT NULL
                                CHECK(
                                    translation_type IN (
                                        'pool',
                                        'interface',
                                        'unknown'
                                    )
                                ),

    pool_name           TEXT,

    -- Đây là interface được tham chiếu trong câu lệnh NAT:
    -- ip nat inside source list ... interface ...
    --
    -- Không phải thuộc tính ip nat inside/outside của interface.
    outside_interface   TEXT,

    CHECK(
        (
            translation_type = 'pool'
            AND pool_name IS NOT NULL
        )
        OR
        (
            translation_type = 'interface'
            AND outside_interface IS NOT NULL
        )
        OR
        (
            translation_type = 'unknown'
        )
    ),

    overload            INTEGER NOT NULL DEFAULT 0
                                CHECK(overload IN (0,1)),

    vrf_name            TEXT,
    description         TEXT,

    collected_at        TEXT    NOT NULL
                                DEFAULT (datetime('now')),

    raw_line            TEXT,

    UNIQUE(
        host,
        match_type,
        acl_name,
        route_map_name,
        translation_type,
        pool_name,
        outside_interface
    ),

    FOREIGN KEY (host)
        REFERENCES t01_devices(host)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    FOREIGN KEY (info_nat_id)
        REFERENCES t11_info_nat_db(info_nat_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS ix_t11_nat_dynamic_host
    ON t11_info_nat_dynamic_rules(host);

CREATE INDEX IF NOT EXISTS ix_t11_nat_dynamic_acl
    ON t11_info_nat_dynamic_rules(host, acl_name);

CREATE INDEX IF NOT EXISTS ix_t11_nat_dynamic_route_map
    ON t11_info_nat_dynamic_rules(host, route_map_name);

CREATE INDEX IF NOT EXISTS ix_t11_nat_dynamic_pool
    ON t11_info_nat_dynamic_rules(host, pool_name);

CREATE INDEX IF NOT EXISTS ix_t11_nat_dynamic_interface
    ON t11_info_nat_dynamic_rules(host, outside_interface);

CREATE INDEX IF NOT EXISTS ix_t11_nat_dynamic_collected_at
    ON t11_info_nat_dynamic_rules(collected_at);


-- ============================================================
-- 11e. ACTIVE NAT TRANSLATIONS
-- Nguồn:
--   show ip nat translations
--   show ip nat translations verbose
-- ============================================================

CREATE TABLE IF NOT EXISTS t11_info_nat_translations (
    translation_id      INTEGER PRIMARY KEY AUTOINCREMENT,

    host                TEXT    NOT NULL,

    protocol            TEXT,

    inside_global_ip    TEXT,
    inside_global_port  INTEGER,

    inside_local_ip     TEXT,
    inside_local_port   INTEGER,

    outside_local_ip    TEXT,
    outside_local_port  INTEGER,

    outside_global_ip   TEXT,
    outside_global_port INTEGER,

    CHECK(
        inside_global_port IS NULL
        OR inside_global_port BETWEEN 1 AND 65535
    ),

    CHECK(
        inside_local_port IS NULL
        OR inside_local_port BETWEEN 1 AND 65535
    ),

    CHECK(
        outside_local_port IS NULL
        OR outside_local_port BETWEEN 1 AND 65535
    ),

    CHECK(
        outside_global_port IS NULL
        OR outside_global_port BETWEEN 1 AND 65535
    ),

    translation_type    TEXT
                                CHECK(
                                    translation_type IS NULL
                                    OR translation_type IN (
                                        'static',
                                        'dynamic',
                                        'extended',
                                        'unknown'
                                    )
                                ),

    expires_in_seconds  INTEGER
                                CHECK(
                                    expires_in_seconds IS NULL
                                    OR expires_in_seconds >= 0
                                ),

    use_count           INTEGER
                                CHECK(
                                    use_count IS NULL
                                    OR use_count >= 0
                                ),

    flags               TEXT,

    collected_at        TEXT    NOT NULL
                                DEFAULT (datetime('now')),

    raw_line            TEXT,

    FOREIGN KEY (host)
        REFERENCES t01_devices(host)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS ix_t11_nat_translation_host
    ON t11_info_nat_translations(host);

CREATE INDEX IF NOT EXISTS ix_t11_nat_translation_inside_local
    ON t11_info_nat_translations(host, inside_local_ip);

CREATE INDEX IF NOT EXISTS ix_t11_nat_translation_inside_global
    ON t11_info_nat_translations(host, inside_global_ip);

CREATE INDEX IF NOT EXISTS ix_t11_nat_translation_outside_global
    ON t11_info_nat_translations(host, outside_global_ip);

CREATE INDEX IF NOT EXISTS ix_t11_nat_translation_protocol
    ON t11_info_nat_translations(host, protocol);

CREATE INDEX IF NOT EXISTS ix_t11_nat_translation_collected_at
    ON t11_info_nat_translations(collected_at);


-- ============================================================
-- 11f. NAT STATISTICS
-- Nguồn:
--   show ip nat statistics
-- ============================================================

CREATE TABLE IF NOT EXISTS t11_info_nat_statistics (
    statistics_id          INTEGER PRIMARY KEY AUTOINCREMENT,

    host                   TEXT    NOT NULL,

    total_active           INTEGER NOT NULL DEFAULT 0
                                   CHECK(total_active >= 0),

    static_active          INTEGER NOT NULL DEFAULT 0
                                   CHECK(static_active >= 0),

    dynamic_active         INTEGER NOT NULL DEFAULT 0
                                   CHECK(dynamic_active >= 0),

    extended_active        INTEGER NOT NULL DEFAULT 0
                                   CHECK(extended_active >= 0),

    peak_translations      INTEGER
                                   CHECK(
                                       peak_translations IS NULL
                                       OR peak_translations >= 0
                                   ),

    hits                   INTEGER
                                   CHECK(hits IS NULL OR hits >= 0),

    misses                 INTEGER
                                   CHECK(misses IS NULL OR misses >= 0),

    expired_translations   INTEGER
                                   CHECK(
                                       expired_translations IS NULL
                                       OR expired_translations >= 0
                                   ),

    dynamic_mappings_count INTEGER
                                   CHECK(
                                       dynamic_mappings_count IS NULL
                                       OR dynamic_mappings_count >= 0
                                   ),

    collected_at           TEXT    NOT NULL
                                   DEFAULT (datetime('now')),

    raw_output             TEXT,

    FOREIGN KEY (host)
        REFERENCES t01_devices(host)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS ix_t11_nat_statistics_host
    ON t11_info_nat_statistics(host);

CREATE INDEX IF NOT EXISTS ix_t11_nat_statistics_collected_at
    ON t11_info_nat_statistics(collected_at);


-- ============================================================
-- 11g. NAT COLLECTION HISTORY
-- ============================================================

CREATE TABLE IF NOT EXISTS t11_info_nat_collection (
    collection_id      INTEGER PRIMARY KEY AUTOINCREMENT,

    host               TEXT    NOT NULL,

    command            TEXT    NOT NULL,

    started_at         TEXT    NOT NULL
                               DEFAULT (datetime('now')),

    completed_at       TEXT,

    collection_state   TEXT    NOT NULL DEFAULT 'running'
                               CHECK(
                                   collection_state IN (
                                       'running',
                                       'completed',
                                       'partial',
                                       'failed'
                                   )
                               ),

    static_count       INTEGER NOT NULL DEFAULT 0
                               CHECK(static_count >= 0),

    dynamic_count      INTEGER NOT NULL DEFAULT 0
                               CHECK(dynamic_count >= 0),

    translation_count  INTEGER NOT NULL DEFAULT 0
                               CHECK(translation_count >= 0),

    pool_count         INTEGER NOT NULL DEFAULT 0
                               CHECK(pool_count >= 0),

    error_message      TEXT,
    raw_output         TEXT,

    FOREIGN KEY (host)
        REFERENCES t01_devices(host)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS ix_t11_nat_collection_host
    ON t11_info_nat_collection(host);

CREATE INDEX IF NOT EXISTS ix_t11_nat_collection_state
    ON t11_info_nat_collection(host, collection_state);

CREATE INDEX IF NOT EXISTS ix_t11_nat_collection_started_at
    ON t11_info_nat_collection(started_at);
-- ============================================================
-- END FILE: info_collected/11_info_nat.sql
-- ============================================================

