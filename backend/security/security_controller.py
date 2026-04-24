import json
import sys
import os
import time
sys.path.append(os.getcwd())
from PyCode.security.packet_sniffer.sniffer_service import PacketSnifferService

# Đường dẫn đến thư mục Tmp (tính từ gốc project)
TMP_DIR = os.path.join(os.getcwd(), "Tmp")
INPUT_FILE = os.path.join(TMP_DIR, "packet_sniffer.json")

def monitor_ui_command():
    sniffer = PacketSnifferService()
    last_action = None

    print("[*] Backend đang canh chừng file packet_sniffer.json...")

    while True:
        if os.path.exists(INPUT_FILE):
            try:
                with open(INPUT_FILE, 'r', encoding='utf-8') as f:
                    data = json.load(f)
                    action = data.get("action")
                    payload = data.get("payload", {})

                # Chỉ xử lý nếu có hành động mới
                if action != last_action:
                    if action == "start_sniffing":
                        sniffer.start(
                            target_ip=payload.get("target_ip"),
                            type_sniffer=payload.get("type_sniffer"),
                            interface=payload.get("interface_name"),
                            bpf_filter=payload.get("bpf_filter")
                        )
                    elif action == "stop_sniffing":
                        sniffer.stop()
                    
                    last_action = action
            except Exception as e:
                print(f"[!] Lỗi đọc lệnh UI: {e}")
        
        time.sleep(1) # Quét file mỗi giây một lần

if __name__ == "__main__":
    monitor_ui_command()