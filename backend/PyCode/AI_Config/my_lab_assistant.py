import requests
import sys
import time
import json
import concurrent.futures
import re
from netmiko import ConnectHandler

class LabAssistant:
    def __init__(self, model_name="Plana"):
        self.api_url = "http://localhost:11434/api/generate"
        self.model = model_name
        print(f"[*] {self.model} đã có mặt để hỗ trợ Kiên-sensei!")

    def generate_bootstrap(self, user_request):
        system_prompt = """Bạn là kỹ sư tự động hóa mạng. Chuyển yêu cầu thành MỘT mảng JSON duy nhất.
TUYỆT ĐỐI KHÔNG giải thích. KHÔNG dùng markdown. Bắt buộc thêm lệnh 'ip ssh version 2'.
Mỗi thiết bị BẮT BUỘC có trường "type" ("virtual" hoặc "physical").
- Nếu "virtual", trường "port" là số (ví dụ: 32769).
- Nếu "physical", trường "port" là tên cổng COM (ví dụ: "COM3").
--- VÍ DỤ MẪU ---
Yêu cầu: "Tạo 2 con R1, R2. Port console lần lượt 32769, 32770. IP g0/0 là 10.0.0.1 và 10.0.0.2/24. pass 123, bật ssh."
JSON:
[
  {
    "type": "virtual",
    "port": 32769,
    "cmds": [
      "hostname R1",
      "interface GigabitEthernet0/0",
      "ip address 10.0.0.1 255.255.255.0",
      "no shutdown",
      "exit",
      "username kien privilege 15 password 123",
      "ip domain-name lab.com",
      "crypto key generate rsa modulus 2048",
      "ip ssh version 2",
      "ip http server",
      "ip http secure-server",
      "line vty 0 4",
      "login local",
      "transport input ssh",
      "exit"
    ]
  },
  {
    "type": "virtual",
    "port": 32770,
    "cmds": [
      "hostname R2",
      "interface GigabitEthernet0/0",
      "ip address 10.0.0.2 255.255.255.0",
      "no shutdown",
      "exit",
      "username kien privilege 15 password 123",
      "ip domain-name lab.com",
      "crypto key generate rsa modulus 2048",
      "ip ssh version 2",
      "ip http server",
      "ip http secure-server",
      "line vty 0 4",
      "login local",
      "transport input ssh",
      "exit"
    ]
  }
]
--- VÍ DỤ MẪU SWITCH ---
Yêu cầu: "1 Switch thật cổng COM5, tạo vlan 10, gán cổng g0/1 access vlan 10, cổng g0/2 trunk. pass 123, ssh"
JSON:
[
  {
    "type": "physical",
    "port": "COM5",
    "cmds": [
      "hostname SW1",
      "vlan 10",
      "exit",
      "interface GigabitEthernet0/1",
      "switchport mode access",
      "switchport access vlan 10",
      "exit",
      "interface GigabitEthernet0/2",
      "switchport trunk encapsulation dot1q",
      "switchport mode trunk",
      "exit",
      "username kien privilege 15 password 123",
      "ip domain-name lab.com",
      "crypto key generate rsa modulus 2048",
      "ip ssh version 2",
      "ip http server",
      "ip http secure-server",
      "line vty 0 4",
      "login local",
      "transport input ssh",
      "exit"
    ]
  }
]
-----------------
YÊU CẦU CỦA NGƯỜI DÙNG: """

        full_prompt = system_prompt + user_request
        payload = {
            "model": self.model, 
            "prompt": full_prompt, 
            "stream": False,
            "options": {"temperature": 0.1}
        }
        
        try:
            print(f"\n[*] Plana đang nặn JSON Code...")
            response = requests.post(self.api_url, json=payload)
            response.raise_for_status()
            
            raw_text = response.json().get("response", "").strip()
            
            match = re.search(r'\[\s*\{.*?\}\s*\]', raw_text, re.DOTALL)
            if match:
                clean_json = match.group(0)
                return json.loads(clean_json)
            else:
                raise ValueError("Không tìm thấy cấu trúc mảng JSON trong câu trả lời.")

        except (json.JSONDecodeError, ValueError):
            print("[-] Plana đã gặp vấn đề, đây là cú pháp thô trả về:")
            print(raw_text)
            return []
        except requests.exceptions.RequestException as e:
            print(f"[-] Lỗi kết nối đến Ollama ({self.model}): {e}")
            return []

    # Hàm xử lý cho 1 LUỒNG (1 thiết bị)
    def _config_worker(self, telnet_ip, node):
        device_type_node = node.get("type", "virtual")
        port = node.get("port")
        cmds = node.get("cmds", [])
        
        if not port or not cmds:
            return

        if device_type_node == "physical":
            print(f"[*] [Port {port}] Đang cắm cáp Console trực tiếp...")
            device = {
                'device_type': 'cisco_ios_serial',
                'serial_settings': {'port': port, 'baudrate': 9600},
                'global_delay_factor': 1.5,
            }
        else:
            print(f"[*] [Port {port}] Đang cắm cáp Telnet vào EVE-NG {telnet_ip}:{port}...")
            device = {
                'device_type': 'cisco_ios_telnet',
                'host': telnet_ip,
                'port': port,
                'global_delay_factor': 1.5,
            }

        try:
            net_connect = ConnectHandler(**device)
            net_connect.write_channel('\r\n\r\n')
            time.sleep(1)
            net_connect.enable()
            
            print(f"[*] [Port {port}] Plana đang gõ cấu hình cháy máy...")
            net_connect.send_command_timing('configure terminal')
            for cmd in cmds:
                net_connect.send_command_timing(cmd)
                
            net_connect.send_command_timing('end')
            net_connect.send_command_timing('write memory')
            net_connect.disconnect()
            print(f"[+] [Port {port}] HOÀN TẤT THÀNH CÔNG!")
            
        except Exception as e:
            print(f"[-] [Port {port}] Bỏ qua do lỗi: {e}")

    # Hàm gọi ĐA LUỒNG
    def push_to_console(self, telnet_ip, node_list):
        print(f"\n KÍCH HOẠT ĐA LUỒNG: Plana đang phân thân gõ lệnh {len(node_list)} thiết bị CÙNG LÚC...")
        
        with concurrent.futures.ThreadPoolExecutor(max_workers=15) as executor:
            futures = [executor.submit(self._config_worker, telnet_ip, node) for node in node_list]
            concurrent.futures.wait(futures)
            
        print("\n TẤT CẢ THIẾT BỊ ĐÃ ĐƯỢC CẤU HÌNH XONG!")


