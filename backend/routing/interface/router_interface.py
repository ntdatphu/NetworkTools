import os
import json
import yaml
import re
import ipaddress
import sqlite3
import requests
import urllib3
import urllib.parse
from ncclient import manager
from jinja2 import Environment, FileSystemLoader

# Tắt cảnh báo SSL cho gọn Terminal
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

try:
    from netmiko import ConnectHandler
except ImportError:
    print("[-] Lỗi: Chưa cài đặt thư viện Netmiko.")

from nornir import InitNornir
from nornir_netmiko.tasks import netmiko_send_config, netmiko_save_config, netmiko_send_command
from nornir.core.task import Result

# GỌI TRẠM RADAR LẤY ĐƯỜNG DẪN DATABASE
from backend.core_services.config import DB_PATH

CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))

# --- HÀM BỔ TRỢ ---
def netmask_to_cidr(network_str):
    try:
        if str(network_str).isdigit(): return int(network_str)
        return ipaddress.ip_network(f"0.0.0.0/{network_str}", strict=False).prefixlen
    except:
        return network_str

def parse_interface_name(intf_full_name):
    match = re.match(r"([a-zA-Z]+)([\d\./]+)", intf_full_name)
    if match: return match.group(1), match.group(2)
    return None, None

def render_interface_config(platform_folder, config_data, mode="setup", template_name="interface.j2"):
    template_dir = os.path.join(CURRENT_DIR, "templates", platform_folder)
    if not os.path.exists(template_dir): return None
    try:
        env = Environment(loader=FileSystemLoader(template_dir))
        return env.get_template(template_name).render(config=config_data, mode=mode, action=mode)
    except Exception as e:
        print(f"[-] Lỗi Render Template Interface ({template_name}): {e}")
        return None

# =========================================================
# XỬ LÝ RESTCONF
# =========================================================
def handle_restconf_interface(task, payload, mode, sub_type):
    host_ip, port = task.host.hostname, task.host.port or 443
    user, pw = task.host.username, task.host.password
    headers = {"Accept": "application/yang-data+json", "Content-Type": "application/yang-data+json"}
    results = []
    
    template_dir = os.path.join(CURRENT_DIR, "templates", task.host.data.get("template_folder", "cisco_ios"))
    env = Environment(loader=FileSystemLoader(template_dir))
    configs = payload.get("config", [])
    
    try:
        for config in configs:
            intf_name = config.get("name", "")
            intf_type, intf_id = parse_interface_name(intf_name)
            if not intf_type: continue
            intf_id_url = urllib.parse.quote(intf_id, safe='')
            base_url = f"https://{host_ip}:{port}/restconf/data/Cisco-IOS-XE-native:native/interface/{intf_type}={intf_id_url}"
            
            # --- LUỒNG 1: QUẢN LÝ IP ---
            if sub_type == "ip_address":
                if mode in ["delete", "remove"]:
                    url_v4 = f"{base_url}/ip/address/primary"
                    res = requests.delete(url_v4, auth=(user, pw), headers=headers, verify=False)
                    results.append(f"Xóa IP {intf_name}: {res.status_code}")
                else:
                    template_json = env.get_template('interface_restconf.j2')
                    payload_json = template_json.render(config=config, intf_type=intf_type, intf_id=intf_id)
                    res = requests.patch(base_url, auth=(user, pw), headers=headers, json=json.loads(payload_json), verify=False)
                    results.append(f"Set IP {intf_name}: {res.status_code}")
                    
            # --- LUỒNG 2: BẬT/TẮT CỔNG (PORT STATUS) ---
            elif sub_type == "port_status":
                if mode in ["delete", "shut", "disable"]:
                    template_json = env.get_template('port_status_restconf.j2')
                    payload_json = template_json.render(config=config, intf_type=intf_type, intf_id=intf_id)
                    res = requests.patch(base_url, auth=(user, pw), headers=headers, json=json.loads(payload_json), verify=False)
                    results.append(f"Shutdown {intf_name}: {res.status_code}")
                else:
                    res = requests.delete(f"{base_url}/shutdown", auth=(user, pw), headers=headers, verify=False)
                    results.append(f"No Shutdown {intf_name}: {res.status_code}")

            # --- LUỒNG 3: ĐỊNH TUYẾN TRÊN CỔNG (OSPF) ---
            elif sub_type == "routing_protocol":
                ospf_url_base = f"{base_url}/ip/Cisco-IOS-XE-ospf:router-ospf/ospf"
                ospf_config = config.get("ospf", {})
                
                if mode in ["delete", "remove"]:
                    pid = ospf_config.get("process_id", 1)
                    res = requests.delete(f"{ospf_url_base}/process-id={pid}", auth=(user, pw), headers=headers, verify=False)
                    results.append(f"Gỡ sạch OSPF {intf_name}: {res.status_code}")
                    continue 
                
                if ospf_config.get("auth_type") == "remove":
                    requests.delete(f"{ospf_url_base}/authentication", auth=(user, pw), headers=headers, verify=False)
                    requests.delete(f"{ospf_url_base}/message-digest-key", auth=(user, pw), headers=headers, verify=False)
                else:
                    keys_list = ospf_config.get("keys", [])
                    for k in keys_list:
                        if k.get("action") == "delete":
                            key_id = k.get("id")
                            requests.delete(f"{ospf_url_base}/message-digest-key={key_id}", auth=(user, pw), headers=headers, verify=False)
                
                if ospf_config.get("bfd") in [False, "remove", "false"]:
                    res_bfd = requests.delete(f"{ospf_url_base}/bfd", auth=(user, pw), headers=headers, verify=False)
                    results.append(f"Gỡ BFD {intf_name}: {res_bfd.status_code}")

                template_json = env.get_template('protocols/ospf/interface_ospf_restconf.j2')
                payload_json = template_json.render(config=config)
                res = requests.patch(f"{base_url}/ip/Cisco-IOS-XE-ospf:router-ospf", auth=(user, pw), headers=headers, json=json.loads(payload_json), verify=False)
                results.append(f"Set OSPF {intf_name}: {res.status_code}")
            else:
                raise Exception(f"RESTCONF chưa hỗ trợ sub_type: {sub_type}")
                
        return " | ".join(results)
    except Exception as e: raise Exception(f"Lỗi RESTCONF ({sub_type}): {str(e)}")

