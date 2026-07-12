import sqlite3

# IMPORT ĐỘNG TỪ CONFIG.PY
from backend.PyCode.share.config import DB_TABLES

# Lấy tên bảng OSPF thông qua dict DB_TABLES ("t04_ospf_processes" và "t04_ospf_networks")
TBL_OSPF_PROC = DB_TABLES["routing_ospf"]["processes"]
TBL_OSPF_NET = DB_TABLES["routing_ospf"]["networks"]

PROC_COL_ID = "ospf_id" 
PROC_COL_HOST = "host"
PROC_COL_PID = "process_id"
PROC_COL_RID = "router_id"
PROC_COL_DEF_ORIG = "default_originate"
PROC_COL_DEF_ALW = "default_originate_always"
PROC_COL_SUC = "success"

NET_COL_ID = "id" 
NET_COL_OSPF_ID = "ospf_id" 
NET_COL_NET = "network"
NET_COL_WILD = "wildcard"
NET_COL_AREA = "area"
NET_COL_SUC = "success"

def sync_ospf_worker(host_ip: str, parse_obj, db_path: str):
    parsed_processes = {}
    
    for ospf_obj in parse_obj.find_objects(r"^router ospf "):
        pid = int(ospf_obj.text.split("router ospf ")[-1].strip())
        
        rid_obj = ospf_obj.re_search_children(r"^\s+router-id ")
        router_id = rid_obj[0].text.split("router-id ")[-1].strip() if rid_obj else None
        
        def_orig_obj = ospf_obj.re_search_children(r"^\s+default-information originate")
        def_orig = 1 if def_orig_obj else 0
        always = 1 if def_orig_obj and "always" in def_orig_obj[0].text else 0
        
        networks = []
        for net_obj in ospf_obj.re_search_children(r"^\s+network "):
            parts = net_obj.text.strip().split()
            if len(parts) >= 5:
                networks.append({
                    'network': parts[1],
                    'wildcard': parts[2],
                    'area': int(parts[4])
                })
                
        parsed_processes[pid] = {
            'router_id': router_id,
            'default_originate': def_orig,
            'default_originate_always': always,
            'networks': networks
        }

    conn = sqlite3.connect(db_path)
    conn.execute("PRAGMA foreign_keys = ON;")
    c = conn.cursor()
    
    try:
        c.execute(f"SELECT {PROC_COL_PID}, {PROC_COL_ID} FROM {TBL_OSPF_PROC} WHERE {PROC_COL_HOST}=?", (host_ip,))
        db_pids_map = {row[0]: row[1] for row in c.fetchall()}
        
        db_pids = set(db_pids_map.keys())
        run_pids = set(parsed_processes.keys())
        
        for pid in (db_pids - run_pids):
            ospf_id = db_pids_map[pid]
            c.execute(f"DELETE FROM {TBL_OSPF_NET} WHERE {NET_COL_OSPF_ID}=?", (ospf_id,))
            c.execute(f"DELETE FROM {TBL_OSPF_PROC} WHERE {PROC_COL_ID}=?", (ospf_id,))
            
        for pid in (run_pids - db_pids):
            data = parsed_processes[pid]
            c.execute(f"""
                INSERT INTO {TBL_OSPF_PROC} 
                ({PROC_COL_HOST}, {PROC_COL_PID}, {PROC_COL_RID}, {PROC_COL_DEF_ORIG}, {PROC_COL_DEF_ALW}, {PROC_COL_SUC}) 
                VALUES (?, ?, ?, ?, ?, 1)
            """, (host_ip, pid, data['router_id'], data['default_originate'], data['default_originate_always']))
            
            new_ospf_id = c.lastrowid
            
            for net in data['networks']:
                c.execute(f"""
                    INSERT INTO {TBL_OSPF_NET} 
                    ({NET_COL_OSPF_ID}, {NET_COL_NET}, {NET_COL_WILD}, {NET_COL_AREA}, {NET_COL_SUC}) 
                    VALUES (?, ?, ?, ?, 1)
                """, (new_ospf_id, net['network'], net['wildcard'], net['area']))
                
        for pid in (db_pids & run_pids):
            data = parsed_processes[pid]
            ospf_id = db_pids_map[pid]
            
            c.execute(f"""
                UPDATE {TBL_OSPF_PROC} 
                SET {PROC_COL_RID}=?, {PROC_COL_DEF_ORIG}=?, {PROC_COL_DEF_ALW}=?, {PROC_COL_SUC}=1 
                WHERE {PROC_COL_ID}=?
            """, (data['router_id'], data['default_originate'], data['default_originate_always'], ospf_id))
            
            c.execute(f"SELECT {NET_COL_ID}, {NET_COL_NET}, {NET_COL_WILD}, {NET_COL_AREA} FROM {TBL_OSPF_NET} WHERE {NET_COL_OSPF_ID}=?", (ospf_id,))
            db_nets = {(row[1], row[2], int(row[3])): row[0] for row in c.fetchall()}
            run_nets = set((n['network'], n['wildcard'], n['area']) for n in data['networks'])
            
            db_net_keys = set(db_nets.keys())
            
            for net in (db_net_keys - run_nets):
                c.execute(f"DELETE FROM {TBL_OSPF_NET} WHERE {NET_COL_ID}=?", (db_nets[net],))
            for net in (run_nets - db_net_keys):
                c.execute(f"""
                    INSERT INTO {TBL_OSPF_NET} 
                    ({NET_COL_OSPF_ID}, {NET_COL_NET}, {NET_COL_WILD}, {NET_COL_AREA}, {NET_COL_SUC}) 
                    VALUES (?, ?, ?, ?, 1)
                """, (ospf_id, net[0], net[1], net[2]))
            for net in (db_net_keys & run_nets):
                c.execute(f"UPDATE {TBL_OSPF_NET} SET {NET_COL_SUC}=1 WHERE {NET_COL_ID}=?", (db_nets[net],))

        conn.commit()
        print(f"[+] OSPF Worker: Đồng bộ thành công {TBL_OSPF_PROC} cho {host_ip}")
        
    except Exception as e:
        print(f"[-] OSPF Worker LỖI: {e}")
        conn.rollback()
    finally:
        conn.close()