if __name__ == "__main__":
    assistant = LabAssistant()
    
    print("="*70)
    print(" Plana trợ lý của Kiên-sensei đã có mặt (Bấm Ctrl+C để thoát)")
    print("="*70)
    
    eve_ip = input("\n[?] Sensei hãy Nhập IP của máy chủ EVE-NG (Ấn Enter nếu chỉ dùng thiết bị thật): ").strip()
    if not eve_ip:
        eve_ip = "127.0.0.1"
    
    while True:
        try:
            yeu_cau = input("\n[1. Kiên-sensei cần cấu hình gì ạ]: ")
            if not yeu_cau.strip(): continue
                
            node_list = assistant.generate_bootstrap(yeu_cau)
            if not node_list: continue
            
            print("\n--- Kế hoạch cấu hình hàng loạt ---")
            print(json.dumps(node_list, indent=2))
            print("-" * 35)
            
            cf = input(f"\n[?] Sensei có muốn Plana phân thân đẩy lệnh vào {len(node_list)} thiết bị CÙNG LÚC không? (y/n): ")
            if cf.lower() == 'y':
                assistant.push_to_console(eve_ip, node_list)
            else:
                print("[*] Plana đã hủy đẩy lệnh.")
            
        except KeyboardInterrupt:
            print("\n[*] Cần gì thì cứ gọi Plana nhé Kiên-sensei!")
            sys.exit(0)