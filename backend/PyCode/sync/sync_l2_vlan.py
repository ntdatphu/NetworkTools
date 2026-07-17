import os
import re
import yaml
import sqlite3
from nornir import InitNornir
from nornir_netmiko.tasks import netmiko_send_command

# ZERO HARDCODE: Lấy mọi thứ từ config.py
from backend.PyCode.share.config import DB_TABLES, DB_PATH, TMP_DIR, L2_BACKUP_DIR

TBL_DEVICES = DB_TABLES["device_info"]["main"]
TBL_VLAN = DB_TABLES["l2_vlan"]["main"]

def parse_vlan_file(file_path: str) -> dict:
    """Đọc file text đã lưu và băm dữ liệu VLAN bằng Regex"""
    parsed_vlans = {}
    pattern = re.compile(r"^(\d+)\s+(\S+)\s+(active|suspend)", re.MULTILINE)
    
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
        
    for match in pattern.finditer(content):
        vlan_id = int(match.group(1))
        # Bỏ qua các VLAN nội bộ của Cisco
        if 1002 <= vlan_id <= 1005: 
            continue
            
        parsed_vlans[vlan_id] = {
            "name": match.group(2),
            "state": match.group(3)
        }
    return parsed_vlans

def sync_vlans_to_db(host_ip: str, parsed_vlans: dict):
    """So sánh dữ liệu từ file với Database và cập nhật"""
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    
    try:
        c.execute(f"SELECT vlan_id, id FROM {TBL_VLAN} WHERE host=?", (host_ip,))
        db_vlans = {row[0]: row[1] for row in c.fetchall()}
        
        db_vlan_ids = set(db_vlans.keys())
        run_vlan_ids = set(parsed_vlans.keys())
        
        # [A] Xóa VLAN (Chừa VLAN 1)
        for v_id in (db_vlan_ids - run_vlan_ids):
            if v_id != 1: 
                c.execute(f"DELETE FROM {TBL_VLAN} WHERE id=?", (db_vlans[v_id],))
        
        # [B] Thêm VLAN mới
        for v_id in (run_vlan_ids - db_vlan_ids):
            data = parsed_vlans[v_id]
            c.execute(f"INSERT INTO {TBL_VLAN} (host, vlan_id, vlan_name, state) VALUES (?, ?, ?, ?)", 
                      (host_ip, v_id, data['name'], data['state']))
            
        # [C] Cập nhật VLAN
        for v_id in (db_vlan_ids & run_vlan_ids):
            data = parsed_vlans[v_id]
            c.execute(f"UPDATE {TBL_VLAN} SET vlan_name=?, state=? WHERE id=?", 
                      (data['name'], data['state'], db_vlans[v_id]))
            
        conn.commit()
    except Exception as e:
        conn.rollback()
        raise e
    finally:
        conn.close()

def task_pull_and_sync_vlan(task):
    """Nhiệm vụ của Nornir trên mỗi Switch: Lệnh -> Ghi file -> Parse -> Sync"""
    host_ip = task.host.hostname
    
    # 1. Gõ lệnh qua SSH
    res = task.run(task=netmiko_send_command, command_string="show vlan brief", read_timeout=30)
    output_text = res[0].result
    
    # 2. Xả text ra file ở thư mục đã quy hoạch
    os.makedirs(L2_BACKUP_DIR, exist_ok=True)
    file_path = os.path.join(L2_BACKUP_DIR, f"{host_ip}_vlan.txt")
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(output_text)
        
    # 3. Băm dữ liệu từ file vừa ghi
    parsed_data = parse_vlan_file(file_path)
    
    # 4. Ghi đè vào DB
    sync_vlans_to_db(host_ip, parsed_data)
    
    return f"Đã ghi file {host_ip}_vlan.txt và đồng bộ {len(parsed_data)} VLAN vào DB."

def build_inventory_and_run(target_hosts: list):
    """Build inventory động từ DB và chạy Nornir"""
    hosts_yaml = {}
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    
    for ip in target_hosts:
        c.execute(f"SELECT device_name, username, password, os, portnumber FROM {TBL_DEVICES} WHERE host = ?", (ip,))
        row = c.fetchone()
        if row:
            hosts_yaml[row[0] or ip] = {
                "hostname": ip, "username": row[1], "password": row[2],
                "platform": "cisco_ios" if row[3] == "cisco" else row[3],
                "port": int(row[4]) if row[4] else 22
            }
    conn.close()
    
    if not hosts_yaml: return
    
    inv_file = os.path.join(TMP_DIR, "tmp_sync_l2_inventory.yaml")
    with open(inv_file, 'w', encoding='utf-8') as f: yaml.dump(hosts_yaml, f)
    
    nr = InitNornir(
        runner={"plugin": "threaded", "options": {"num_workers": 10}},
        inventory={"plugin": "SimpleInventory", "options": {"host_file": inv_file}},
        logging={"enabled": False}
    )
    
    print("\n[+] Đang SSH lấy bảng VLAN và đồng bộ...")
    results = nr.run(task=task_pull_and_sync_vlan)
    
    for host, res in results.items():
        if res.failed:
            print(f"[-] {host}: THẤT BẠI - {res.exception}")
        else:
            print(f"[+] {host}: {res[0].result}")
            
    if os.path.exists(inv_file): os.remove(inv_file)

def trigger_vlan_sync(target="all"):
    """Hàm kích hoạt từ bên ngoài"""
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    if target.lower() == "all":
        c.execute(f"SELECT host FROM {TBL_DEVICES} WHERE TRIM(LOWER(role)) IN ('sw2', 'sw3') OR LOWER(role) LIKE '%sw%'")
        targets = [row[0] for row in c.fetchall()]
    else:
        targets = [target]
    conn.close()
    
    if targets:
        build_inventory_and_run(targets)