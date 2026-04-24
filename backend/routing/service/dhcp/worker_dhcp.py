import os
import sqlite3
import re
import yaml
import json
import requests
import urllib3
import urllib.parse
from jinja2 import Environment, FileSystemLoader
from nornir import InitNornir
from nornir_netmiko.tasks import netmiko_send_config, netmiko_send_command
from nornir.core.task import Result

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(CURRENT_DIR, "..", "..", "..", ".."))

# ==========================================
# 1. RENDER TEMPLATE (CHỈ DÙNG CHO LUỒNG SSH)
# ==========================================
def render_dhcp_template(platform, payload, mode):
    folder_name = "router" if "cisco" in platform else platform
    template_dir = os.path.join(CURRENT_DIR, "templates", folder_name)
    if not os.path.exists(template_dir): raise Exception(f"Không tìm thấy thư mục template: {template_dir}")
    env = Environment(loader=FileSystemLoader(template_dir))
    
    template = env.get_template("dhcp_config.j2")
    return template.render(config=payload.get("config", {}))

# ==========================================
# LUỒNG 1: XỬ LÝ RESTCONF (THUẦN API 100%) - FULL TÍNH NĂNG
# ==========================================
def handle_restconf_dhcp(task, payload, mode):
    host_ip = task.host.hostname
    rest_port = task.host.data.get("rest_port", 443)
    user = task.host.username
    pw = task.host.password
    
    raw_configs = payload.get("config", [])
    configs = raw_configs if isinstance(raw_configs, list) else [raw_configs]
    
    headers = {"Accept": "application/yang-data+json", "Content-Type": "application/yang-data+json"}
    dhcp_url = f"https://{host_ip}:{rest_port}/restconf/data/Cisco-IOS-XE-native:native/ip/dhcp"
    
    results = []

    try:
        for config in configs:
            for exc in config.get("excluded_addresses", []):
                start_ip = exc.get("start_ip")
                end_ip = exc.get("end_ip")
                if end_ip:
                    url_ex = f"{dhcp_url}/excluded-address/low-high-address-list={start_ip},{end_ip}"
                    list_name = "low-high-address-list"
                    item_data = {"low-address": start_ip, "high-address": end_ip}
                else:
                    url_ex = f"{dhcp_url}/excluded-address/low-address-list={start_ip}"
                    list_name = "low-address-list"
                    item_data = {"low-address": start_ip}

                if exc.get("state") in ["remove", "absent"]:
                    requests.delete(url_ex, auth=(user, pw), headers=headers, verify=False)
                    results.append(f"Xóa Excluded {start_ip}")
                else:
                    put_payload = {f"Cisco-IOS-XE-dhcp:{list_name}": [item_data]}
                    res = requests.put(url_ex, auth=(user, pw), headers=headers, json=put_payload, verify=False)
                    if res.status_code >= 400: results.append(f"Lỗi Excluded {start_ip}: {res.text}")
                    else: results.append(f"Setup Excluded {start_ip}: HTTP {res.status_code}")

            for pool in config.get("pools", []):
                pool_name = pool.get("name")
                pool_name_url = urllib.parse.quote(pool_name, safe='')
                url_pool = f"{dhcp_url}/pool={pool_name_url}"
                
                if pool.get("state") in ["remove", "absent"]:
                    requests.delete(url_pool, auth=(user, pw), headers=headers, verify=False)
                    results.append(f"Xóa Pool {pool_name}")
                else:
                    pool_data = {"id": pool_name}
                    if pool.get("network"): 
                        pool_data["network"] = {"primary-network": {"number": pool["network"], "mask": pool.get("subnet_mask", "255.255.255.0")}}
                    if pool.get("default_gateway"): 
                        pool_data["default-router"] = {"default-router-list": pool["default_gateway"].split()}
                    if pool.get("dns_server"): 
                        pool_data["dns-server"] = {"dns-server-list": pool["dns_server"].split()}
                    if pool.get("domain_name"): 
                        pool_data["domain-name"] = pool["domain_name"]
                    
                    if pool.get("lease"):
                        lease_info = pool["lease"]
                        pool_data["lease"] = {}
                        if lease_info.get("infinite"):
                            pool_data["lease"]["infinite"] = [None] 
                        else:
                            lease_value = {}
                            if "days" in lease_info: lease_value["days"] = lease_info["days"]
                            if "hours" in lease_info: lease_value["hours"] = lease_info["hours"]
                            if "minutes" in lease_info: lease_value["minutes"] = lease_info["minutes"]
                            if lease_value:
                                pool_data["lease"]["lease-value"] = lease_value
                    
                    put_payload = {"Cisco-IOS-XE-dhcp:pool": [pool_data]}
                    res = requests.put(url_pool, auth=(user, pw), headers=headers, json=put_payload, verify=False)
                    if res.status_code >= 400: results.append(f"Lỗi Pool {pool_name}: {res.text}")
                    else: results.append(f"Setup Pool {pool_name}: HTTP {res.status_code}")

            for sb in config.get("static_bindings", []):
                pool_name = sb.get("pool_name")
                pool_name_url = urllib.parse.quote(pool_name, safe='')
                url_pool = f"{dhcp_url}/pool={pool_name_url}"
                
                if sb.get("state") in ["remove", "absent"]:
                    requests.delete(url_pool, auth=(user, pw), headers=headers, verify=False)
                    results.append(f"Xóa Static Binding {pool_name}")
                else:
                    pool_data = {"id": pool_name}
                    if sb.get("host_ip"):
                        pool_data["host"] = {
                            "number": sb["host_ip"], 
                            "mask": sb.get("subnet_mask", "255.255.255.0")
                        }
                    if sb.get("mac_address"):
                        pool_data["client-identifier"] = sb["mac_address"]
                    if sb.get("client_name"):
                        pool_data["client-name"] = sb["client_name"]
                        
                    put_payload = {"Cisco-IOS-XE-dhcp:pool": [pool_data]}
                    res = requests.put(url_pool, auth=(user, pw), headers=headers, json=put_payload, verify=False)
                    if res.status_code >= 400: results.append(f"Lỗi Static Binding {pool_name}: {res.text}")
                    else: results.append(f"Setup Static Binding {pool_name}: HTTP {res.status_code}")

        return " | ".join(results) if results else "Xử lý RESTCONF thành công (Không có data)."
    except Exception as e:
        raise Exception(f"Lỗi RESTCONF: {str(e)}")

