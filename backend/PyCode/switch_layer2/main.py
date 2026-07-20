import os
import json
import sqlite3
from backend.PyCode.share.config import get_db_connection, DB_PATH, DB_TABLES, TMP_DIR
from backend.PyCode.switch_layer2.modules.vlan import run_vlan_worker

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

        # 2. Gom dữ liệu chờ xử lý (Quét toàn bộ VLAN của Host)
        for host in target_hosts:
            if feature == "vlan":
                # [SỬA Ở ĐÂY]: Bỏ cột success đi, lấy toàn bộ VLAN của thiết bị này
                c.execute(f"SELECT id, vlan_id, vlan_name, state FROM {TBL_VLAN} WHERE host = ?", (host,))
                vlan_records = c.fetchall()
                
                if not vlan_records: continue
                
                host_payload = {"target": host, "vlans": []}
                
                for r_id, v_id, v_name, v_state in vlan_records:
                    # Không cần check success nữa, mặc định action là 'setup'
                    host_payload["vlans"].append({
                        "vlan_id": v_id, "vlan_name": v_name, "state": v_state, "action": "setup"
                    })
                
                valid_data.append(host_payload)

        # 3. Kích hoạt Nornir Worker
        if not valid_data:
            print("[INFO] Không có dữ liệu VLAN nào để xử lý.")
            return

        run_vlan_worker(valid_data, DB_PATH, L2_OUTPUT)

        # 4. In kết quả (Close-loop không cần UPDATE DB)
        if os.path.exists(L2_OUTPUT):
            with open(L2_OUTPUT, 'r', encoding='utf-8') as f:
                out_results = json.load(f)

            for res in out_results:
                ip = res.get("target")
                status_text = "THÀNH CÔNG" if res.get("status") == "success" else "THẤT BẠI"
                print(f"[*] Push VLAN cho {ip}: {status_text}")
                
            # KHÔNG CẦN đoạn c.execute(UPDATE...) nữa vì DB không có cột success
            print("[*] Đã hoàn tất luồng đẩy cấu hình VLAN.")

        # 3. Kích hoạt Nornir Worker
        if not valid_data:
            print("[INFO] Không có dữ liệu VLAN chờ xử lý.")
            return

        run_vlan_worker(valid_data, DB_PATH, L2_OUTPUT)

        # 4. In kết quả (Close-loop không cần UPDATE DB)
        if os.path.exists(L2_OUTPUT):
            with open(L2_OUTPUT, 'r', encoding='utf-8') as f:
                out_results = json.load(f)

            for res in out_results:
                ip = res.get("target")
                status = res.get("status")
                
                if status == "success":
                    print(f"[*] Push VLAN cho {ip}: THÀNH CÔNG")
                else:
                    msg = res.get('message', 'Không rõ lỗi')
                    print(f"[-] Push VLAN cho {ip}: THẤT BẠI - Lỗi: {msg}")

            # KHÔNG CÒN VÒNG LẶP UPDATE DB NÀO Ở ĐÂY NỮA
            print("\n[*] Đã hoàn tất luồng đẩy cấu hình VLAN.")

    except Exception as e:
        print(f"[-] LỖI L2 DISPATCHER: {e}")
    finally:
        if 'conn' in locals(): 
            conn.close()