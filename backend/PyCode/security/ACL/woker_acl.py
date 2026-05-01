import os
import yaml
import sys
import sqlite3
import urllib3
from jinja2 import Environment, FileSystemLoader

from nornir import InitNornir
from nornir_netmiko.tasks import netmiko_send_config

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# =========================================================
# VĂN MẪU: BẬT RADAR TÌM GỐC DỰ ÁN
# =========================================================
CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(CURRENT_DIR, "../../.."))
if PROJECT_ROOT not in sys.path: sys.path.append(PROJECT_ROOT)

from PyCode.share.config import TMP_DIR

# =========================================================
# 1. TRÍCH XUẤT VÀ NẶN DATA TỪ DB CHO JINJA2 (CONTROLLER)
# =========================================================
def _format_rule_to_dict(rule_tuple, acl_type='extended'):
    """
    Hàm này có nhiệm vụ duy nhất: Đọc data từ Tuple (DB), 
    ép các giá trị rác thành chuỗi rỗng "", và gắn nhãn biến (Dictionary).
    KHÔNG xử lý logic ghép chữ ở đây nữa!
    """
    #Ép 'none', 'NULL' hoặc khoảng trắng thành chuỗi rỗng ""
    r = ["" if str(x).strip().lower() in ['none', 'null', ''] else str(x).strip() for x in rule_tuple]
    
    # Đóng gói biến đẩy sang Jinja2 tùy theo loại ACL
    if acl_type == 'dynamic':
        return {"seq": r[2], 
                "action": r[3], 
                "protocol": r[4], 
                "src": r[5], 
                "src_mask": r[6], 
                "src_port": r[7], 
                "dst": r[8], 
                "dst_mask": r[9], 
                "dst_port": r[10], 
                "dyn_name": r[11], 
                "timeout": r[12]}
        
    elif acl_type == 'mac':
        return {"seq": r[2], 
                "action": r[3], 
                "src_mac": r[4], 
                "src_mask": r[5], 
                "dst_mac": r[6], 
                "dst_mask": r[7], 
                "ethertype": r[8]}
        
    elif acl_type == 'reflexive':
        return {"seq": r[2], 
                "action": r[3], 
                "protocol": r[4], 
                "src": r[5], 
                "src_mask": r[6], 
                "src_port": r[7], 
                "dst": r[8], 
                "dst_mask": r[9], 
                "dst_port": r[10], 
                "reflect_name": r[11], 
                "timeout": r[12]}
        
    elif acl_type == 'standard':
        return {"seq": r[2], "action": r[3], "src": r[4], "src_mask": r[5]}
        
    else: # Extended mặc định
        return {"seq": r[2], 
                "action": r[3], 
                "protocol": r[4], 
                "src": r[5], 
                "src_mask": r[6], 
                "src_port": r[7], 
                "dst": r[8], 
                "dst_mask": r[9], 
                "dst_port": r[10]}


def build_acl_payload(db_path, acl_id):
    """
    Gom data từ Database và xây dựng gói Payload hoàn chỉnh đưa cho Nornir
    """
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT acl_name, acl_type, success, action_Cfg, description FROM ACL_DB WHERE Acl_id = ?", (acl_id,))
        row = cursor.fetchone()
        if not row: return None
        
        acl_name, acl_type, success_db, action_cfg, desc = row
        rule_table = f"{acl_type.lower()}_acl_rules"

        payload = {
            "acl_id": acl_id, "acl_name": acl_name, "acl_type": acl_type.lower(),
            "action": "", "update_remark": False, "remark": desc,
            "rules_del": [], "rules_add": [], 
            "tracking_ids": {"del": [], "add": []}
        }

        if success_db == -1:
            payload["action"] = "delete"
            return payload

        cursor.execute(f"SELECT * FROM {rule_table} WHERE acl_id = ? ORDER BY sequence ASC", (acl_id,))
        all_rules = cursor.fetchall()

        pending_del = [r for r in all_rules if r[-1] == -1]
        pending_add = [r for r in all_rules if r[-1] == 0]
        done_rules  = [r for r in all_rules if r[-1] == 1]

        is_new_acl = (len(done_rules) == 0 and len(pending_add) > 0)
        payload["action"] = "set" if is_new_acl else "change"
        
        # CHỈ CẬP NHẬT REMARK NẾU KHÔNG PHẢI MAC ACL
        if (action_cfg & 1) == 1 and payload["acl_type"] != 'mac':
            payload["update_remark"] = True
        
        # Nạp Dictionary vào danh sách xóa/thêm
        for r in pending_del:
            payload["rules_del"].append(_format_rule_to_dict(r, payload["acl_type"]))
            payload["tracking_ids"]["del"].append(r[0])
            
        for r in pending_add:
            payload["rules_add"].append(_format_rule_to_dict(r, payload["acl_type"]))
            payload["tracking_ids"]["add"].append(r[0])

        return payload
    except Exception as e:
        print(f"[-] Lỗi Build ACL Payload: {e}")
        return None
    finally:
        conn.close()

