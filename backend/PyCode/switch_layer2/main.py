import os
import json
import sqlite3

from backend.PyCode.switch_layer2.modules.stp import run_stp_worker
from backend.PyCode.share.config import get_db_connection, DB_PATH, DB_TABLES, TMP_DIR, STATE_DIR
from backend.PyCode.share.config import get_db_connection, DB_PATH, DB_TABLES, TMP_DIR
from backend.PyCode.switch_layer2.modules.vlan import run_vlan_worker
from backend.PyCode.switch_layer2.modules.interface_l2 import run_interface_worker
from backend.PyCode.switch_layer2.modules.vtp import run_vtp_worker
L2_OUTPUT = os.path.join(TMP_DIR, "l2_output_log.json")

TBL_STP_GLOBAL = DB_TABLES["l2_stp"]["global"]
TBL_STP_IFACE = DB_TABLES["l2_stp"]["interface"]
TBL_DEVICES = DB_TABLES["device_info"]["main"]
TBL_VLAN = DB_TABLES["l2_vlan"]["main"]
TBL_IFACE = DB_TABLES["l2_interfaces"]["main"]
TBL_ACC = DB_TABLES["l2_interfaces"]["access"]
TBL_TRUNK = DB_TABLES["l2_interfaces"]["trunk"]
TBL_PO = DB_TABLES["l2_etherchannel"]["main"]
TBL_VTP_DOMAINS = DB_TABLES["l2_vtp"]["domains"]
TBL_VTP_SWITCHES = DB_TABLES["l2_vtp"]["switches"]
TBL_VTP_MODES = DB_TABLES["l2_vtp"]["modes"]

