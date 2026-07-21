import os
import re
from backend.PyCode.share.config import get_db_connection, DB_TABLES, L2_BACKUP_DIR

TBL_VLAN = DB_TABLES["l2_vlan"]["main"]

def sync_l2_vlan_worker(host_ip: str):
    """Chỉ đọc file text _vlan.txt offline và băm dữ liệu vào DB"""
    file_path = os.path.join(L2_BACKUP_DIR, host_ip, f"{host_ip}_vlan.txt")
    if not os.path.exists(file_path):
        print(f"[-] [SYNC VLAN] Không tìm thấy file {file_path}")
        return

    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Băm Regex
    parsed_vlans = {}
    pattern = re.compile(r"^(\d+)\s+(\S+)\s+(active|suspend)", re.MULTILINE)
    for match in pattern.finditer(content):
        vlan_id = int(match.group(1))
        if 1002 <= vlan_id <= 1005: 
            continue
        parsed_vlans[vlan_id] = {"name": match.group(2), "state": match.group(3)}

    # Cập nhật Database
    conn = get_db_connection()
    c = conn.cursor()
    try:
        c.execute(f"SELECT vlan_id, id FROM {TBL_VLAN} WHERE host=?", (host_ip,))
        db_vlans = {row[0]: row[1] for row in c.fetchall()}

        db_vlan_ids = set(db_vlans.keys())
        run_vlan_ids = set(parsed_vlans.keys())

        # [A] Xóa
        for v_id in (db_vlan_ids - run_vlan_ids):
            if v_id != 1: c.execute(f"DELETE FROM {TBL_VLAN} WHERE id=?", (db_vlans[v_id],))

        # [B] Thêm mới
        for v_id in (run_vlan_ids - db_vlan_ids):
            data = parsed_vlans[v_id]
            c.execute(f"INSERT INTO {TBL_VLAN} (host, vlan_id, vlan_name, state) VALUES (?, ?, ?, ?)", 
                      (host_ip, v_id, data['name'], data['state']))

        # [C] Cập nhật
        for v_id in (db_vlan_ids & run_vlan_ids):
            data = parsed_vlans[v_id]
            c.execute(f"UPDATE {TBL_VLAN} SET vlan_name=?, state=? WHERE id=?", 
                      (data['name'], data['state'], db_vlans[v_id]))

        conn.commit()
        print(f"  [+] [VLAN SYNC] Đã đồng bộ thành công VLAN từ file cho {host_ip}")
    except Exception as e:
        conn.rollback()
        print(f"  [-] LỖI DATABASE KHI SYNC VLAN ({host_ip}): {e}")
    finally:
        conn.close()