# =========================================================
# 2. XỬ LÝ TEMPLATE VÀ ĐẨY LỆNH (NORNIR TASK)
# =========================================================
def task_push_acl(task):
    payload = task.host.data["ui_payload"]
    acl_type = payload['acl_type']
    
    # Chuẩn hóa file template: dynamic/reflexive đều dùng syntax của extended.j2
    tpl_name = 'extended' if acl_type in ['dynamic', 'reflexive'] else acl_type
    
    # Nạp template Jinja2
    template_dir = os.path.abspath(os.path.join(PROJECT_ROOT, "PyCode", "security", "ACL", "Templates", task.host.data['template_folder']))
    env = Environment(loader=FileSystemLoader(template_dir))
    template = env.get_template(f"{tpl_name}.j2")
    commands_str = template.render(**payload)
    
    # Lọc các dòng trống và loại bỏ các dòng comment có dấu !
    cmds = [l.strip() for l in commands_str.splitlines() if l.strip() and not l.strip().startswith('!')]
    
    if not cmds: return "No commands."
    
    print(f"\n[DEBUG] Lệnh đẩy xuống {task.host.hostname} (ACL_ID {payload['acl_id']}):")
    print("\n".join(cmds))

    # Tắt log console để Netmiko đọc output không bị nhiễu do bản tin Syslog
    cmds.insert(0, "no logging console")
    
    # Bắn thẳng mảng lệnh vào Router
    res = task.run(task=netmiko_send_config, config_commands=cmds, read_timeout=120, cmd_verify=False)
    return res[0].result

# =========================================================
# 3. UPDATE DATABASE SAU KHI THÀNH CÔNG (SUCCESS = 1)
# =========================================================
def update_db_after_success(db_path, payload):
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    try:
        a_id = payload["acl_id"]
        table = f"{payload['acl_type']}_acl_rules"

        if payload["action"] == "delete":
            cursor.execute(f"DELETE FROM {table} WHERE acl_id = ?", (a_id,))
            cursor.execute("DELETE FROM ACL_DB WHERE Acl_id = ?", (a_id,))
        else:
            for r_id in payload["tracking_ids"]["del"]: 
                cursor.execute(f"DELETE FROM {table} WHERE id = ?", (r_id,))
            for r_id in payload["tracking_ids"]["add"]: 
                cursor.execute(f"UPDATE {table} SET success = 1 WHERE id = ?", (r_id,))
            
            cursor.execute("UPDATE ACL_DB SET success = 1, action_Cfg = 0 WHERE Acl_id = ?", (a_id,))
            
        conn.commit()
    except Exception as e:
        print(f"[-] Lỗi Update DB: {e}")
    finally:
        conn.close()