# ==========================================
# LUỒNG 2: XỬ LÝ SSH / NETMIKO (THUẦN CLI 100%)
# ==========================================
def handle_ssh_dhcp(task, payload, mode):
    raw_configs = payload.get("config", [])
    configs = raw_configs if isinstance(raw_configs, list) else [raw_configs]
    cmds_list = []
    
    for config in configs:
        temp_payload = {"config": config}
        cmds_str = render_dhcp_template(task.host.data["platform_os"], temp_payload, mode)
        cmds_list.extend([cmd.strip() for cmd in cmds_str.splitlines() if cmd.strip()])
    
    if not cmds_list: 
        raise Exception("Template không sinh ra mã lệnh CLI nào!")
        
    res = task.run(task=netmiko_send_config, config_commands=cmds_list)
    return res[0].result

# ==========================================
# CẢNH SÁT GIAO THÔNG: ĐIỀU PHỐI LUỒNG (TÁCH BẠCH 100%)
# ==========================================
def task_manage_dhcp(task):
    payload = task.host.data["ui_payload"]
    mode = payload.get("action", "")
    method = task.host.data.get("method", "SSH")
    
    # --- XỬ LÝ LỆNH SHOW (ĐỌC BẢNG BINDING) ---
    if mode == "show": 
        if method == "RESTCONF":
            host_ip = task.host.hostname
            rest_port = task.host.data.get("rest_port", 443)
            user, pw = task.host.username, task.host.password
            
            oper_url = f"https://{host_ip}:{rest_port}/restconf/data/Cisco-IOS-XE-dhcp-oper:dhcp-oper-data"
            try:
                res = requests.get(oper_url, auth=(user, pw), headers={"Accept": "application/yang-data+json", "Connection": "close"}, verify=False, timeout=10)
                
                if res.status_code == 200: 
                    return Result(host=task.host, result=res.text)
                elif res.status_code == 404:
                    # Trạng thái 404 chuẩn của RESTCONF khi bảng Binding thực sự trống
                    empty_data = {"Cisco-IOS-XE-dhcp-oper:dhcp-oper-data": {"dhcp-v4-binding": []}}
                    return Result(host=task.host, result=json.dumps(empty_data))
                else:
                    raise Exception(f"HTTP {res.status_code} - {res.text}")
                    
            except requests.exceptions.ChunkedEncodingError:
                # Báo lỗi thẳng tay nếu Router bị bug ngắt kết nối API đột ngột
                raise Exception("Lỗi RESTCONF: Router ngắt kết nối đột ngột (ChunkedEncodingError). Bug của thiết bị không nhả data qua API.")
            except Exception as e:
                raise Exception(f"Lỗi hệ thống API: {str(e)}")
        else:
            # Luồng SSH thuần túy
            return task.run(task=netmiko_send_command, command_string="show ip dhcp binding").result

    # --- XỬ LÝ LỆNH CLEAR (XÓA IP ĐÃ CẤP) ---
    if mode == "clear":
        ip = payload.get("config", [{}])[0].get("ip_address", "all")
        if method == "RESTCONF":
            # Ghi chú: Cisco RESTCONF chưa hỗ trợ API RPC để clear DHCP binding ở một số bản IOS-XE. 
            # Tạm thời khóa luồng này để đảm bảo tính minh bạch.
            raise Exception("Lỗi: Thiết bị chưa hỗ trợ API RESTCONF để Clear DHCP Binding. Vui lòng dùng SSH.")
        else:
            return task.run(task=netmiko_send_command, command_string="clear ip dhcp binding *" if ip.lower() == "all" else f"clear ip dhcp binding {ip}").result

    # --- XỬ LÝ CẤU HÌNH (SETUP / REMOVE) ---
    if method == "RESTCONF":
        return Result(host=task.host, result=handle_restconf_dhcp(task, payload, mode))
    elif method == "NETCONF":
        raise Exception("NETCONF Module đang được bảo trì. Vui lòng chọn SSH hoặc RESTCONF.")
    else:
        return Result(host=task.host, result=handle_ssh_dhcp(task, payload, mode))
    payload = task.host.data["ui_payload"]
    mode = payload.get("action", "")
    method = task.host.data.get("method", "SSH")
    
    # --- XỬ LÝ LỆNH SHOW (ĐỌC BẢNG BINDING) ---
    if mode == "show": 
        if method == "RESTCONF":
            host_ip = task.host.hostname
            rest_port = task.host.data.get("rest_port", 443)
            user, pw = task.host.username, task.host.password
            
            oper_url = f"https://{host_ip}:{rest_port}/restconf/data/Cisco-IOS-XE-dhcp-oper:dhcp-oper-data"
            try:
                res = requests.get(oper_url, auth=(user, pw), headers={"Accept": "application/yang-data+json", "Connection": "close"}, verify=False, timeout=5)
                if res.status_code == 200: 
                    return Result(host=task.host, result=res.text)
                else:
                    raise Exception(f"API HTTP {res.status_code}")
            except Exception as e:
                # 🔥 TUYỆT CHIÊU HYBRID FALLBACK: API LỖI -> ÂM THẦM DÙNG SSH MÓC DATA 🔥
                cli_text = task.run(task=netmiko_send_command, command_string="show ip dhcp binding").result
                fallback_bindings = []
                for line in cli_text.splitlines():
                    match = re.match(r"^(\d+\.\d+\.\d+\.\d+)\s+([a-fA-F0-9.]+)\s+(.*?)\s+(Automatic|Manual)", line.strip())
                    if match: 
                        fallback_bindings.append({
                            "client-ip": match.group(1),
                            "client-hardware-address": match.group(2),
                            "expiration": match.group(3).strip(),
                            "binding-type": match.group(4)
                        })
                # Đóng gói data từ CLI thành cục JSON giả mạo y hệt RESTCONF xịn
                fake_api_json = {"Cisco-IOS-XE-dhcp-oper:dhcp-oper-data": {"dhcp-v4-binding": fallback_bindings}}
                return Result(host=task.host, result=json.dumps(fake_api_json))
        else:
            return task.run(task=netmiko_send_command, command_string="show ip dhcp binding").result

    # --- XỬ LÝ LỆNH CLEAR (XÓA IP ĐÃ CẤP) ---
    if mode == "clear":
        ip = payload.get("config", [{}])[0].get("ip_address", "all")
        return task.run(task=netmiko_send_command, command_string="clear ip dhcp binding *" if ip.lower() == "all" else f"clear ip dhcp binding {ip}").result

    # --- XỬ LÝ CẤU HÌNH (SETUP / REMOVE) ---
    if method == "RESTCONF":
        return Result(host=task.host, result=handle_restconf_dhcp(task, payload, mode))
    elif method == "NETCONF":
        raise Exception("NETCONF Module đang được bảo trì. Vui lòng chọn SSH hoặc RESTCONF.")
    else:
        return Result(host=task.host, result=handle_ssh_dhcp(task, payload, mode))
    payload = task.host.data["ui_payload"]
    mode = payload.get("action", "")
    method = task.host.data.get("method", "SSH")
    
    if mode == "show": 
        if method == "RESTCONF":
            host_ip = task.host.hostname
            rest_port = task.host.data.get("rest_port", 443)
            user, pw = task.host.username, task.host.password
            
            oper_url = f"https://{host_ip}:{rest_port}/restconf/data/Cisco-IOS-XE-dhcp-oper:dhcp-oper-data"
            try:
                # 🔥 FIX 1: Thêm Connection: close để trị chứng đứt gãy TCP của con C8000v
                res = requests.get(oper_url, auth=(user, pw), headers={"Accept": "application/yang-data+json", "Connection": "close"}, verify=False, timeout=10)
                
                if res.status_code == 200: 
                    return Result(host=task.host, result=res.text)
                elif res.status_code == 404:
                    empty_data = {"Cisco-IOS-XE-dhcp-oper:dhcp-oper-data": {"dhcp-v4-binding": []}}
                    return Result(host=task.host, result=json.dumps(empty_data))
                    
                raise Exception(f"Lỗi GET API: HTTP {res.status_code} - {res.text}")
            except requests.exceptions.ChunkedEncodingError:
                # 🔥 FIX 2: Nếu Cisco rút dây đột ngột, Tool sẽ tự giả lập mảng rỗng để đi tiếp
                empty_data = {"Cisco-IOS-XE-dhcp-oper:dhcp-oper-data": {"dhcp-v4-binding": []}}
                return Result(host=task.host, result=json.dumps(empty_data))
            except Exception as e:
                raise Exception(f"Lỗi RESTCONF Show: {str(e)}")
        else:
            return task.run(task=netmiko_send_command, command_string="show ip dhcp binding").result

    if mode == "clear":
        ip = payload.get("config", [{}])[0].get("ip_address", "all")
        return task.run(task=netmiko_send_command, command_string="clear ip dhcp binding *" if ip.lower() == "all" else f"clear ip dhcp binding {ip}").result

    if method == "RESTCONF":
        return Result(host=task.host, result=handle_restconf_dhcp(task, payload, mode))
    elif method == "NETCONF":
        raise Exception("NETCONF Module đang được bảo trì. Vui lòng chọn SSH hoặc RESTCONF.")
    else:
        return Result(host=task.host, result=handle_ssh_dhcp(task, payload, mode))