def l2_dispatcher(target: str = "all", feature: str = "vlan"):
    print(f"\n[*] [L2 Master] Target: {target} | Feature: {feature.upper()}")
    
    valid_data = []
    # Biến này để "nhớ tạm" toàn bộ cấu hình lấy từ DB, chỉ ghi ra file NẾU đẩy thành công
    full_db_snapshot = {} 
    
    try:
        conn = get_db_connection()
        c = conn.cursor()
        
        # 1. Lọc mục tiêu Switch
        if target.lower() == "all":
            c.execute(f"SELECT host FROM {TBL_DEVICES} WHERE TRIM(LOWER(role)) IN ('sw2', 'sw3') OR LOWER(role) LIKE '%sw%'")
            target_hosts = [row[0] for row in c.fetchall()]
        else:
            target_hosts = [target]

        # 2. Gom dữ liệu chờ xử lý
        for host in target_hosts:
            
            # ================= [ NHÁNH 1: XỬ LÝ VLAN ] =================
            if feature == "vlan":
                c.execute(f"SELECT id, vlan_id, vlan_name, state FROM {TBL_VLAN} WHERE host = ?", (host,))
                vlan_records = c.fetchall()
                if not vlan_records: continue
                
                # 1. Gom dữ liệu từ Letos DB
                full_vlans = []
                for r_id, v_id, v_name, v_state in vlan_records:
                    full_vlans.append({"vlan_id": v_id, "vlan_name": v_name, "state": v_state})
                
                # Lưu Full Data vào biến tạm chờ ghi file
                full_db_snapshot[host] = full_vlans

                # 2. Đọc Snapshot cũ để so sánh
                state_file = os.path.join(STATE_DIR, f"{host}_vlan_state.json")
                last_state = []
                if os.path.exists(state_file):
                    with open(state_file, 'r', encoding='utf-8') as f:
                        last_state = json.load(f)

                # Chuyển state cũ thành Dictionary với Key là vlan_id để tra cứu
                last_state_dict = {str(v["vlan_id"]): v for v in last_state}

                vlans_to_push = []
                for curr_vlan in full_vlans:
                    v_id_str = str(curr_vlan["vlan_id"])
                    last_vlan = last_state_dict.get(v_id_str)

                    # Tự động so sánh: Khác tên, khác state hoặc vlan mới thì mang đi Push
                    if not last_vlan or curr_vlan != last_vlan:
                        vlans_to_push.append(curr_vlan)

                if not vlans_to_push:
                    print(f"[*] [SKIP] Không có thay đổi VLAN nào trên {host}. Bỏ qua cấu hình!")
                    continue

                # Đóng gói Payload chuẩn bị ném cho Nornir
                host_payload = {"target": host, "vlans": vlans_to_push}
                valid_data.append(host_payload)

            # ================= [ NHÁNH 2: XỬ LÝ INTERFACE ] =================
            elif feature == "interface":
                c.execute(f"""
                    SELECT i.id, i.if_name, i.description, i.mode, i.admin_status, i.speed, i.duplex,
                           a.access_vlan, a.voice_vlan,
                           t.allowed_vlans, t.native_vlan, t.encapsulation
                    FROM {TBL_IFACE} i
                    LEFT JOIN {TBL_ACC} a ON i.id = a.iface_id
                    LEFT JOIN {TBL_TRUNK} t ON i.id = t.iface_id
                    WHERE i.host = ?
                """, (host,))
                iface_records = c.fetchall()
                if not iface_records: continue

                c.execute(f"SELECT po_number, protocol, mode, member_ports FROM {TBL_PO} WHERE host = ?", (host,))
                po_records = c.fetchall()

                # Tự điển chứa cấu hình gốc lấy từ DB (Ý định của sếp)
                full_interfaces = []
                
                for r in iface_records:
                    iface_dict = {
                        "if_name": r[1], "description": r[2], "mode": r[3], "admin_status": r[4], 
                        "speed": r[5], "duplex": r[6], "access_vlan": r[7], "voice_vlan": r[8],
                        "allowed_vlans": r[9], "native_vlan": r[10], "encapsulation": r[11],
                        "channel_group": "None", "channel_protocol": "None", "channel_group_mode": "None"
                    }
                    
                    for po_num, po_proto, po_mode, members in po_records:
                        if members and iface_dict["if_name"] in members.split(','):
                            iface_dict["channel_group"] = po_num
                            iface_dict["channel_protocol"] = po_proto if po_proto != 'static' else 'None'
                            iface_dict["channel_group_mode"] = po_mode
                            break 
                            
                    full_interfaces.append(iface_dict)

                # Lưu full data vào biến tạm, KHÔNG ĐƯỢC LƯU FILE LÚC NÀY
                full_db_snapshot[host] = full_interfaces

                # --- ĐỌC SNAPSHOT CŨ ĐỂ SO SÁNH ---
                state_file = os.path.join(STATE_DIR, f"{host}_iface_state.json")
                last_state = []
                if os.path.exists(state_file):
                    with open(state_file, 'r', encoding='utf-8') as f:
                        last_state = json.load(f)

                # Chuyển đổi để dễ tra cứu theo tên cổng
                last_state_dict = {iface["if_name"]: iface for iface in last_state}

                interfaces_to_push = []
                for curr_iface in full_interfaces:
                    if_name = curr_iface["if_name"]
                    last_iface = last_state_dict.get(if_name)

                    # Tự động bắt sự khác biệt
                    if not last_iface or curr_iface != last_iface:
                        interfaces_to_push.append(curr_iface)

                if not interfaces_to_push:
                    print(f"[*] [SKIP] Không có thay đổi trên {host}. Bỏ qua cấu hình!")
                    continue

                # Chỉ nạp cổng bị thay đổi cho Nornir
                host_payload = {"target": host, "interfaces": interfaces_to_push}
                valid_data.append(host_payload)

        # ================= [ NHÁNH 3: XỬ LÝ SPANNING TREE (STP) ] =================
            elif feature == "stp":
                # Kéo dữ liệu STP Global
                c.execute(f"SELECT vlan_id, stp_mode, priority, root_role FROM {TBL_STP_GLOBAL} WHERE host = ?", (host,))
                global_records = c.fetchall()
                
                # Kéo dữ liệu STP Interface 
                c.execute(f"""
                    SELECT i.if_name, s.portfast, s.bpduguard, s.bpdufilter, s.root_guard, s.loop_guard
                    FROM {TBL_STP_IFACE} s
                    JOIN {TBL_IFACE} i ON s.iface_id = i.id
                    WHERE i.host = ? 
                      AND i.if_name NOT IN ('GigabitEthernet0/0', 'Gi0/0', 'g0/0')
                """, (host,))
                iface_records = c.fetchall()

                # Nếu DB không có gì thì bỏ qua Switch này
                if not global_records and not iface_records: 
                    continue

                # Đóng gói dữ liệu hiện tại (Intent) từ DB
                curr_stp_state = {
                    "global": [{"vlan_id": r[0], "stp_mode": r[1], "priority": r[2], "root_role": r[3]} for r in global_records],
                    "interfaces": [{"if_name": r[0], "portfast": r[1], "bpduguard": r[2], "bpdufilter": r[3], "root_guard": r[4], "loop_guard": r[5]} for r in iface_records]
                }
                
                # Lưu Full Data vào biến tạm chờ ghi Snapshot
                full_db_snapshot[host] = curr_stp_state

                # --- ĐỌC SNAPSHOT CŨ ĐỂ SO SÁNH ---
                state_file = os.path.join(STATE_DIR, f"{host}_stp_state.json")
                last_state = {"global": [], "interfaces": []}
                if os.path.exists(state_file):
                    with open(state_file, 'r', encoding='utf-8') as f:
                        last_state = json.load(f)

                # Phân tích sự thay đổi (Diffing)
                global_to_push = [g for g in curr_stp_state["global"] if g not in last_state.get("global", [])]
                ifaces_to_push = [i for i in curr_stp_state["interfaces"] if i not in last_state.get("interfaces", [])]

                if not global_to_push and not ifaces_to_push:
                    print(f"[*] [SKIP] Không có cấu hình STP nào thay đổi trên {host}. Bỏ qua!")
                    continue

                # Đóng gói Payload nạp vào mảng valid_data để đưa cho Nornir
                host_payload = {
                    "target": host, 
                    "stp_globals": global_to_push, 
                    "stp_interfaces": ifaces_to_push
                }
                valid_data.append(host_payload)
            # ================= [ NHÁNH 4: XỬ LÝ VTP ] =================
            elif feature == "vtp":
                # Kéo dữ liệu VTP từ 3 bảng bằng JOIN (Lấy database_type = 'vlan' làm chuẩn)
                c.execute(f"""
                    SELECT d.domain_name, d.version, d.password_type, d.password_value,
                           s.pruning, m.mode
                    FROM {TBL_VTP_SWITCHES} s
                    JOIN {TBL_VTP_DOMAINS} d ON s.vtp_domain_id = d.vtp_domain_id
                    LEFT JOIN {TBL_VTP_MODES} m ON s.vtp_switch_id = m.vtp_switch_id AND m.database_type = 'vlan'
                    WHERE s.host = ?
                """, (host,))
                
                vtp_record = c.fetchone()
                if not vtp_record: 
                    continue # Nếu thiết bị không tham gia domain VTP nào thì bỏ qua

                # Đóng gói dữ liệu hiện tại (Intent)
                curr_vtp_state = {
                    "domain_name": vtp_record[0],
                    "version": vtp_record[1],
                    "password_type": vtp_record[2],
                    "password_value": vtp_record[3],
                    "pruning": vtp_record[4],
                    "mode": vtp_record[5] if vtp_record[5] else "transparent" # Mặc định an toàn
                }
                
                # Lưu Full Data vào biến tạm chờ ghi Snapshot
                full_db_snapshot[host] = curr_vtp_state

                # --- ĐỌC SNAPSHOT CŨ ĐỂ SO SÁNH ---
                state_file = os.path.join(STATE_DIR, f"{host}_vtp_state.json")
                last_state = {}
                if os.path.exists(state_file):
                    with open(state_file, 'r', encoding='utf-8') as f:
                        last_state = json.load(f)

                # Phân tích sự thay đổi (Diffing)
                if curr_vtp_state != last_state:
                    valid_data.append({"target": host, "vtp_data": curr_vtp_state})
                else:
                    print(f"[*] [SKIP] Không có cấu hình VTP nào thay đổi trên {host}. Bỏ qua!")
                    continue