# =========================================================
# XỬ LÝ NETCONF
# =========================================================
def handle_netconf_interface(task, payload, mode, sub_type):
    host_ip, port = task.host.hostname, task.host.port or 830
    user, pw = task.host.username, task.host.password
    template_dir = os.path.join(CURRENT_DIR, "templates", task.host.data.get("template_folder", "cisco_ios"))
    env = Environment(loader=FileSystemLoader(template_dir))
    results = []
    configs = payload.get("config", [])
    try:
        with manager.connect(host=host_ip, port=port, username=user, password=pw, hostkey_verify=False, device_params={'name': 'default'}, timeout=10) as m:
            for config in configs:
                intf_type, intf_id = parse_interface_name(config.get("name", ""))
                if not intf_type: continue
                if sub_type == "ip_address": tpl = 'interface_netconf.j2'
                elif sub_type == "port_status": tpl = 'port_status_netconf.j2'
                elif sub_type == "routing_protocol": tpl = 'interface_ospf_netconf.j2'
                else: raise Exception(f"NETCONF chưa hỗ trợ sub_type: {sub_type}")
                xml_payload = env.get_template(tpl).render(config=config, intf_type=intf_type, intf_id=intf_id, mode=mode)
                res = m.edit_config(target='running', config=xml_payload)
                results.append(f'{config.get("name")} {sub_type} (NETCONF): {res.ok}')
        return " | ".join(results)
    except Exception as e: raise Exception(f"Lỗi NETCONF ({sub_type}): {str(e)}")

