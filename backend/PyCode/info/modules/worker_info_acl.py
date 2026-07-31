import os
import re
from datetime import datetime

def extract_section(raw_text, section_keyword):
    """Hàm phụ trợ cắt đúng phần text của từng lệnh"""
    if section_keyword not in raw_text:
        return ""
    content = raw_text.split(section_keyword)[1]
    content = content.lstrip(" =\n")
    if "[ SHOW" in content:
        content = content.split("[ SHOW")[0]
    if "====================" in content:
        content = content.split("====================")[0]
    return content

def process_acl_data(host, file_path, db_cursor):
    """Worker xử lý dữ liệu ACL - Thuật toán Đồng bộ (Sync/Diffing) giữ nguyên ID"""
    if not os.path.exists(file_path):
        print(f"      [-] Worker ACL: Không tìm thấy file tại {file_path}")
        return False

    with open(file_path, "r", encoding="utf-8") as f:
        raw_text = f.read()

    # Tạo bản ghi Collection Tracker
    start_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    db_cursor.execute("""
        INSERT INTO t10_info_acl_collection (host, command, started_at, collection_state, acl_count, rule_count) 
        VALUES (?, ?, ?, ?, ?, ?)
    """, (host, "show access-lists", start_time, "running", 0, 0))
    collection_id = db_cursor.lastrowid

    acl_sec = extract_section(raw_text, "[ SHOW ACCESS-LISTS ]")
    run_sec = extract_section(raw_text, "[ SHOW RUNNING-CONFIG ]")

    # =========================================================
    # BƯỚC 0: FETCH TRẠNG THÁI DATABASE HIỆN TẠI (ĐỂ SO KHỚP)
    # =========================================================
    # 1. Lấy danh sách ACL hiện tại của Host này -> {acl_name: info_acl_id}
    db_cursor.execute("SELECT info_acl_id, acl_name FROM t10_info_acl_db WHERE host = ?", (host,))
    existing_acls = {row[1]: row[0] for row in db_cursor.fetchall()}

    # 2. Lấy danh sách Rules hiện tại -> {info_acl_id: {sequence: info_rule_id}}
    db_cursor.execute("""
        SELECT info_acl_id, sequence, info_rule_id 
        FROM t10_info_acl_rules 
        WHERE info_acl_id IN (SELECT info_acl_id FROM t10_info_acl_db WHERE host = ?)
    """, (host,))
    existing_rules = {}
    for acl_id, seq, rule_id in db_cursor.fetchall():
        if acl_id not in existing_rules:
            existing_rules[acl_id] = {}
        existing_rules[acl_id][seq] = rule_id

    # Biến theo dõi những gì quét được trong đợt này
    seen_acls = set()
    seen_rules = {} # {info_acl_id: set(sequences)}

    total_acls = 0
    total_rules = 0
    current_acl_id = None
    current_acl_type = None
    mock_sequence = 10  
    #Khởi tạo bộ đếm sequence giả để đối phó với mac-acl của layer2
    #T thề là t cố hết sức với cái mac_acl rồi nên là chịu gắn biến giả đi
    # =========================================================
    # BƯỚC 1: PARSE VÀ ĐỒNG BỘ (UPSERT) DỮ LIỆU ACL & RULES
    # =========================================================
    if acl_sec:
        for line in acl_sec.splitlines():
            line = line.rstrip()
            if not line: continue

            # 1.1 XỬ LÝ HEADER ACL
            # Cập nhật Regex để bắt được cụm từ ở giữa (VD: bắt được chữ "MAC" trong "Extended MAC access list")
            header_match = re.match(r"^(Standard|Extended|IPv6|MAC)\s+(.*?)access\s+list\s+(.+)$", line, re.I)
            if header_match:
                prefix = header_match.group(1).lower()
                middle = header_match.group(2).lower()
                acl_name = header_match.group(3).strip()

                # PHÂN LOẠI LẠI ĐÚNG HỆ GIA PHẢ CỦA ACL (Sửa lỗi MAC bị nhận nhầm thành IPv4)
                if "mac" in middle or prefix == "mac":
                    address_family = "mac"
                    current_acl_type = "mac"  # Quan trọng: Ép về 'mac' để luồng 1.2 bóc tách đúng
                    acl_type = "extended" 
                elif "ipv6" in middle or prefix == "ipv6":
                    address_family = "ipv6"
                    current_acl_type = "ipv6"
                    acl_type = prefix if prefix in ["standard", "extended"] else "extended"
                else:
                    address_family = "ipv4"
                    current_acl_type = prefix
                    acl_type = prefix

                acl_format = 'numbered' if acl_name.isdigit() else 'named'

                if acl_name in existing_acls:
                    # ACL đã tồn tại -> UPDATE
                    current_acl_id = existing_acls[acl_name]
                    db_cursor.execute("""
                        UPDATE t10_info_acl_db 
                        SET acl_type = ?, address_family = ?, acl_format = ?, is_applied = 0, rule_count = 0, raw_output = ?
                        WHERE info_acl_id = ?
                    """, (acl_type, address_family, acl_format, line, current_acl_id))
                else:
                    # ACL mới tinh -> INSERT
                    db_cursor.execute("""
                        INSERT INTO t10_info_acl_db (host, acl_name, acl_type, address_family, acl_format, is_applied, rule_count, raw_output) 
                        VALUES (?, ?, ?, ?, ?, 0, 0, ?)
                    """, (host, acl_name, acl_type, address_family, acl_format, line))
                    current_acl_id = db_cursor.lastrowid
                    existing_acls[acl_name] = current_acl_id # Cập nhật dict

                seen_acls.add(current_acl_id)
                if current_acl_id not in seen_rules:
                    seen_rules[current_acl_id] = set()
                
                total_acls += 1
                mock_sequence = 10
                continue

           
            # 1.2 XỬ LÝ RULES (Chỉ chạy khi đã có header)
            if current_acl_id and (line.startswith(" ") or line.startswith("\t")):
                rule_str = line.strip()
                
                # 🚀 BƯỚC 1: QUÉT TÌM VÀ CẮT BỎ ĐUÔI 'SEQUENCE XX' CỦA IPV6
                seq_at_end = None
                end_seq_match = re.search(r"\bsequence\s+(\d+)$", rule_str, re.I)
                if end_seq_match:
                    seq_at_end = int(end_seq_match.group(1))
                    # Xén mất phần đuôi để không làm nhiễu logic bóc tách IP/Port ở dưới
                    rule_str = rule_str[:end_seq_match.start()].strip()

                # 🚀 BƯỚC 2: QUÉT SỐ Ở ĐẦU HOẶC KHÔNG CÓ SỐ (IPV4 & MAC)
                seq_match = re.match(r"^(?:(\d+)\s+)?(permit|deny|remark|evaluate|dynamic)\b\s*(.*)", rule_str, re.I)
                
                if seq_match:
                    # Logic thích ứng chốt hạ Sequence
                    if seq_at_end is not None:
                        sequence = seq_at_end               # Ưu tiên 1: Lấy số ở cuối (Dị bản IPv6)
                        mock_sequence = sequence + 10
                    elif seq_match.group(1):
                        sequence = int(seq_match.group(1))  # Ưu tiên 2: Lấy số ở đầu (Chuẩn IPv4)
                        mock_sequence = sequence + 10
                    else:
                        sequence = mock_sequence            # Ưu tiên 3: Tự sinh số (Dị bản MAC)
                        mock_sequence += 10
                        
                    action = seq_match.group(2).lower()
                    remainder = seq_match.group(3)

                    # Bóc Match count
                    match_count = 0
                    matches_match = re.search(r"\((\d+)\s+match(?:es)?\)", remainder, re.I)
                    if matches_match:
                        match_count = int(matches_match.group(1))
                        remainder = remainder.replace(matches_match.group(0), "").strip()

                    # Bóc Logging
                    logging = None
                    if remainder.endswith(" log"):
                        logging = "log"
                        remainder = remainder[:-4].strip()
                    elif remainder.endswith(" log-input"):
                        logging = "log-input"
                        remainder = remainder[:-10].strip()

                    # Khởi tạo biến cho bảng t10_info_acl_rules
                    parsed_ok = 1
                    source = dst = src_wild = dst_wild = protocol = None
                    src_port_op = src_port_start = src_port_end = None
                    dst_port_op = dst_port_start = dst_port_end = None
                    tcp_flags = icmp_type = icmp_code = dynamic_name = reflect_name = evaluate_name = None
                    remark_text = None
                    
                    # 🚀 KHỞI TẠO BIẾN ĐỘC LẬP CHO BẢNG MAC (Không mượn tạm)
                    ethertype = vlan_id = cos_value = None
                    
                    original_action = action
                    
                    # XỬ LÝ ACTION ĐẶC BIỆT: EVALUATE VÀ DYNAMIC
                    if action == "evaluate":
                        evaluate_name = remainder.strip()
                        action = "permit"  
                    elif action == "dynamic":
                        parts = remainder.split()
                        if len(parts) >= 2:
                            dynamic_name = parts[0]
                            action = parts[1].lower() 
                            remainder = " ".join(parts[2:])
                    
                    # BÓC TÁCH THEO TYPE
                    if original_action == "remark":
                        remark_text = remainder
                    
                    elif original_action != "evaluate" and current_acl_type == "standard":
                        remainder = remainder.replace(",", "").replace("wildcard bits", "").strip()
                        if remainder == "any":
                            source = "any"
                        elif remainder.startswith("host "):
                            source = remainder.split()[1]
                            src_wild = "0.0.0.0"
                        else:
                            parts = remainder.split()
                            if len(parts) >= 2:
                                source, src_wild = parts[0], parts[1]
                            elif len(parts) == 1 and re.match(r"^\d+\.\d+\.\d+\.\d+$", parts[0]):
                                source = parts[0]
                                src_wild = "0.0.0.0"
                            else:
                                source = remainder
                                parsed_ok = 0
                    
                    # 🚀 NHÁNH XỬ LÝ ĐỘC LẬP CHO MAC ACL
                    elif original_action != "evaluate" and current_acl_type == "mac":
                        tokens = remainder.split()
                        
                        def parse_mac_block(tks):
                            mac_val = mask_val = None
                            if not tks: return mac_val, mask_val
                            if tks[0] == "any":
                                mac_val = tks.pop(0)
                            elif tks[0] == "host":
                                tks.pop(0)
                                if tks:
                                    mac_val = tks.pop(0)
                                    mask_val = "0000.0000.0000"
                            else:
                                mac_val = tks.pop(0)
                                if tks and re.match(r"^[0-9a-fA-F\.]+$", tks[0]):
                                    mask_val = tks.pop(0)
                            return mac_val, mask_val

                        try:
                            source, src_wild = parse_mac_block(tokens)
                            dst, dst_wild = parse_mac_block(tokens)
                            
                            if tokens and tokens[0] not in ['vlan', 'cos', 'log']:
                                ethertype = tokens.pop(0)
                                if ethertype == "lsap" and len(tokens) >= 2:
                                    ethertype = f"lsap {tokens.pop(0)} {tokens.pop(0)}"

                            while tokens:
                                tok = tokens.pop(0).lower()
                                if tok == "vlan" and tokens:
                                    try: vlan_id = int(tokens.pop(0)) # Gán thẳng vào biến độc lập
                                    except ValueError: pass
                                elif tok == "cos" and tokens:
                                    try: cos_value = int(tokens.pop(0)) # Gán thẳng vào biến độc lập
                                    except ValueError: pass
                                elif tok == "log":
                                    logging = "log"
                        except Exception:
                            parsed_ok = 0
                            
                    # 🚀 NHÁNH XỬ LÝ ĐỘC LẬP CHO EXTENDED (IP)
                    elif original_action != "evaluate" and current_acl_type == "extended":
                        tokens = remainder.split()
                        if tokens: protocol = tokens.pop(0)
                        
                        def parse_ip_block(tks):
                            ip_val = wild_val = None
                            if not tks: return ip_val, wild_val
                            if tks[0] == "any":
                                ip_val = tks.pop(0)
                            elif tks[0] == "host":
                                tks.pop(0)
                                if tks:
                                    ip_val = tks.pop(0)
                                    wild_val = "0.0.0.0"
                            else:
                                ip_val = tks.pop(0)
                                if tks and re.match(r"^\d+\.\d+\.\d+\.\d+$", tks[0]):
                                    wild_val = tks.pop(0)
                            return ip_val, wild_val

                        def parse_port_block(tks):
                            op = p_start = p_end = None
                            if tks and tks[0] in ["eq", "neq", "lt", "gt", "range"]:
                                op = tks.pop(0)
                                if tks: p_start = tks.pop(0)
                                if op == "range" and tks: p_end = tks.pop(0)
                            return op, p_start, p_end

                        try:
                            source, src_wild = parse_ip_block(tokens)
                            src_port_op, src_port_start, src_port_end = parse_port_block(tokens)
                            dst, dst_wild = parse_ip_block(tokens)
                            dst_port_op, dst_port_start, dst_port_end = parse_port_block(tokens)
                            
                            while tokens:
                                tok = tokens.pop(0).lower()
                                if tok == "reflect" and tokens:
                                    reflect_name = tokens.pop(0)
                                elif tok == "timeout" and tokens:
                                    try:
                                        timeout_seconds = int(tokens.pop(0))
                                    except ValueError:
                                        pass
                                elif tok == "established":
                                    tcp_flags = "established"
                                elif tok in ["syn", "ack", "fin", "rst", "urg", "psh"]:
                                    tcp_flags = tok
                                elif protocol == "icmp" and not icmp_type:
                                    tok_lower = tok
                                    icmp_comprehensive_mapping = {
                                        "echo": ("8", "0"), "echo-reply": ("0", "0"), "unreachable": ("3", None),
                                        "network-unreachable": ("3", "0"), "host-unreachable": ("3", "1"),
                                        "protocol-unreachable": ("3", "2"), "port-unreachable": ("3", "3"),
                                        "packet-too-big": ("3", "4"), "ttl-exceeded": ("11", "0"),
                                        "time-exceeded": ("11", "0"), "traceroute": ("30", "0"),
                                        "mask-request": ("17", "0"), "mask-reply": ("18", "0"),
                                        "router-advertisement": ("9", "0"), "router-solicitation": ("10", "0"),
                                        "timestamp-request": ("13", "0"), "timestamp-reply": ("14", "0"),
                                        "information-request": ("15", "0"), "information-reply": ("16", "0")
                                    }
                                    
                                    if tok_lower in icmp_comprehensive_mapping:
                                        icmp_type, icmp_code = icmp_comprehensive_mapping[tok_lower]
                                    elif tok_lower.isdigit():
                                        icmp_type = tok_lower
                                        if tokens and tokens[0].isdigit():
                                            icmp_code = tokens.pop(0)
                                    else:
                                        icmp_type = tok_lower
                        except Exception:
                            parsed_ok = 0 

                    # Cập nhật rule_tuple (Không có MAC fields)
                    rule_tuple = (
                        action, protocol, source, src_wild, src_port_op, src_port_start, src_port_end,
                        dst, dst_wild, dst_port_op, dst_port_start, dst_port_end,
                        tcp_flags, icmp_type, icmp_code, dynamic_name, reflect_name, evaluate_name,
                        match_count, logging, remark_text, parsed_ok, rule_str
                    )

                    # Lưu vào Bảng Cha: t10_info_acl_rules
                    rule_id_db = None
                    if current_acl_id in existing_rules and sequence in existing_rules[current_acl_id]:
                        rule_id_db = existing_rules[current_acl_id][sequence]
                        db_cursor.execute("""
                            UPDATE t10_info_acl_rules SET 
                                action=?, protocol=?, source=?, src_wildcard=?, src_port_operator=?, src_port_start=?, src_port_end=?,
                                destination=?, dst_wildcard=?, dst_port_operator=?, dst_port_start=?, dst_port_end=?,
                                tcp_flags=?, icmp_type=?, icmp_code=?, dynamic_name=?, reflect_name=?, evaluate_name=?,
                                match_count=?, logging=?, remark_text=?, parsed_ok=?, raw_line=?
                            WHERE info_rule_id = ?
                        """, (*rule_tuple, rule_id_db))
                    else:
                        db_cursor.execute("""
                            INSERT INTO t10_info_acl_rules (
                                info_acl_id, sequence, action, protocol, source, src_wildcard, src_port_operator, src_port_start, src_port_end,
                                destination, dst_wildcard, dst_port_operator, dst_port_start, dst_port_end,
                                tcp_flags, icmp_type, icmp_code, dynamic_name, reflect_name, evaluate_name,
                                match_count, logging, remark_text, parsed_ok, raw_line
                            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                        """, (current_acl_id, sequence, *rule_tuple))
                        rule_id_db = db_cursor.lastrowid # Bắt ID ngay sau khi Insert để dùng cho bảng con

                    # 🚀 LƯU VÀO BẢNG CON MAC CHI TIẾT NẾU LÀ MAC ACL
                    if current_acl_type == "mac" and original_action != "remark" and rule_id_db is not None:
                        db_cursor.execute("SELECT id FROM t10_info_mac_acl_rule_details WHERE info_rule_id = ?", (rule_id_db,))
                        if db_cursor.fetchone():
                            db_cursor.execute("""
                                UPDATE t10_info_mac_acl_rule_details SET 
                                    src_mac=?, src_mask=?, dst_mac=?, dst_mask=?, ethertype=?, vlan_id=?, cos_value=?, raw_line=?
                                WHERE info_rule_id = ?
                            """, (source, src_wild, dst, dst_wild, ethertype, vlan_id, cos_value, rule_str, rule_id_db))
                        else:
                            db_cursor.execute("""
                                INSERT INTO t10_info_mac_acl_rule_details (
                                    info_rule_id, src_mac, src_mask, dst_mac, dst_mask, ethertype, vlan_id, cos_value, raw_line
                                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                            """, (rule_id_db, source, src_wild, dst, dst_wild, ethertype, vlan_id, cos_value, rule_str))

                    seen_rules[current_acl_id].add(sequence)
                    db_cursor.execute("UPDATE t10_info_acl_db SET rule_count = rule_count + 1 WHERE info_acl_id = ?", (current_acl_id,))
                    total_rules += 1
    # =========================================================
    # BƯỚC 1.5: QUÉT LẠI RUNNING-CONFIG (BẮT TIMEOUT & PHÂN LOẠI DESCRIPTION / REMARK)
    # =========================================================
    if run_sec:
        current_acl_name = None
        has_seen_action = False  # Cờ theo dõi xem ACL đã có lệnh thực thi nào chưa
        
        for line in run_sec.splitlines():
            line = line.strip()
            
            # --- KIỂU 1: BLOCK EXTENDED/NAMED ACL (Bắt đầu bằng ip access-list) ---
            if line.startswith("ip access-list "):
                current_acl_name = line.split()[-1]
                has_seen_action = False  # Reset cờ cho ACL mới
                continue
            elif line == "!":
                current_acl_name = None
                has_seen_action = False
                continue
                
            # Đang ở trong block cấu hình của 1 ACL
            if current_acl_name and current_acl_name in existing_acls:
                acl_id = existing_acls[current_acl_name]
                
                # Nếu gặp lệnh "thực thi" -> Bật cờ đã có action
                if re.match(r"^(permit|deny|evaluate|dynamic)\b", line, re.I):
                    has_seen_action = True
                    
                    # Logic bắt timeout
                    timeout_match = re.search(r"timeout\s+(\d+)", line, re.I)
                    if timeout_match:
                        t_val = int(timeout_match.group(1))
                        dyn_match = re.search(r"dynamic\s+(\S+)", line, re.I)
                        ref_match = re.search(r"reflect\s+(\S+)", line, re.I)
                        
                        if dyn_match:
                            db_cursor.execute("UPDATE t10_info_acl_rules SET timeout_seconds = ? WHERE info_acl_id = ? AND dynamic_name = ?", (t_val, acl_id, dyn_match.group(1)))
                        elif ref_match:
                            db_cursor.execute("UPDATE t10_info_acl_rules SET timeout_seconds = ? WHERE info_acl_id = ? AND reflect_name = ?", (t_val, acl_id, ref_match.group(1)))
                            
                # Nếu gặp lệnh "remark"
                remark_match = re.match(r"^remark\s+(.*)", line, re.I)
                if remark_match:
                    rem_text = remark_match.group(1).strip()
                    
                    if not has_seen_action:
                        # Đứng đầu hoặc đứng một mình -> Cập nhật thành Description cho toàn bộ ACL
                        db_cursor.execute("UPDATE t10_info_acl_db SET description = ? WHERE info_acl_id = ?", (rem_text, acl_id))
                    else:
                        # Nằm xen kẽ ở dưới -> Nó là rule remark nội bộ
                        db_cursor.execute("SELECT info_rule_id FROM t10_info_acl_rules WHERE info_acl_id = ? AND action = 'remark' AND remark_text = ?", (acl_id, rem_text))
                        if not db_cursor.fetchone():
                            db_cursor.execute("""
                                INSERT INTO t10_info_acl_rules (
                                    info_acl_id, sequence, action, protocol, source, src_wildcard, src_port_operator, src_port_start, src_port_end,
                                    destination, dst_wildcard, dst_port_operator, dst_port_start, dst_port_end,
                                    tcp_flags, icmp_type, icmp_code, dynamic_name, reflect_name, evaluate_name,
                                    match_count, logging, remark_text, parsed_ok, raw_line
                                ) VALUES (?, NULL, 'remark', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, ?, 1, ?)
                            """, (acl_id, rem_text, line))
                            db_cursor.execute("UPDATE t10_info_acl_db SET rule_count = rule_count + 1 WHERE info_acl_id = ?", (acl_id,))
                            
            # --- KIỂU 2: GLOBAL STANDARD ACL (Bắt đầu bằng access-list 10...) ---
            m_std = re.match(r"^access-list\s+(\S+)\s+(.*)", line, re.I)
            if m_std:
                acl_name = m_std.group(1)
                content = m_std.group(2)
                
                # Nếu nhảy sang ACL khác -> Reset cờ
                if current_acl_name != acl_name:
                    current_acl_name = acl_name
                    has_seen_action = False
                
                if current_acl_name in existing_acls:
                    acl_id = existing_acls[current_acl_name]
                    
                    if content.lower().startswith("remark "):
                        rem_text = content[7:].strip()
                        if not has_seen_action:
                            # Đứng đầu khối lệnh
                            db_cursor.execute("UPDATE t10_info_acl_db SET description = ? WHERE info_acl_id = ?", (rem_text, acl_id))
                        else:
                            # Nằm dưới permit/deny
                            db_cursor.execute("SELECT info_rule_id FROM t10_info_acl_rules WHERE info_acl_id = ? AND action = 'remark' AND remark_text = ?", (acl_id, rem_text))
                            if not db_cursor.fetchone():
                                db_cursor.execute("""
                                    INSERT INTO t10_info_acl_rules (
                                        info_acl_id, sequence, action, protocol, source, src_wildcard, src_port_operator, src_port_start, src_port_end,
                                        destination, dst_wildcard, dst_port_operator, dst_port_start, dst_port_end,
                                        tcp_flags, icmp_type, icmp_code, dynamic_name, reflect_name, evaluate_name,
                                        match_count, logging, remark_text, parsed_ok, raw_line
                                    ) VALUES (?, NULL, 'remark', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, ?, 1, ?)
                                """, (acl_id, rem_text, line))
                                db_cursor.execute("UPDATE t10_info_acl_db SET rule_count = rule_count + 1 WHERE info_acl_id = ?", (acl_id,))
                    else:
                        # Gặp permit/deny dạng access-list -> Bật cờ
                        has_seen_action = True
    # =========================================================
    # BƯỚC 2: DỌN DẸP DỮ LIỆU CŨ & ĐỒNG BỘ INTERFACE
    # =========================================================
    # Xóa các Rule bị mất khỏi ACL
    for acl_id, seq_dict in existing_rules.items():
        if acl_id in seen_rules:
            for old_seq, rule_id in seq_dict.items():
                if old_seq not in seen_rules[acl_id]:
                    db_cursor.execute("DELETE FROM t10_info_acl_rules WHERE info_rule_id = ?", (rule_id,))

    # Xóa hoàn toàn các ACL bị mất khỏi Router (Cascade sẽ xóa Rules theo nếu sếp đã set Foreign Key constraint)
    for old_acl_id in list(existing_acls.values()):
        if old_acl_id not in seen_acls:
            db_cursor.execute("DELETE FROM t10_info_acl_rules WHERE info_acl_id = ?", (old_acl_id,))
            db_cursor.execute("DELETE FROM t10_info_acl_db WHERE info_acl_id = ?", (old_acl_id,))

    # Interface Mapping: Reset lại của riêng host này vì cấu trúc cổng có thể nhảy liên tục
    db_cursor.execute("DELETE FROM t10_info_iface_acl WHERE host = ?", (host,))
    
    if run_sec:
        current_iface = None
        for line in run_sec.splitlines():
            line = line.strip()
            if line.startswith("interface "):
                current_iface = line.split("interface ")[1]
            elif current_iface and line.startswith("ip access-group "):
                parts = line.split()
                if len(parts) >= 4:
                    acl_name = parts[2]
                    direction = parts[3].lower()
                    
                    if acl_name in existing_acls:
                        acl_id = existing_acls[acl_name]
                        if direction in ['in', 'out']:
                            db_cursor.execute("""
                                INSERT INTO t10_info_iface_acl (host, interface_name, info_acl_id, acl_name, direction, address_family, apply_scope, raw_line) 
                                VALUES (?, ?, ?, ?, ?, 'ipv4', 'interface', ?)
                            """, (host, current_iface, acl_id, acl_name, direction, line))
                            
                            db_cursor.execute("UPDATE t10_info_acl_db SET is_applied = 1 WHERE info_acl_id = ?", (acl_id,))

    # =========================================================
    # BƯỚC 3: CẬP NHẬT TRẠNG THÁI COLLECTION
    # =========================================================
    end_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    db_cursor.execute("""
        UPDATE t10_info_acl_collection 
        SET completed_at = ?, collection_state = ?, acl_count = ?, rule_count = ? 
        WHERE collection_id = ?
    """, (end_time, "completed", total_acls, total_rules, collection_id))

    return True