# ==========================================
# KHỞI TẠO HỆ THỐNG VÀ XUẤT KẾT QUẢ
# ==========================================
def build_dhcp_inventory(db_path, task_list):
    task_map = {item.get("target", {}).get("ip"): item for item in task_list if item.get("target", {}).get("ip")}
    hosts_yaml = {}
    if not task_map: return None

    try:
        conn_db = sqlite3.connect(db_path)
        cursor = conn_db.cursor()
        for ip, payload in task_map.items():
            cursor.execute('SELECT device_name, username, password, os, portnumber, method FROM devices WHERE host = ?', (ip,))
            row = cursor.fetchone()
            if row:
                dev_name, db_user, db_pass, db_os, db_port, db_method = row
                platform = "cisco_ios" if db_os == "cisco" else db_os
                host_key = dev_name if dev_name else ip
                hosts_yaml[host_key] = {
                    "hostname": ip, 
                    "username": db_user, 
                    "password": db_pass, 
                    "port": 22,
                    "platform": platform, 
                    "connection_options": {
                        "netmiko": {
                            "extras": {
                                "banner_timeout": 30,
                                "auth_timeout": 30,
                                "session_timeout": 60,
                                "global_delay_factor": 2
                            }
                        }
                    },
                    "data": {
                        "ui_payload": payload, 
                        "platform_os": db_os, 
                        "method": db_method,
                        "rest_port": db_port if db_port else 443
                    }
                }
    except Exception as e: print(f"[ERROR] Lỗi DB: {e}")
    finally:
        if 'conn_db' in locals(): conn_db.close()
        
    inv_file_path = os.path.join(CURRENT_DIR, "tmp_dhcp_inventory.yaml")
    with open(inv_file_path, 'w', encoding='utf-8') as f: yaml.dump(hosts_yaml, f)
    return inv_file_path