# =========================================================
# QUẢN LÝ INVENTORY & RUNNER
# =========================================================
def build_worker_inventory(task_list): # Đã gỡ tham số db_path
    task_map = {item.get("target", {}).get("ip"): item for item in task_list if item.get("target", {}).get("ip")}
    hosts_yaml = {}
    try:
        # Chọc thẳng vào DB_PATH từ config
        conn_db = sqlite3.connect(DB_PATH)
        cursor = conn_db.cursor()
        for ip, payload in task_map.items():
            cursor.execute('SELECT device_name, username, password, os, portnumber, method FROM devices WHERE host = ?', (ip,))
            row = cursor.fetchone()
            if row:
                dev_name, db_user, db_pass, db_os, db_port, db_method = row
                platform = "cisco_ios" if db_os == "cisco" else db_os
                # Đặc biệt nếu là cisco_ios nhưng dùng Telnet thì vẫn phải xài template của cisco_ios để render, chỉ khác ở phần connection thôi
                if platform == "cisco_ios_telnet":
                    tpl_folder = "cisco_ios"
                else:
                    tpl_folder = platform
                    #============================
                hosts_yaml[dev_name or ip] = {
                    "hostname": ip, "username": db_user, "password": db_pass,
                    "port": db_port or 22, "platform": platform,
                    "data": {"secret": "", "template_folder": tpl_folder, "ui_payload": payload, "method": db_method}
                }
        conn_db.close()
    except Exception as e: print(f"[-] Lỗi DB: {e}")
    inv_file_path = os.path.join(CURRENT_DIR, "tmp_interface_inventory.yaml")
    with open(inv_file_path, 'w', encoding='utf-8') as f: yaml.dump(hosts_yaml, f)
    return inv_file_path

# =========================================================
# TASK PUSH CHÍNH
# =========================================================
def task_push_interface(task):
    my_payload = task.host.data["ui_payload"]
    mode = my_payload.get("action", "setup").lower()
    sub_type = my_payload.get("sub_type", "ip_address").lower()
    method = task.host.data.get("method", "SSH")
    
    if method == "RESTCONF": return Result(host=task.host, result=handle_restconf_interface(task, my_payload, mode, sub_type))
    if method == "NETCONF": return Result(host=task.host, result=handle_netconf_interface(task, my_payload, mode, sub_type))

    configs = my_payload.get("config", [])
    template_folder = task.host.data["template_folder"]
    all_commands = []
    
    for cfg in configs:
        intf_name = cfg.get("name")
        if not intf_name: continue
        
        all_commands.append(f"interface {intf_name}")
        
        if sub_type == "ip_address": tpl = 'interface.j2'
        elif sub_type == "port_status": tpl = 'port_status.j2'
        elif sub_type == "routing_protocol": tpl = 'protocols/ospf/ospf_int.j2'
        else: raise Exception(f"SSH chưa hỗ trợ: {sub_type}")
        
        cmd_str = render_interface_config(template_folder, cfg, mode, template_name=tpl)
        if cmd_str: 
            lines = [l.strip() for l in cmd_str.splitlines() if l.strip() and not l.strip().startswith('!')]
            all_commands.extend(lines)

    if not all_commands: return "No commands to push."
    res = task.run(
        task=netmiko_send_config, 
        config_commands=all_commands,
        read_timeout=120,          # Ép chờ 120s thay vì timeout mặc định 
    )
    return res[0].result

def run_interface_config(task_list, output_path): # Đã gỡ tham số db_path
    inv_path = build_worker_inventory(task_list)  # Đã gỡ tham số
    if not inv_path: return
    
#!========= HÀM CHÍNH CHẠY INTERFACE CONFIG QUA NORNIR (QUYẾT ĐỊNH SỐ LƯỢNG WORKER) =========
    nr = InitNornir(
        runner={"plugin": "threaded", "options": {"num_workers": 20}}, 
        inventory={"plugin": "SimpleInventory", "options": {"host_file": inv_path}}, 
        logging={"enabled": False}
    )
    results = nr.run(task=task_push_interface)
    output_data = []
    for host, task_res in results.items():
        status = "failed" if task_res.failed else "success"
        message = str(task_res.exception) if task_res.failed else (str(task_res[0].result) if hasattr(task_res[0], 'result') else str(task_res[0]))
        output_data.append({"target": nr.inventory.hosts[host].hostname, "status": status, "message": message})
        print(f"[{'+' if status == 'success' else '-'}] {host}: {message}")
    with open(output_path, 'w', encoding='utf-8') as f: json.dump(output_data, f, indent=4, ensure_ascii=False)
    if os.path.exists(inv_path): os.remove(inv_path)