import os
import re
import sqlite3

# ZERO HARDCODE
from backend.PyCode.share.config import DB_TABLES, DB_PATH, L2_BACKUP_DIR

TBL_VLAN = DB_TABLES["l2_vlan"]["main"]

def parse_vlan_file(file_path: str) -> dict:
    """Đọc file _vlan.txt do Collector kéo về và băm bằng Regex"""
    parsed_vlans = {}
    # Regex này vẫn lấy chuẩn thông tin từ bảng đầu tiên của lệnh 'show vlan'
    pattern = re.compile(r"^(\d+)\s+(\S+)\s+(active|suspend)", re.MULTILINE)
    
    if not os.path.exists(file_path):
        print(f"[-] [VLAN SYNC] Không tìm thấy file {file_path}")
        return parsed_vlans

    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
        
    for match in pattern.finditer(content):
        vlan_id = int(match.group(1))
        if 1002 <= vlan_id <= 1005: # Bỏ qua VLAN mặc định của Cisco
            continue
            
        parsed_vlans[vlan_id] = {
            "name": match.group(2),
            "state": match.group(3)
        }
    return parsed_vlans

def sync_vlan_worker(host_ip: str):
    """Đọc dữ liệu đã băm và đồng bộ vào Database (Có dọn rác Duplicate)"""
    file_path = os.path.join(L2_BACKUP_DIR, host_ip, f"{host_ip}_vlan.txt")
    parsed_vlans = parse_vlan_file(file_path)
    
    if not parsed_vlans:
        return

    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    
    try:
        # Ép key thành chuỗi (String) để né lỗi so sánh của Python
        parsed_str = {str(k): v for k, v in parsed_vlans.items()}
        
        c.execute(f"SELECT vlan_id, id FROM {TBL_VLAN} WHERE host=?", (host_ip,))
        db_rows = c.fetchall()
        
        db_vlan_map = {}
        for v_id_raw, db_id in db_rows:
            v_str = str(v_id_raw)
            if v_str not in db_vlan_map:
                db_vlan_map[v_str] = []
            db_vlan_map[v_str].append(db_id)
        
        db_vlan_ids = set(db_vlan_map.keys())
        run_vlan_ids = set(parsed_str.keys())
        
        # [A] Xóa VLAN (Có trong DB nhưng Switch không có)
        for v_id in (db_vlan_ids - run_vlan_ids):
            if v_id != "1": 
                for db_id in db_vlan_map[v_id]:
                    c.execute(f"DELETE FROM {TBL_VLAN} WHERE id=?", (db_id,))
        
        # [B] Thêm VLAN mới
        for v_id in (run_vlan_ids - db_vlan_ids):
            data = parsed_str[v_id]
            c.execute(f"INSERT INTO {TBL_VLAN} (host, vlan_id, vlan_name, state) VALUES (?, ?, ?, ?)", 
                      (host_ip, int(v_id), data['name'], data['state']))
            
        # [C] Cập nhật VLAN & Dọn rác
        for v_id in (db_vlan_ids & run_vlan_ids):
            data = parsed_str[v_id]
            ids = db_vlan_map[v_id]
            
            primary_id = ids[0]
            c.execute(f"UPDATE {TBL_VLAN} SET vlan_name=?, state=? WHERE id=?", 
                      (data['name'], data['state'], primary_id))
            
            for extra_id in ids[1:]:
                c.execute(f"DELETE FROM {TBL_VLAN} WHERE id=?", (extra_id,))
                
        conn.commit()
        print(f"[+] [VLAN SYNC] Đã đồng bộ thành công VLAN từ file cho {host_ip}")
    except Exception as e:
        conn.rollback()
        print(f"[-] [VLAN SYNC LỖI] {e}")
    finally:
        conn.close()