import json
import random

# Hàm hỗ trợ sinh IP ngẫu nhiên
def random_ip():
    return f"{random.randint(10, 192)}.{random.randint(0, 255)}.{random.randint(0, 255)}.{random.randint(1, 254)}"

def random_port():
    return random.choice([random.randint(32000, 33000), f"COM{random.randint(1, 9)}"])

# Tập hợp các câu lệnh mồi chung cho AI
INSTRUCTION = "Bạn là kỹ sư tự động hóa mạng. Chuyển yêu cầu thành MỘT mảng JSON duy nhất. KHÔNG giải thích. Mỗi thiết bị BẮT BUỘC có trường 'type' (virtual/physical), 'port' và 'cmds'."

dataset = []

def add_entry(user_input, cmds_list, port):
    device_type = "physical" if str(port).startswith("COM") else "virtual"
    output_obj = [{
        "type": device_type,
        "port": port,
        "cmds": cmds_list
    }]
    dataset.append({
        "instruction": INSTRUCTION,
        "input": user_input,
        "output": json.dumps(output_obj, ensure_ascii=False)
    })

print("[*] Đang khởi động lò đúc Dataset...")

# ---------------------------------------------------------
# 1. BOOTSTRAP ROUTER (100 bài)
# ---------------------------------------------------------
for i in range(100):
    port = random_port()
    ip = random_ip()
    host = f"R{random.randint(1, 99)}"
    user = random.choice(["admin", "kien", "root", "cisco"])
    password = random.choice(["123", "cisco123", "admin@123"])
    
    user_input = f"Tạo 1 Router { 'thật cắm cổng' if str(port).startswith('COM') else 'ảo port' } {port}. Đặt tên {host}, IP cổng g0/0 là {ip}/24, no shut. Tạo user {user} pass {password}, bật ssh version 2."
    cmds = [
        f"hostname {host}",
        "interface GigabitEthernet0/0",
        f"ip address {ip} 255.255.255.0",
        "no shutdown", "exit",
        f"username {user} privilege 15 password {password}",
        "ip domain-name lab.local",
        "crypto key generate rsa modulus 2048",
        "ip ssh version 2",
        "line vty 0 4", "login local", "transport input ssh", "exit"
    ]
    add_entry(user_input, cmds, port)

# ---------------------------------------------------------
# 2. BOOTSTRAP SWITCH (100 bài)
# ---------------------------------------------------------
for i in range(100):
    port = random_port()
    ip = random_ip()
    host = f"SW{random.randint(1, 99)}"
    vlan_mgmt = random.choice([1, 98, 99, 100])
    
    user_input = f"Cấu hình mồi Switch {host} trên port {port}. Bật interface vlan {vlan_mgmt} IP {ip}/24. Tạo user admin pass 123 và bật ssh."
    cmds = [
        f"hostname {host}",
        f"interface Vlan{vlan_mgmt}",
        f"ip address {ip} 255.255.255.0",
        "no shutdown", "exit",
        "username admin privilege 15 password 123",
        "ip domain-name lab.local",
        "crypto key generate rsa modulus 2048",
        "ip ssh version 2",
        "line vty 0 4", "login local", "transport input ssh", "exit"
    ]
    add_entry(user_input, cmds, port)

# ---------------------------------------------------------
# 3. ĐẶT IP INTERFACE ROUTER (100 bài)
# ---------------------------------------------------------
for i in range(100):
    port = random_port()
    intf1 = f"GigabitEthernet0/{random.randint(1,3)}"
    ip1 = random_ip()
    intf2 = f"GigabitEthernet0/{random.randint(4,6)}"
    ip2 = random_ip()
    
    user_input = f"Vào Router port {port}, đặt IP cho cổng {intf1} là {ip1}/24 và cổng {intf2} là {ip2}/24. Nhớ no shutdown cả 2 cổng."
    cmds = [
        f"interface {intf1}", f"ip address {ip1} 255.255.255.0", "no shutdown", "exit",
        f"interface {intf2}", f"ip address {ip2} 255.255.255.0", "no shutdown", "exit"
    ]
    add_entry(user_input, cmds, port)

# ---------------------------------------------------------
# 4. GIAO THỨC OSPF (100 bài)
# ---------------------------------------------------------
for i in range(100):
    port = random_port()
    process_id = random.randint(1, 100)
    net1 = random_ip()[:-1] + "0" # Tạo IP đuôi 0
    area = random.choice([0, 1, 10])
    
    user_input = f"Port {port}, cấu hình chạy OSPF process {process_id}, quảng bá mạng {net1}/24 vào area {area}."
    cmds = [
        f"router ospf {process_id}",
        f"network {net1} 0.0.0.255 area {area}",
        "exit"
    ]
    add_entry(user_input, cmds, port)