# ===============================================================


        # 3. Kích hoạt Nornir Worker
        if not valid_data:
            print(f"[INFO] Tất cả cấu hình đã đồng bộ, không cần đẩy lệnh.")
            return

        if feature == "vlan":
            run_vlan_worker(valid_data, DB_PATH, L2_OUTPUT)
        elif feature == "interface":
            run_interface_worker(valid_data, DB_PATH, L2_OUTPUT)
        elif feature == "stp":
            run_stp_worker(valid_data, DB_PATH, L2_OUTPUT)
        elif feature == "vtp":
            run_vtp_worker(valid_data, DB_PATH, L2_OUTPUT)

        # 4. In kết quả và KIỂM SOÁT VIỆC GHI SNAPSHOT (Đã fix lỗi gán cứng feature)
        if os.path.exists(L2_OUTPUT):
            with open(L2_OUTPUT, 'r', encoding='utf-8') as f:
                out_results = json.load(f)

            for res in out_results:
                ip = res.get("target")
                
                # BẮT BUỘC STATUS PHẢI LÀ SUCCESS THÌ MỚI LƯU
                if res.get("status") == "success":
                    print(f"[*] Push {feature.upper()} cho {ip}: THÀNH CÔNG")
                    
                    # Ghi đè file trạng thái mới nhất cho BẤT KỲ feature nào (vlan, interface, stp)
                    if ip in full_db_snapshot:
                        state_file = os.path.join(STATE_DIR, f"{ip}_{feature}_state.json")
                        with open(state_file, 'w', encoding='utf-8') as f:
                            json.dump(full_db_snapshot[ip], f)
                        print(f"  [+] Đã cập nhật Snapshot trạng thái mới cho {ip}")
                else:
                    # NẾU FAIL -> BỎ QUA GHI FILE.
                    print(f"[*] Push {feature.upper()} cho {ip}: THẤT BẠI ({res.get('message')})")
                    print(f"  [-] Giữ nguyên Snapshot cũ do cấu hình thất bại.")
        
                
            print(f"[*] Đã hoàn tất luồng đẩy cấu hình {feature.upper()}.")

    except Exception as e:
        print(f"[-] LỖI L2 DISPATCHER: {e}")
    finally:
        if 'conn' in locals(): 
            conn.close()