# =========================================================
# 3.5. UPDATE DATABASE SAU KHI THẤT BẠI (ROLLBACK TỰ ĐỘNG)
# =========================================================
def update_db_after_fail(db_path, payload):
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    try:
        a_id = payload["acl_id"]
        table = f"{payload['acl_type']}_acl_rules"

        # 1. Xóa trắng các Rule đang định thêm
        for r_id in payload["tracking_ids"]["add"]: 
            cursor.execute(f"DELETE FROM {table} WHERE id = ?", (r_id,))
            
        # 2. Trả lại cờ success cho các Rule đang định xóa
        for r_id in payload["tracking_ids"]["del"]: 
            cursor.execute(f"UPDATE {table} SET success = 1 WHERE id = ?", (r_id,))
            
        cursor.execute("UPDATE ACL_DB SET success = 1 WHERE Acl_id = ?", (a_id,))
        conn.commit()
    except Exception as e:
        print(f"[-] Lỗi Update DB (Rollback Fail): {e}")
    finally:
        conn.close()

# =========================================================
# 4. HÀM RUNNER CHÍNH (ĐIỀU PHỐI WORKER)
# =========================================================
def build_inventory(db_path, target_ip, payloads):
    hosts_yaml = {}
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    cursor.execute('SELECT device_name, username, password, os, portnumber, method FROM devices WHERE host = ?', (target_ip,))
    row = cursor.fetchone()
    conn.close()
    
    if row:
        dev_name, db_user, db_pass, db_os, db_port, db_method = row
        platform = "cisco_ios" if db_os == "cisco" else db_os
        tpl_folder = "cisco_ios" if platform == "cisco_ios_telnet" else platform
        
        hosts_yaml[dev_name or target_ip] = {
            "hostname": target_ip, "username": db_user, "password": db_pass,
            "port": int(db_port) if db_port else (23 if db_method == "TELNET" else 22), 
            "platform": platform,
            "connection_options": {"netmiko": {"extras": {"global_delay_factor": 2}}},
            "data": {"template_folder": tpl_folder, "payloads": payloads}
        }
    
    inv_file = os.path.join(TMP_DIR, "tmp_acl_inventory.yaml")
    with open(inv_file, 'w', encoding='utf-8') as f: yaml.dump(hosts_yaml, f)
    return inv_file

def run_acl_worker(target_ip, acl_ids, db_path):
    print(f"\n[INFO] Khởi động ACL Worker (Jinja2) cho {target_ip}...")
    
    payloads = [p for p in (build_acl_payload(db_path, a_id) for a_id in acl_ids) if p]
    if not payloads: return
    
    inv_file = build_inventory(db_path, target_ip, payloads)
    
    nr = InitNornir(
        runner={"plugin": "threaded", "options": {"num_workers": 5}}, 
        inventory={"plugin": "SimpleInventory", "options": {"host_file": inv_file}}, 
        logging={"enabled": False}
    )
    
    for payload in payloads:
        print(f"\n[*] Đang thực thi ACL: {payload['acl_name']} (ID {payload['acl_id']} | Type: {payload['acl_type'].upper()})")
        for h in nr.inventory.hosts.values(): h.data["ui_payload"] = payload
        
        results = nr.run(task=task_push_acl)
        
        for host, task_res in results.items():
            if task_res.failed:
                print(f"[-] LỖI KẾT NỐI trên {host}: {task_res.exception}")
            else:
                output_log = str(task_res.result)
                cisco_errors = ["% Invalid input", "% Incomplete command", "% Ambiguous command", "% Bad mask"]
                has_syntax_error = any(error in output_log for error in cisco_errors)
                
                if has_syntax_error:
                    print(f"[-] LỖI CÚ PHÁP TỪ ROUTER {host} TỪ CHỐI LỆNH!")
                    print(f"    Chi tiết Router báo: \n{output_log}")
                    print(f"[-] ĐÃ KÍCH HOẠT TỰ ĐỘNG ROLLBACK: XÓA LỆNH LỖI KHỎI DATABASE!")
                    update_db_after_fail(db_path, payload)
                else:
                    print(f"[+] Thành công trên {host}! Thiết bị đã nhận lệnh. Đang cập nhật DB...")
                    update_db_after_success(db_path, payload)

    if os.path.exists(inv_file): os.remove(inv_file)