def run_dhcp_worker(task_list, db_path, output_path):
    print("\n[INFO] Khởi động Nornir DHCP Worker (Đã Tách Luồng Độc Lập)...")
    inv_file_path = build_dhcp_inventory(db_path, task_list)
    if not inv_file_path: return
    
    nr = InitNornir(runner={"plugin": "threaded", "options": {"num_workers": 10}}, inventory={"plugin": "SimpleInventory", "options": {"host_file": inv_file_path}}, logging={"enabled": False})
    results = nr.run(task=task_manage_dhcp)
    BASE_BACKUP_DIR = os.path.join(PROJECT_ROOT, "PyCode", "share", "database", "backup")
    output_data = []

    for host, task_res in results.items():
        # 🔥 FIX 3: Dời 3 biến này lên đầu để tránh bị lấy râu ông nọ cắm cằm bà kia!
        payload = nr.inventory.hosts[host].data.get("ui_payload", {})
        mode = payload.get("action", "")
        method = nr.inventory.hosts[host].data.get("method", "SSH")
        
        status = "failed" if task_res.failed else "success"
        message = str(task_res.exception) if task_res.failed else str(task_res[0].result if type(task_res) is not Result else task_res.result)
        
        if "Lỗi" in message or "HTTP 4" in message or "Response ended prematurely" in message or status == "failed":
            print(f"[-] Thất bại: {host} -> {message}")
            status = "failed"
        else:
            try:
                count = len(json.loads(message).get('Cisco-IOS-XE-dhcp-oper:dhcp-oper-data', {}).get('dhcp-v4-binding', [])) if method == 'RESTCONF' else message.count('Automatic') + message.count('Manual')
                print(f"[+] Thành công: {host} -> Đã trích xuất {count} bản ghi Binding.")
            except Exception:
                print(f"[+] Thành công: {host} -> Lấy dữ liệu hoàn tất.")

        host_result = {"target": nr.inventory.hosts[host].hostname, "status": status, "message": message}
        
        if mode == "show" and status == "success":
            ip_target = nr.inventory.hosts[host].hostname
            host_backup_dir = os.path.join(BASE_BACKUP_DIR, ip_target)
            if not os.path.exists(host_backup_dir): os.makedirs(host_backup_dir)
            parsed_bindings = []
            
            if method == "RESTCONF":
                try:
                    oper_data = json.loads(message).get("Cisco-IOS-XE-dhcp-oper:dhcp-oper-data", {})
                    for b in oper_data.get("dhcp-v4-binding", []):
                        parsed_bindings.append({
                            "ip_address": b.get("client-ip", ""), 
                            "mac_address": b.get("client-hardware-address", ""), 
                            "lease_expiration": b.get("expiration", ""), 
                            "type": b.get("binding-type", "")
                        })
                except Exception as e: print(f"[-] Lỗi Parse JSON API: {e}")
            else:
                for line in message.splitlines():
                    match = re.match(r"^(\d+\.\d+\.\d+\.\d+)\s+([a-fA-F0-9.]+)\s+(.*?)\s+(Automatic|Manual)", line.strip())
                    if match: parsed_bindings.append({"ip_address": match.group(1), "mac_address": match.group(2), "lease_expiration": match.group(3).strip(), "type": match.group(4)})
            
            backup_file = os.path.join(host_backup_dir, "show_binding.json")
            with open(backup_file, 'w', encoding='utf-8') as bf: json.dump(parsed_bindings, bf, indent=4, ensure_ascii=False)
            host_result["message"] = parsed_bindings

        output_data.append(host_result)

    with open(output_path, 'w', encoding='utf-8') as f: json.dump(output_data, f, indent=4, ensure_ascii=False)
    if os.path.exists(inv_file_path): os.remove(inv_file_path)