# ---------------------------------------------------------
# 5. GIAO THỨC EIGRP (100 bài)
# ---------------------------------------------------------
for i in range(100):
    port = random_port()
    as_num = random.randint(1, 65535)
    net1 = random_ip()[:-1] + "0"
    
    user_input = f"Router port {port}. Thiết lập định tuyến EIGRP AS {as_num}. Quảng bá dải mạng {net1} (wildcard 0.0.0.255) và tắt auto-summary."
    cmds = [
        f"router eigrp {as_num}",
        f"network {net1} 0.0.0.255",
        "no auto-summary",
        "exit"
    ]
    add_entry(user_input, cmds, port)

# ---------------------------------------------------------
# 6. SWITCH VLAN, ACCESS, TRUNK GOM CỔNG (100 bài)
# ---------------------------------------------------------
for i in range(100):
    port = random_port()
    v_id = random.randint(10, 50)
    start_p = random.randint(1, 5)
    end_p = random.randint(6, 12)
    trunk_p = random.randint(20, 24)
    
    user_input = f"Switch port {port}. Tạo vlan {v_id} tên IT. Gom dải cổng FastEthernet0/{start_p} - {end_p} vào mode access cho vlan {v_id}. Cấu hình cổng GigabitEthernet0/1 làm đường trunk."
    cmds = [
        f"vlan {v_id}", "name IT", "exit",
        f"interface range FastEthernet0/{start_p} - {end_p}",
        "switchport mode access",
        f"switchport access vlan {v_id}", "exit",
        "interface GigabitEthernet0/1",
        "switchport trunk encapsulation dot1q",
        "switchport mode trunk", "exit"
    ]
    add_entry(user_input, cmds, port)

# ---------------------------------------------------------
# 7. CẤU HÌNH DHCP SERVER (100 bài)
# ---------------------------------------------------------
for i in range(100):
    port = random_port()
    pool_name = f"LAN_{random.randint(1, 50)}"
    net_ip = random_ip()[:-1] + "0"
    gw_ip = net_ip[:-1] + "1"
    dns_ip = "8.8.8.8"
    
    user_input = f"Vào Router ảo port {port}, tạo DHCP pool tên {pool_name}. Cấp dải mạng {net_ip}/24, default router là {gw_ip} và DNS {dns_ip}."
    cmds = [
        f"ip dhcp pool {pool_name}",
        f"network {net_ip} 255.255.255.0",
        f"default-router {gw_ip}",
        f"dns-server {dns_ip}",
        "exit"
    ]
    add_entry(user_input, cmds, port)

# ---------------------------------------------------------
# 8. BẢO MẬT VỚI ACL (Access Control List) (100 bài)
# ---------------------------------------------------------
for i in range(100):
    port = random_port()
    acl_num = random.randint(1, 99) # Standard ACL
    deny_ip = random_ip()
    intf = f"GigabitEthernet0/{random.randint(0,2)}"
    direction = random.choice(["in", "out"])
    
    user_input = f"Router cổng {port}, tạo ACL {acl_num} để chặn IP {deny_ip}, còn lại cho phép hết. Áp dụng ACL này vào cổng {intf} chiều {direction}."
    cmds = [
        f"access-list {acl_num} deny host {deny_ip}",
        f"access-list {acl_num} permit any",
        f"interface {intf}",
        f"ip access-group {acl_num} {direction}",
        "exit"
    ]
    add_entry(user_input, cmds, port)

# ---------------------------------------------------------
# 9. DỊCH VỊ ĐỊA CHỈ NAT OVERLOAD (PAT) (100 bài)
# ---------------------------------------------------------
for i in range(100):
    port = random_port()
    acl_num = random.randint(1, 99)
    in_intf = f"GigabitEthernet0/{random.randint(0,1)}" # Cổng LAN
    out_intf = f"GigabitEthernet0/{random.randint(2,3)}" # Cổng WAN
    
    user_input = f"Thiết lập NAT overload trên thiết bị thật port {port}. Dùng ACL {acl_num} để NAT ra interface {out_intf}. Nhớ set {in_intf} là nat inside, {out_intf} là nat outside."
    cmds = [
        f"ip nat inside source list {acl_num} interface {out_intf} overload",
        f"interface {in_intf}",
        "ip nat inside", "exit",
        f"interface {out_intf}",
        "ip nat outside", "exit"
    ]
    add_entry(user_input, cmds, port)

# ---------------------------------------------------------
# LƯU FILE
# ---------------------------------------------------------
# Xáo trộn mảng để AI học xen kẽ, không bị thiên vị học 1 mạch
random.shuffle(dataset)

output_file = "dataset_kien_net.jsonl"
with open(output_file, "w", encoding="utf-8") as f:
    for item in dataset:
        f.write(json.dumps(item, ensure_ascii=False) + "\n")

print(f"[+] Đã hoàn thành! Sinh ra tổng cộng {len(dataset)} mẫu giáo trình.")
print(f"[+] File lưu tại: {output_file}")