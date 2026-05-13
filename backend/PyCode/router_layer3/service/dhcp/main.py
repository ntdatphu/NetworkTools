import os
import sys
import json
import sqlite3
import argparse

# Setup radar đường dẫn
CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))
BACKEND_DIR = os.path.abspath(os.path.join(CURRENT_DIR, "..", "..", "..", ".."))

if BACKEND_DIR not in sys.path: sys.path.append(BACKEND_DIR)
if CURRENT_DIR not in sys.path: sys.path.append(CURRENT_DIR)

from PyCode.share.config import DB_PATH, DHCP_OUTPUT, TMP_DIR, DB_TABLES

try:
    from worker_dhcp import run_dhcp_config
except ImportError as e:
    print(f"[-] Lỗi Import Worker: {e}")
    sys.exit(1)

def success_state(val):
    if val in (0, '0', None): return "setup"
    if val in (-1, '-1'): return "remove"
    return "ignore"

def main():
    parser = argparse.ArgumentParser(description="DHCP Automation Controller")
    parser.add_argument("-t", "--target", type=str, default="all")
    args = parser.parse_args()
    
    target_ip = args.target
    T_DHCP_POOL = DB_TABLES.get("dhcp", {}).get("pools", "dhcp_pool")
    T_DHCP_EXC = DB_TABLES.get("dhcp", {}).get("excluded", "excluded_address")
    T_DHCP_RELAY = DB_TABLES.get("dhcp", {}).get("relays", "dhcp_relay") # Thêm bảng Relay
    
    valid_data = []
    
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        # Bốc host từ cả 3 bảng: Pool, Excluded và Relay
        query_hosts = f"""
            SELECT host FROM {T_DHCP_POOL} WHERE success <= 0 OR success IS NULL
            UNION SELECT host FROM {T_DHCP_EXC} WHERE success <= 0 OR success IS NULL
            UNION SELECT host FROM {T_DHCP_RELAY} WHERE success <= 0 OR success IS NULL
        """
        if target_ip != "all":
            query_hosts = f"SELECT host FROM ({query_hosts}) WHERE host = ?"
            cursor.execute(query_hosts, (target_ip,))
        else:
            cursor.execute(query_hosts)
            
        hosts = [row[0] for row in cursor.fetchall()]
        
        for host in hosts:
            config_data = {"pools": [], "excluded_addresses": [], "relays": []}
            ids = {"pool_add": [], "pool_del": [], "exc_add": [], "exc_del": [], "relay_add": [], "relay_del": []}
            
            # 1. Bốc Excluded
            cursor.execute(f"SELECT ex_id, start_ip, end_ip, success FROM {T_DHCP_EXC} WHERE host = ? AND (success <= 0 OR success IS NULL)", (host,))
            for ex_id, s_ip, e_ip, succ in cursor.fetchall():
                state = success_state(succ)
                config_data["excluded_addresses"].append({"start_ip": s_ip, "end_ip": e_ip, "state": state})
                if state == "remove": ids["exc_del"].append(ex_id)
                else: ids["exc_add"].append(ex_id)
                
            # 2. Bốc Pools
            cursor.execute(f"SELECT dhcp_id, pool, network, subnetmask, defaut, dns, success FROM {T_DHCP_POOL} WHERE host = ? AND (success <= 0 OR success IS NULL)", (host,))
            for p_id, p_name, net, mask, gw, dns, succ in cursor.fetchall():
                state = success_state(succ)
                config_data["pools"].append({"name": p_name, "network": net, "subnet_mask": mask, "default_gateway": gw, "dns_server": dns, "state": state})
                if state == "remove": ids["pool_del"].append(p_id)
                else: ids["pool_add"].append(p_id)

            # 3. Bốc Relay (IP Helper) - PHẦN MỚI THÊM
            try:
                cursor.execute(f"SELECT relay_id, interface_name, helper_address, success FROM {T_DHCP_RELAY} WHERE host = ? AND (success <= 0 OR success IS NULL)", (host,))
                for r_id, intf, h_ip, succ in cursor.fetchall():
                    state = success_state(succ)
                    config_data["relays"].append({"interface": intf, "helper_address": h_ip, "state": state})
                    if state == "remove": ids["relay_del"].append(r_id)
                    else: ids["relay_add"].append(r_id)
            except sqlite3.OperationalError: pass # Bỏ qua nếu bảng chưa tồn tại
                
            if any(ids.values()):
                valid_data.append({"target": {"ip": host}, "action": "setup", "ids": ids, "config": [config_data]})
                
        if not valid_data: return
        
        run_dhcp_config(valid_data, DB_PATH, DHCP_OUTPUT)
        
        # --- Cập nhật DB sau khi Worker chạy xong ---
        if os.path.exists(DHCP_OUTPUT):
            with open(DHCP_OUTPUT, 'r', encoding='utf-8') as f:
                results = json.load(f)
            for res in results:
                if res.get("status") == "success":
                    for item in valid_data:
                        if item["target"]["ip"] == res["target"]:
                            d = item["ids"]
                            for eid in d["exc_add"]: cursor.execute(f"UPDATE {T_DHCP_EXC} SET success = 1 WHERE ex_id = ?", (eid,))
                            for eid in d["exc_del"]: cursor.execute(f"DELETE FROM {T_DHCP_EXC} WHERE ex_id = ?", (eid,))
                            for pid in d["pool_add"]: cursor.execute(f"UPDATE {T_DHCP_POOL} SET success = 1 WHERE dhcp_id = ?", (pid,))
                            for pid in d["pool_del"]: cursor.execute(f"DELETE FROM {T_DHCP_POOL} WHERE dhcp_id = ?", (pid,))
                            for rid in d["relay_add"]: cursor.execute(f"UPDATE {T_DHCP_RELAY} SET success = 1 WHERE relay_id = ?", (rid,))
                            for rid in d["relay_del"]: cursor.execute(f"DELETE FROM {T_DHCP_RELAY} WHERE relay_id = ?", (rid,))
            conn.commit()
            print("[*] Đồng bộ DB thành công!")
    finally:
        if 'conn' in locals(): conn.close()

if __name__ == "__main__": main()