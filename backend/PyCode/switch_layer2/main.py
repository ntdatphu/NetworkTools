import os
import json
import sqlite3
from backend.PyCode.share.config import get_db_connection, DB_PATH, DB_TABLES, TMP_DIR
from backend.PyCode.switch_layer2.modules.vlan import run_vlan_worker
from backend.PyCode.switch_layer2.modules.interface_l2 import run_interface_worker

L2_OUTPUT = os.path.join(TMP_DIR, "l2_output_log.json")
TBL_DEVICES = DB_TABLES["device_info"]["main"]
TBL_VLAN = DB_TABLES["l2_vlan"]["main"]

def success_state(val):
    if val in (0, '0', 0.0, None): return "setup"
    if val in (-1, '-1', -1.0): return "remove"
    return "ignore"

def l2_dispatcher(target: str = "all", feature: str = "vlan"):
    print(f"\n[*] [L2 Master] Target: {target} | Feature: {feature.upper()}")
    
    valid_data = []
    
    try:
        conn = get_db_connection()
        c = conn.cursor()
        
        # 1. Lọc mục tiêu Switch
        if target.lower() == "all":
            c.execute(f"SELECT host FROM {TBL_DEVICES} WHERE TRIM(LOWER(role)) IN ('sw2', 'sw3') OR LOWER(role) LIKE '%sw%'")
            target_hosts = [row[0] for row in c.fetchall()]
        else:
            target_hosts = [target]

        # 2. Xử lý tùy theo Feature
        for host in target_hosts:
            # ==========================================
            # --- LUỒNG 1: VLAN ---
            # ==========================================
            if feature == "vlan":
                c.execute(f"SELECT id, vlan_id, vlan_name, state FROM {TBL_VLAN} WHERE host = ?", (host,))
                vlan_records = c.fetchall()
                if not vlan_records: continue
                
                host_payload = {"target": host, "vlans": [{"vlan_id": v[1], "vlan_name": v[2], "state": v[3], "action": "setup"} for v in vlan_records]}
                valid_data.append(host_payload)
                
            # ==========================================
            # --- LUỒNG 2: INTERFACE & ETHERCHANNEL ---
            # ==========================================
            elif feature == "interface":
                # A. Truy vấn thông tin cơ bản của cổng
                query = f"""
                SELECT i.if_name, i.description, i.admin_status, i.speed, i.duplex, i.mode,
                       a.access_vlan, a.voice_vlan, t.encapsulation, t.native_vlan, t.allowed_vlans
                FROM t06_interface_l2 i
                LEFT JOIN t06_iface_access a ON i.id = a.iface_id
                LEFT JOIN t06_iface_trunk t ON i.id = t.iface_id
                WHERE i.host = ?
                """
                c.execute(query, (host,))
                rows = c.fetchall()
                
                # B. Truy vấn riêng bảng EtherChannel (Tránh lỗi Join)
                c.execute(f"SELECT po_number, protocol, mode, member_ports FROM t06_etherchannel WHERE host = ?", (host,))
                ec_data = c.fetchall() 
                
                if not rows: continue
                
                ifaces = []
                for row in rows:
                    iface_dict = {
                        "if_name": row[0], "description": row[1], "admin_status": row[2], "speed": row[3], 
                        "duplex": row[4], "mode": row[5], "access_vlan": row[6], "voice_vlan": row[7],
                        "encapsulation": row[8], "native_vlan": row[9], "allowed_vlans": row[10]
                    }
                    
                    # C. Nối EtherChannel vào Interface bằng Python
                    for ec in ec_data:
                        po_num, proto, mode, members = ec
                        if members and iface_dict["if_name"] in members.split(','):
                            iface_dict["channel_group"] = po_num
                            iface_dict["channel_group_mode"] = mode
                            if proto:
                                iface_dict["channel_protocol"] = proto
                            break 
                    
                    ifaces.append(iface_dict)
                
                valid_data.append({"target": host, "interfaces": ifaces})

        # 3. Kiểm tra xem có data không
        if not valid_data:
            print(f"[INFO] Không có dữ liệu {feature.upper()} nào để xử lý cho {target}.")
            return

        # 4. Kích hoạt Nornir Worker tương ứng và In Log kết quả
        if feature == "vlan":
            run_vlan_worker(valid_data, DB_PATH, L2_OUTPUT)
            if os.path.exists(L2_OUTPUT):
                with open(L2_OUTPUT, 'r', encoding='utf-8') as f:
                    out_results = json.load(f)
                for res in out_results:
                    status_text = "THÀNH CÔNG" if res.get("status") == "success" else f"THẤT BẠI - {res.get('message')}"
                    print(f"[*] Push VLAN cho {res.get('target')}: {status_text}")
                    
        elif feature == "interface":
            iface_out = os.path.join(TMP_DIR, "iface_log.json")
            run_interface_worker(valid_data, DB_PATH, iface_out)
            if os.path.exists(iface_out):
                with open(iface_out, 'r', encoding='utf-8') as f:
                    out_results = json.load(f)
                
                # --- ĐOẠN ĐƯỢC CẬP NHẬT ĐỂ IN LOG CLI ---
                for res in out_results:
                    target_ip = res.get("target")
                    status = res.get("status")
                    msg = res.get("message", "Không có dữ liệu trả về.")
                    
                    if status == "success":
                        print(f"\n[*] Push Interface cho {target_ip}: THÀNH CÔNG")
                        print(f"=== CHI TIẾT LỆNH ĐÃ CHẠY TRÊN {target_ip} ===")
                        print(msg)  # In toàn bộ log màn hình CLI của Switch
                        print("==================================================")
                    else:
                        print(f"\n[-] Push Interface cho {target_ip}: THẤT BẠI")
                        print(f"=== CHI TIẾT LỖI ===")
                        print(msg)
                        print("====================")
                        
        print(f"\n[*] Đã hoàn tất luồng đẩy cấu hình {feature.upper()}.")

    except Exception as e:
        print(f"[-] LỖI L2 DISPATCHER: {e}")
    finally:
        if 'conn' in locals(): conn.close()